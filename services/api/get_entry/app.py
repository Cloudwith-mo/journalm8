import json
import os
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

        # Query DynamoDB for the specific entry
        response = entries_table.get_item(
            Key={
                "pk": f"USER#{user_sub}",
                "sk": f"ENTRY#{entry_id}",
            }
        )

        item = response.get("Item")
        if not item:
            return _response(404, {"message": "Entry not found"})

        # Fetch text from S3 if keys are available
        raw_text = ""
        corrected_text = None
        
        raw_text_key = item.get("rawTextKey")
        if raw_text_key:
            try:
                s3_response = s3.get_object(Bucket=PROCESSED_BUCKET_NAME, Key=raw_text_key)
                raw_text = s3_response["Body"].read().decode("utf-8")
            except ClientError as e:
                print(f"Warning: Could not fetch rawText from S3: {str(e)}")
                raw_text = ""
        
        corrected_text_key = item.get("correctedTextKey")
        if corrected_text_key:
            try:
                s3_response = s3.get_object(Bucket=PROCESSED_BUCKET_NAME, Key=corrected_text_key)
                corrected_text = s3_response["Body"].read().decode("utf-8")
            except ClientError as e:
                print(f"Warning: Could not fetch correctedText from S3: {str(e)}")
                corrected_text = None

        # Format response
        formatted_entry = {
            "entryId": item.get("sk", "").replace("ENTRY#", ""),
            "status": item.get("status", "processing"),
            "reviewStatus": item.get("reviewStatus"),
            "rawText": raw_text,
            "correctedText": corrected_text,
            "createdAt": item.get("createdAt"),
            "updatedAt": item.get("updatedAt"),
        }

        return _response(200, formatted_entry)

    except Exception as e:
        print(f"Error getting entry: {str(e)}")
        return _response(500, {"message": "Internal server error", "error": str(e)})
