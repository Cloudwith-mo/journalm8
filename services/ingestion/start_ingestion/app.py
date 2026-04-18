import hashlib
import json
import os
from datetime import datetime, timezone
from typing import Any, Dict, List
from urllib.parse import unquote_plus

import boto3
from botocore.exceptions import ClientError

ddb = boto3.client("dynamodb")
sfn = boto3.client("stepfunctions")

INGESTION_JOBS_TABLE_NAME = os.environ["INGESTION_JOBS_TABLE_NAME"]
STATE_MACHINE_ARN = os.environ["STATE_MACHINE_ARN"]


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _parse_key(key: str) -> Dict[str, str]:
    """
    Expected shape:
    users/{userId}/raw/{entryId}/{filename}
    """
    decoded = unquote_plus(key)
    parts = decoded.split("/")

    if len(parts) < 5:
        raise ValueError(f"Unexpected S3 key format: {decoded}")

    if parts[0] != "users" or parts[2] != "raw":
        raise ValueError(f"Unexpected S3 key pattern: {decoded}")

    return {
        "decoded_key": decoded,
        "user_id": parts[1],
        "entry_id": parts[3],
        "filename": parts[4],
    }


def _job_id(bucket: str, key: str, sequencer: str) -> str:
    base = f"{bucket}:{key}:{sequencer}"
    return hashlib.sha256(base.encode("utf-8")).hexdigest()


def _put_job_if_new(job_id: str, payload: Dict[str, str]) -> bool:
    try:
        ddb.put_item(
            TableName=INGESTION_JOBS_TABLE_NAME,
            Item={
                "jobId": {"S": job_id},
                "userId": {"S": payload["userId"]},
                "entryId": {"S": payload["entryId"]},
                "bucket": {"S": payload["bucket"]},
                "key": {"S": payload["key"]},
                "status": {"S": "STARTED"},
                "startedAt": {"S": _now_iso()},
                "sourceEventName": {"S": payload["eventName"]},
                "sequencer": {"S": payload["sequencer"]},
            },
            ConditionExpression="attribute_not_exists(jobId)",
        )
        return True
    except ClientError as exc:
        if exc.response.get("Error", {}).get("Code") == "ConditionalCheckFailedException":
            print(f"Duplicate event ignored for jobId={job_id}")
            return False
        raise


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    print(json.dumps(event))

    records: List[Dict[str, Any]] = event.get("Records", [])
    started = []
    skipped = []

    for record in records:
        try:
            event_name = record["eventName"]
            bucket = record["s3"]["bucket"]["name"]
            key = record["s3"]["object"]["key"]
            sequencer = record["s3"]["object"].get("sequencer", "unknown")

            parsed = _parse_key(key)
            job_id = _job_id(bucket, parsed["decoded_key"], sequencer)

            execution_input = {
                "jobId": job_id,
                "userId": parsed["user_id"],
                "entryId": parsed["entry_id"],
                "bucket": bucket,
                "key": parsed["decoded_key"],
                "filename": parsed["filename"],
                "eventName": event_name,
                "sequencer": sequencer,
                "receivedAt": _now_iso(),
            }

            inserted = _put_job_if_new(job_id, execution_input)
            if not inserted:
                skipped.append({"jobId": job_id, "reason": "duplicate"})
                continue

            response = sfn.start_execution(
                stateMachineArn=STATE_MACHINE_ARN,
                input=json.dumps(execution_input),
            )

            started.append(
                {
                    "jobId": job_id,
                    "executionArn": response["executionArn"],
                    "entryId": parsed["entry_id"],
                }
            )

        except Exception as exc:
            print(f"ERROR processing record: {str(exc)}")
            skipped.append({"reason": str(exc)})

    return {
        "statusCode": 200,
        "body": json.dumps(
            {
                "startedCount": len(started),
                "skippedCount": len(skipped),
                "started": started,
                "skipped": skipped,
            }
        ),
    }
