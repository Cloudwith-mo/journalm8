import json
import os
from typing import Any, Dict

import boto3
from botocore.exceptions import ClientError

lambda_client = boto3.client("lambda")
dynamodb = boto3.resource("dynamodb")

JOURNAL_ENTRIES_TABLE_NAME = os.environ["JOURNAL_ENTRIES_TABLE_NAME"]
ENRICH_ENTRY_FUNCTION_NAME = os.environ.get("ENRICH_ENTRY_FUNCTION_NAME", "")

entries_table = dynamodb.Table(JOURNAL_ENTRIES_TABLE_NAME)


def _response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
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

        # Verify entry exists and belongs to this user
        try:
            resp = entries_table.get_item(
                Key={"pk": f"USER#{user_sub}", "sk": f"ENTRY#{entry_id}"}
            )
            item = resp.get("Item")
            if not item:
                return _response(404, {"message": "Entry not found"})
        except ClientError as e:
            return _response(500, {"message": str(e)})

        # Reset aiStatus to QUEUED
        try:
            entries_table.update_item(
                Key={"pk": f"USER#{user_sub}", "sk": f"ENTRY#{entry_id}"},
                UpdateExpression="SET aiStatus = :s",
                ExpressionAttributeValues={":s": "QUEUED"},
            )
        except ClientError as e:
            return _response(500, {"message": f"Failed to reset aiStatus: {str(e)}"})

        # Async-invoke enrich_entry
        if ENRICH_ENTRY_FUNCTION_NAME:
            try:
                lambda_client.invoke(
                    FunctionName=ENRICH_ENTRY_FUNCTION_NAME,
                    InvocationType="Event",
                    Payload=json.dumps({"userSub": user_sub, "entryId": entry_id}),
                )
            except ClientError as e:
                print(f"WARN: Could not invoke enrich_entry: {e}")

        return _response(200, {"entryId": entry_id, "aiStatus": "QUEUED"})

    except Exception as e:
        print(f"ERROR: {e}")
        return _response(500, {"message": "Internal server error"})
