import json
import os
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any, Dict

import boto3
from botocore.exceptions import ClientError

s3 = boto3.client("s3")
bedrock = boto3.client("bedrock-runtime", region_name=os.environ.get("AWS_REGION", "us-east-1"))
dynamodb = boto3.resource("dynamodb")

PROCESSED_BUCKET_NAME = os.environ["PROCESSED_BUCKET_NAME"]
JOURNAL_ENTRIES_TABLE_NAME = os.environ["JOURNAL_ENTRIES_TABLE_NAME"]
BEDROCK_MODEL_ID = os.environ.get("BEDROCK_MODEL_ID", "us.anthropic.claude-3-5-haiku-20241022-v1:0")
AI_PROVIDER = os.environ.get("AI_PROVIDER", "bedrock")  # "bedrock" | "mock"
MAX_INPUT_CHARS = int(os.environ.get("MAX_INPUT_CHARS", "4000"))
MAX_OUTPUT_TOKENS = int(os.environ.get("MAX_OUTPUT_TOKENS", "600"))

if AI_PROVIDER == "mock":
    print("WARNING: AI_PROVIDER=mock — Bedrock WILL NOT be called. Outputs are synthetic. Do NOT use in production.")

entries_table = dynamodb.Table(JOURNAL_ENTRIES_TABLE_NAME)

ENTRY_INSIGHT_PROMPT = """You are a personal journal analyst. Analyse the journal entry below and return ONLY a valid JSON object — no markdown, no explanation, no code fences.

The JSON must follow this exact schema:
{{
  "summary": "One or two sentence summary of the entry.",
  "mood": {{
    "primary": "single dominant mood word",
    "secondary": ["optional", "additional", "mood", "words"],
    "confidence": 0.0
  }},
  "themes": ["theme1", "theme2"],
  "sentiment": {{
    "score": 0.0,
    "label": "positive | negative | mixed | mixed-positive | mixed-negative | neutral"
  }},
  "keyInsights": ["insight 1", "insight 2"],
  "actionItems": ["action 1"],
  "identitySignals": ["signal 1"],
  "patternsToWatch": ["pattern 1"],
  "reflectionQuestions": ["question 1", "question 2"]
}}

Rules:
- sentiment.score is a float between -1.0 (very negative) and 1.0 (very positive)
- mood.confidence is a float between 0.0 and 1.0
- All array fields default to [] if nothing is relevant
- Return raw JSON only — no surrounding text

Journal entry:
---
{text}
---"""


class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return int(obj) if obj % 1 == 0 else float(obj)
        return super().default(obj)


