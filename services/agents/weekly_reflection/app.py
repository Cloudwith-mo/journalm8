import json
import os
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any, Dict, List

import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError

bedrock = boto3.client("bedrock-runtime", region_name=os.environ.get("AWS_REGION", "us-east-1"))
dynamodb = boto3.resource("dynamodb")

JOURNAL_ENTRIES_TABLE_NAME = os.environ["JOURNAL_ENTRIES_TABLE_NAME"]
BEDROCK_MODEL_ID = os.environ.get("BEDROCK_MODEL_ID", "anthropic.claude-3-haiku-20240307-v1:0")

entries_table = dynamodb.Table(JOURNAL_ENTRIES_TABLE_NAME)

WEEKLY_REFLECTION_PROMPT = """You are a personal growth coach and journal analyst. Below are summaries and insights from a person's journal entries for the past week.

Analyse them and return ONLY a valid JSON object — no markdown, no explanation, no code fences.

Schema:
{{
  "weeklySummary": "2-3 sentence summary of what the week was about.",
  "dominantThemes": ["theme1", "theme2"],
  "wins": ["win 1", "win 2"],
  "struggles": ["struggle 1"],
  "emotionalPattern": "One sentence about how mood/emotion shifted across the week.",
  "identityPattern": "One sentence about what kind of person this writer is becoming.",
  "repeatedLoop": "The main repeated thought pattern or behaviour.",
  "recommendedFocus": "One clear, practical focus for next week.",
  "reflectionQuestions": ["question 1", "question 2", "question 3"]
}}

Week: {week_start} to {week_end}

Entry summaries:
{entry_summaries}"""


class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return int(obj) if obj % 1 == 0 else float(obj)
        return super().default(obj)


