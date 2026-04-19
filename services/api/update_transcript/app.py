import json
import os
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any, Dict

import boto3
from botocore.exceptions import ClientError

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")

PROCESSED_BUCKET_NAME = os.environ["PROCESSED_BUCKET_NAME"]
JOURNAL_ENTRIES_TABLE_NAME = os.environ["JOURNAL_ENTRIES_TABLE_NAME"]

entries_table = dynamodb.Table(JOURNAL_ENTRIES_TABLE_NAME)


class DecimalEncoder(json.JSONEncoder):
    """Custom JSON encoder that handles Decimal objects from DynamoDB"""
    def default(self, obj):
        if isinstance(obj, Decimal):
            return int(obj) if obj % 1 == 0 else float(obj)
        return super().default(obj)


def _response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
        },
        "body": json.dumps(body, cls=DecimalEncoder),
    }


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    try:
        # Extract user from JWT claims
        claims = (
            event.get("requestContext", {})
            .get("authorizer", {})
            .get("jwt", {})
            .get("claims", {})
        )
        user_sub = claims.get("sub")

        if not user_sub:
            return _response(401, {"message": "Unauthorized: missing user identity"})

        # Extract entryId from path
        entry_id = event.get("pathParameters", {}).get("entryId")
        if not entry_id:
            return _response(400, {"message": "entryId is required"})

        # Parse request body
        raw_body = event.get("body") or "{}"
        body = json.loads(raw_body)
        corrected_text = body.get("correctedText")

        if not corrected_text:
            return _response(400, {"message": "correctedText is required"})

        # Verify user owns this entry
        try:
            entry = entries_table.get_item(
                Key={"pk": f"USER#{user_sub}", "sk": f"ENTRY#{entry_id}"}
            )
            if "Item" not in entry:
                return _response(404, {"message": "Entry not found"})
        except ClientError as e:
            return _response(500, {"message": f"Database error: {str(e)}"})

        entry_item = entry["Item"]
        corrected_text_key = entry_item.get("correctedTextKey")

        if not corrected_text_key:
            return _response(500, {"message": "Entry missing correctedTextKey"})

        # Save corrected text to S3
        s3.put_object(
            Bucket=PROCESSED_BUCKET_NAME,
            Key=corrected_text_key,
            Body=corrected_text.encode("utf-8"),
            ContentType="text/plain; charset=utf-8",
        )

        # Update DynamoDB
        now = _now_iso()
        correction_count = int(entry_item.get("correctionCount", 0)) + 1

        entries_table.update_item(
            Key={"pk": f"USER#{user_sub}", "sk": f"ENTRY#{entry_id}"},
            UpdateExpression=(
                "SET reviewStatus = :status, correctionCount = :count, "
                "lastCorrectedAt = :correctedAt, updatedAt = :updatedAt"
            ),
            ExpressionAttributeValues={
                ":status": "REVIEWED",
                ":count": correction_count,
                ":correctedAt": now,
                ":updatedAt": now,
            },
        )

        return _response(
            200,
            {
                "message": "Transcript updated successfully",
                "entryId": entry_id,
                "reviewStatus": "REVIEWED",
                "correctionCount": correction_count,
            },
        )

    except json.JSONDecodeError:
        return _response(400, {"message": "Invalid JSON body"})
    except Exception as exc:
        print(f"ERROR: {str(exc)}")
        return _response(500, {"message": "Internal server error"})