def _floats_to_decimal(obj):
    """Recursively convert float values to Decimal for DynamoDB compatibility."""
    if isinstance(obj, float):
        return Decimal(str(obj))
    if isinstance(obj, dict):
        return {k: _floats_to_decimal(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_floats_to_decimal(i) for i in obj]
    return obj


def _mock_insight(text: str) -> Dict:
    """Returns deterministic mock insight for dev/validation use only.
    Enabled when AI_PROVIDER=mock. Never set in production Terraform.
    """
    words = text.split()[:6] if text else ["journal", "entry"]
    preview = " ".join(words)
    return {
        "summary": f"Mock insight for entry starting: '{preview}...'",
        "mood": {
            "primary": "reflective",
            "secondary": ["curious", "focused"],
            "confidence": Decimal("0.9"),
        },
        "themes": ["personal growth", "daily reflection", "self-awareness"],
        "sentiment": {"score": Decimal("0.3"), "label": "mixed-positive"},
        "keyInsights": [
            "Mock: The entry shows consistent self-reflection patterns.",
            "Mock: Goals and intentions are clearly articulated.",
        ],
        "actionItems": ["Mock: Review progress against weekly goals"],
        "identitySignals": ["goal-oriented", "self-aware"],
        "patternsToWatch": ["Mock: Monitor consistency of reflection practice"],
        "reflectionQuestions": [
            "Mock: What one thing would make tomorrow better?",
            "Mock: How does this entry connect to your longer-term goals?",
        ],
        "_source": "mock_validation",
    }


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    user_sub = event.get("userSub")
    entry_id = event.get("entryId")

    if not user_sub or not entry_id:
        print(f"ERROR: Missing userSub or entryId in event: {event}")
        return {"statusCode": 400, "message": "Missing userSub or entryId"}

    print(f"INFO: Enriching entry {entry_id} for user {user_sub}")

    # ── 1. Load entry metadata from DynamoDB ──────────────────────────────────
    try:
        response = entries_table.get_item(
            Key={"pk": f"USER#{user_sub}", "sk": f"ENTRY#{entry_id}"}
        )
        item = response.get("Item")
        if not item:
            print(f"ERROR: Entry {entry_id} not found for user {user_sub}")
            return {"statusCode": 404, "message": "Entry not found"}
    except ClientError as e:
        print(f"ERROR: DynamoDB GetItem failed: {e}")
        return {"statusCode": 500, "message": str(e)}

    # ── 2. Mark entry as ENRICHING ────────────────────────────────────────────
    try:
        entries_table.update_item(
            Key={"pk": f"USER#{user_sub}", "sk": f"ENTRY#{entry_id}"},
            UpdateExpression="SET aiStatus = :s",
            ExpressionAttributeValues={":s": "ENRICHING"},
        )
    except ClientError as e:
        print(f"WARN: Could not update aiStatus to ENRICHING: {e}")

    # ── 3. Fetch corrected transcript from S3 ─────────────────────────────────
    corrected_text_key = item.get("correctedTextKey")
    raw_text_key = item.get("rawTextKey")
    text_to_analyse = ""

    key_to_try = corrected_text_key or raw_text_key
    if key_to_try:
        try:
            s3_response = s3.get_object(Bucket=PROCESSED_BUCKET_NAME, Key=key_to_try)
            text_to_analyse = s3_response["Body"].read().decode("utf-8").strip()
        except ClientError as e:
            print(f"WARN: Could not fetch transcript from S3 ({key_to_try}): {e}")

    if not text_to_analyse:
        print(f"ERROR: No transcript text available for entry {entry_id}")
        _mark_failed(user_sub, entry_id, "NoTranscript", "No transcript text available")
        return {"statusCode": 422, "message": "No transcript text to analyse"}

    # Truncate to configured limit to conserve quota
    if len(text_to_analyse) > MAX_INPUT_CHARS:
        print(f"INFO: Truncating transcript from {len(text_to_analyse)} to {MAX_INPUT_CHARS} chars")
        text_to_analyse = text_to_analyse[:MAX_INPUT_CHARS]

    # ── 4. Call AI provider ───────────────────────────────────────────────────
    prompt = ENTRY_INSIGHT_PROMPT.format(text=text_to_analyse)

    if AI_PROVIDER == "mock":
        print(f"INFO: Mock mode — skipping Bedrock for entry {entry_id}")
        insight = _mock_insight(text_to_analyse)
    else:
        try:
            bedrock_response = bedrock.invoke_model(
                modelId=BEDROCK_MODEL_ID,
                contentType="application/json",
                accept="application/json",
                body=json.dumps({
                    "anthropic_version": "bedrock-2023-05-31",
                    "max_tokens": MAX_OUTPUT_TOKENS,
                    "temperature": 0.3,
                    "messages": [{"role": "user", "content": prompt}],
                }),
            )
            response_body = json.loads(bedrock_response["body"].read())
            raw_text = response_body["content"][0]["text"].strip()
        except Exception as e:
            error_str = str(e)
            print(f"ERROR: Bedrock invocation failed: {e}")
            error_code = type(e).__name__
            if hasattr(e, "response"):
                error_code = e.response.get("Error", {}).get("Code", error_code)
            if "ThrottlingException" in error_str or "TooManyRequests" in error_str:
                _mark_throttled(user_sub, entry_id, error_code, error_str[:200])
            else:
                _mark_failed(user_sub, entry_id, error_code, error_str[:200])
            return {"statusCode": 500, "message": f"Bedrock error: {error_str}"}

        # ── 5. Parse JSON from model output ───────────────────────────────────
        try:
            if raw_text.startswith("```"):
                raw_text = raw_text.split("```")[1]
                if raw_text.startswith("json"):
                    raw_text = raw_text[4:]
            insight = json.loads(raw_text)
        except json.JSONDecodeError as e:
            print(f"ERROR: Could not parse Bedrock JSON response: {e}\nRaw: {raw_text[:500]}")
            _mark_failed(user_sub, entry_id, "JSONDecodeError", str(e)[:200])
            return {"statusCode": 500, "message": "Invalid JSON from model"}

    # ── 6. Store INSIGHT item in DynamoDB ─────────────────────────────────────
    now = _now_iso()
    insight_item = {
        "pk": f"USER#{user_sub}",
        "sk": f"INSIGHT#{entry_id}",
        "entityType": "ENTRY_INSIGHT",
        "entryId": entry_id,
        "summary": insight.get("summary", ""),
        "mood": _floats_to_decimal(insight.get("mood", {})),
        "themes": insight.get("themes", []),
        "sentiment": _floats_to_decimal(insight.get("sentiment", {})),
        "keyInsights": insight.get("keyInsights", []),
        "actionItems": insight.get("actionItems", []),
        "identitySignals": insight.get("identitySignals", []),
        "patternsToWatch": insight.get("patternsToWatch", []),
        "reflectionQuestions": insight.get("reflectionQuestions", []),
        "modelId": BEDROCK_MODEL_ID if AI_PROVIDER != "mock" else "mock",
        "promptVersion": "entry-insight-v1",
        "createdAt": now,
    }
    # Carry _source tag through for mock/seeded items
    if insight.get("_source"):
        insight_item["source"] = insight["_source"]

    try:
        entries_table.put_item(Item=insight_item)
    except ClientError as e:
        print(f"ERROR: DynamoDB PutItem (insight) failed: {e}")
        _mark_failed(user_sub, entry_id)
        return {"statusCode": 500, "message": str(e)}

    # ── 7. Update entry aiStatus = COMPLETE and capture lastAnalyzedAt ────────
    try:
        entries_table.update_item(
            Key={"pk": f"USER#{user_sub}", "sk": f"ENTRY#{entry_id}"},
            UpdateExpression="SET aiStatus = :s, lastAnalyzedAt = :t",
            ExpressionAttributeValues={":s": "COMPLETE", ":t": now},
        )
    except ClientError as e:
        print(f"WARN: Could not update aiStatus to COMPLETE: {e}")

    print(f"INFO: Enrichment complete for entry {entry_id}. Themes: {insight.get('themes', [])}")
    return {"statusCode": 200, "entryId": entry_id, "aiStatus": "COMPLETE"}


def _mark_throttled(user_sub: str, entry_id: str, error_code: str, error_msg: str) -> None:
    try:
        entries_table.update_item(
            Key={"pk": f"USER#{user_sub}", "sk": f"ENTRY#{entry_id}"},
            UpdateExpression="SET aiStatus = :s, aiErrorCode = :c, aiErrorMessage = :m, lastAiAttemptAt = :t",
            ExpressionAttributeValues={
                ":s": "THROTTLED",
                ":c": error_code,
                ":m": error_msg,
                ":t": _now_iso(),
            },
        )
    except Exception:
        pass


def _mark_failed(user_sub: str, entry_id: str, error_code: str = "UnknownError", error_msg: str = "") -> None:
    try:
        entries_table.update_item(
            Key={"pk": f"USER#{user_sub}", "sk": f"ENTRY#{entry_id}"},
            UpdateExpression="SET aiStatus = :s, aiErrorCode = :c, aiErrorMessage = :m, lastAiAttemptAt = :t",
            ExpressionAttributeValues={
                ":s": "FAILED",
                ":c": error_code,
                ":m": error_msg,
                ":t": _now_iso(),
            },
        )
    except Exception:
        pass
