import json
import os
from decimal import Decimal
from typing import Any, Dict

import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource("dynamodb")

JOURNAL_ENTRIES_TABLE_NAME = os.environ["JOURNAL_ENTRIES_TABLE_NAME"]

entries_table = dynamodb.Table(JOURNAL_ENTRIES_TABLE_NAME)


class DecimalEncoder(json.JSONEncoder):
    """Custom JSON encoder that handles Decimal objects from DynamoDB"""
    def default(self, obj):
        if isinstance(obj, Decimal):
            return int(obj) if obj % 1 == 0 else float(obj)
        return super().default(obj)


def _response(status_code: int, body: Dict[str, Any] | list) -> Dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
        },
        "body": json.dumps(body, cls=DecimalEncoder),
    }


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

        # Query only ENTRY# items — excludes INSIGHT#, REFLECTION#, etc.
        response = entries_table.query(
            KeyConditionExpression=Key("pk").eq(f"USER#{user_sub}") & Key("sk").begins_with("ENTRY#"),
            ScanIndexForward=False,  # Sort by sk descending
        )

        entries = response.get("Items", [])

        # Transform DynamoDB items to API response format
        formatted_entries = []
        for item in entries:
            formatted_entries.append({
                "entryId": item.get("sk", "").replace("ENTRY#", ""),
                "status": item.get("status", "processing"),
                "reviewStatus": item.get("reviewStatus"),
                "aiStatus": item.get("aiStatus"),
                "rawText": item.get("rawText", ""),
                "correctedText": item.get("correctedText"),
                "createdAt": item.get("createdAt"),
                "updatedAt": item.get("updatedAt"),
                "lastAnalyzedAt": item.get("lastAnalyzedAt"),
            })

        return _response(200, {"entries": formatted_entries})

    except Exception as e:
        print(f"Error listing entries: {str(e)}")
        return _response(500, {"message": "Internal server error", "error": str(e)})
