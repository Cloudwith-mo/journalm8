import json
import os
from decimal import Decimal
from typing import Any, Dict

import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb")

JOURNAL_ENTRIES_TABLE_NAME = os.environ["JOURNAL_ENTRIES_TABLE_NAME"]
entries_table = dynamodb.Table(JOURNAL_ENTRIES_TABLE_NAME)


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

        entry_id = event.get("pathParameters", {}).get("entryId")
        if not entry_id:
            return _response(400, {"message": "entryId is required"})

        response = entries_table.get_item(
            Key={"pk": f"USER#{user_sub}", "sk": f"INSIGHT#{entry_id}"}
        )
        item = response.get("Item")
        if not item:
            return _response(404, {"message": "Insight not found"})

        insight = {
            "entryId": item.get("entryId"),
            "summary": item.get("summary", ""),
            "mood": item.get("mood", {}),
            "themes": item.get("themes", []),
            "sentiment": item.get("sentiment", {}),
            "keyInsights": item.get("keyInsights", []),
            "actionItems": item.get("actionItems", []),
            "identitySignals": item.get("identitySignals", []),
            "patternsToWatch": item.get("patternsToWatch", []),
            "reflectionQuestions": item.get("reflectionQuestions", []),
            "modelId": item.get("modelId"),
            "promptVersion": item.get("promptVersion"),
            "createdAt": item.get("createdAt"),
        }

        return _response(200, insight)

    except ClientError as e:
        print(f"ERROR: DynamoDB error: {e}")
        return _response(500, {"message": "Database error"})
    except Exception as e:
        print(f"ERROR: {e}")
        return _response(500, {"message": "Internal server error"})