def _response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body, cls=DecimalEncoder),
    }


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    try:
        claims = (
            event.get("requestContext", {})
            .get("authorizer", {})
            .get("jwt", {})
            .get("claims", {})
        )
        user_sub = claims.get("sub")

        if not user_sub:
            return _response(401, {"message": "Unauthorized"})

        # Parse week range from request body
        raw_body = event.get("body") or "{}"
        body = json.loads(raw_body)
        week_start = body.get("weekStart")
        week_end = body.get("weekEnd")

        if not week_start or not week_end:
            # Default to current week (Mon–Sun)
            now = datetime.now(timezone.utc)
            week_num = now.strftime("%Y-W%V")
            week_start = week_start or now.strftime("%Y-%m-%d")
            week_end = week_end or now.strftime("%Y-%m-%d")
            week_id = week_num
        else:
            # Derive ISO week id from weekStart
            try:
                week_id = datetime.fromisoformat(week_start).strftime("%Y-W%V")
            except ValueError:
                week_id = week_start

        # ── 1. Query all ENTRY items for this user ────────────────────────────
        response = entries_table.query(
            KeyConditionExpression=Key("pk").eq(f"USER#{user_sub}") & Key("sk").begins_with("ENTRY#"),
        )
        all_entries = response.get("Items", [])

        # ── 2. Filter reviewed entries within the date range ──────────────────
        reviewed_entries = [
            e for e in all_entries
            if e.get("reviewStatus") == "REVIEWED"
            and _in_date_range(e.get("updatedAt", ""), week_start, week_end)
        ]

        if not reviewed_entries:
            return _response(404, {
                "message": "No reviewed entries found in this date range",
                "weekId": week_id,
                "weekStart": week_start,
                "weekEnd": week_end,
            })

        # ── 3. Fetch INSIGHT items for those entries ───────────────────────────
        entry_ids = [e.get("sk", "").replace("ENTRY#", "") for e in reviewed_entries]
        insight_map: Dict[str, Any] = {}
        for eid in entry_ids:
            try:
                ins_response = entries_table.get_item(
                    Key={"pk": f"USER#{user_sub}", "sk": f"INSIGHT#{eid}"}
                )
                ins = ins_response.get("Item")
                if ins:
                    insight_map[eid] = ins
            except ClientError:
                pass

        # ── 4. Build entry_summaries block for the prompt ─────────────────────
        summaries_text = _build_summaries(reviewed_entries, insight_map)

        # ── 5. Call Bedrock ───────────────────────────────────────────────────
        prompt = WEEKLY_REFLECTION_PROMPT.format(
            week_start=week_start,
            week_end=week_end,
            entry_summaries=summaries_text,
        )
        try:
            bedrock_response = bedrock.invoke_model(
                modelId=BEDROCK_MODEL_ID,
                contentType="application/json",
                accept="application/json",
                body=json.dumps({
                    "anthropic_version": "bedrock-2023-05-31",
                    "max_tokens": 1024,
                    "temperature": 0.4,
                    "messages": [{"role": "user", "content": prompt}],
                }),
            )
            response_body = json.loads(bedrock_response["body"].read())
            raw_text = response_body["content"][0]["text"].strip()
        except Exception as e:
            print(f"ERROR: Bedrock invocation failed: {e}")
            return _response(500, {"message": f"Bedrock error: {str(e)}"})

        # ── 6. Parse JSON ──────────────────────────────────────────────────────
        try:
            if raw_text.startswith("```"):
                raw_text = raw_text.split("```")[1]
                if raw_text.startswith("json"):
                    raw_text = raw_text[4:]
            reflection = json.loads(raw_text)
        except json.JSONDecodeError as e:
            print(f"ERROR: Could not parse reflection JSON: {e}\nRaw: {raw_text[:500]}")
            return _response(500, {"message": "Invalid JSON from model"})

        # ── 7. Store REFLECTION item in DynamoDB ──────────────────────────────
        now = _now_iso()
        reflection_item = {
            "pk": f"USER#{user_sub}",
            "sk": f"REFLECTION#WEEK#{week_id}",
            "entityType": "WEEKLY_REFLECTION",
            "weekId": week_id,
            "weekStart": week_start,
            "weekEnd": week_end,
            "entryCount": len(reviewed_entries),
            "weeklySummary": reflection.get("weeklySummary", ""),
            "dominantThemes": reflection.get("dominantThemes", []),
            "wins": reflection.get("wins", []),
            "struggles": reflection.get("struggles", []),
            "emotionalPattern": reflection.get("emotionalPattern", ""),
            "identityPattern": reflection.get("identityPattern", ""),
            "repeatedLoop": reflection.get("repeatedLoop", ""),
            "recommendedFocus": reflection.get("recommendedFocus", ""),
            "reflectionQuestions": reflection.get("reflectionQuestions", []),
            "modelId": BEDROCK_MODEL_ID,
            "createdAt": now,
        }

        entries_table.put_item(Item=reflection_item)
        print(f"INFO: Weekly reflection created for user {user_sub}, week {week_id}")

        return _response(
            200,
            {
                "weekId": week_id,
                "weekStart": week_start,
                "weekEnd": week_end,
                "entryCount": len(reviewed_entries),
                "weeklySummary": reflection_item["weeklySummary"],
                "dominantThemes": reflection_item["dominantThemes"],
                "wins": reflection_item["wins"],
                "struggles": reflection_item["struggles"],
                "emotionalPattern": reflection_item["emotionalPattern"],
                "identityPattern": reflection_item["identityPattern"],
                "repeatedLoop": reflection_item["repeatedLoop"],
                "recommendedFocus": reflection_item["recommendedFocus"],
                "reflectionQuestions": reflection_item["reflectionQuestions"],
            },
        )

    except json.JSONDecodeError:
        return _response(400, {"message": "Invalid JSON body"})
    except Exception as exc:
        print(f"ERROR: {str(exc)}")
        return _response(500, {"message": "Internal server error"})


def _in_date_range(iso_date_str: str, start: str, end: str) -> bool:
    """Return True if iso_date_str falls within [start, end] inclusive."""
    if not iso_date_str:
        return False
    try:
        date = iso_date_str[:10]  # take YYYY-MM-DD portion
        return start <= date <= end
    except Exception:
        return False


def _build_summaries(entries: List[Dict], insight_map: Dict[str, Any]) -> str:
    """Format entries + insights into a readable block for the prompt."""
    lines = []
    for i, entry in enumerate(entries, 1):
        entry_id = entry.get("sk", "").replace("ENTRY#", "")
        date = entry.get("updatedAt", "")[:10]
        insight = insight_map.get(entry_id, {})
        summary = insight.get("summary") or "(no AI summary available)"
        themes = ", ".join(insight.get("themes", [])) or "none"
        mood = insight.get("mood", {}).get("primary", "unknown")
        lines.append(f"Entry {i} ({date}) — mood: {mood}, themes: {themes}\nSummary: {summary}")
    return "\n\n".join(lines)
