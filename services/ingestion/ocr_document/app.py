import json
import os
from datetime import datetime, timezone
from typing import Any, Dict, List

import boto3
from botocore.exceptions import ClientError

from text_processor import process_ocr_text
from image_preprocessor import preprocess_image, should_preprocess

s3 = boto3.client("s3")
textract = boto3.client("textract")
dynamodb = boto3.resource("dynamodb")

PROCESSED_BUCKET_NAME = os.environ["PROCESSED_BUCKET_NAME"]
INGESTION_JOBS_TABLE_NAME = os.environ["INGESTION_JOBS_TABLE_NAME"]
JOURNAL_ENTRIES_TABLE_NAME = os.environ["JOURNAL_ENTRIES_TABLE_NAME"]

jobs_table = dynamodb.Table(INGESTION_JOBS_TABLE_NAME)
entries_table = dynamodb.Table(JOURNAL_ENTRIES_TABLE_NAME)


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _extract_lines(blocks: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    return [b for b in blocks if b.get("BlockType") == "LINE" and b.get("Text")]


def _build_clean_text(lines: List[Dict[str, Any]]) -> str:
    return "\n".join(line["Text"] for line in lines).strip()


def _line_stats(lines: List[Dict[str, Any]]) -> Dict[str, Any]:
    handwriting_count = 0
    printed_count = 0
    confidences = []

    for line in lines:
        text_type = line.get("TextType")
        if text_type == "HANDWRITING":
            handwriting_count += 1
        elif text_type == "PRINTED":
            printed_count += 1

        confidence = line.get("Confidence")
        if isinstance(confidence, (int, float)):
            confidences.append(confidence)

    avg_confidence = round(sum(confidences) / len(confidences), 2) if confidences else 0.0

    return {
        "lineCount": len(lines),
        "handwritingLineCount": handwriting_count,
        "printedLineCount": printed_count,
        "avgLineConfidence": avg_confidence,
    }


def _put_processed_objects(
    user_id: str,
    entry_id: str,
    textract_response: Dict[str, Any],
    raw_text: str,
    corrected_text: str,
    metadata: Dict[str, Any],
) -> Dict[str, str]:
    prefix = f"users/{user_id}/processed/{entry_id}"
    ocr_json_key = f"{prefix}/ocr.json"
    raw_text_key = f"{prefix}/raw.txt"
    corrected_text_key = f"{prefix}/corrected.txt"
    metadata_key = f"{prefix}/metadata.json"

    s3.put_object(
        Bucket=PROCESSED_BUCKET_NAME,
        Key=ocr_json_key,
        Body=json.dumps(textract_response).encode("utf-8"),
        ContentType="application/json",
    )

    s3.put_object(
        Bucket=PROCESSED_BUCKET_NAME,
        Key=raw_text_key,
        Body=raw_text.encode("utf-8"),
        ContentType="text/plain; charset=utf-8",
    )

    s3.put_object(
        Bucket=PROCESSED_BUCKET_NAME,
        Key=corrected_text_key,
        Body=corrected_text.encode("utf-8"),
        ContentType="text/plain; charset=utf-8",
    )

    s3.put_object(
        Bucket=PROCESSED_BUCKET_NAME,
        Key=metadata_key,
        Body=json.dumps(metadata).encode("utf-8"),
        ContentType="application/json",
    )

    return {
        "ocrJsonKey": ocr_json_key,
        "rawTextKey": raw_text_key,
        "correctedTextKey": corrected_text_key,
        "metadataKey": metadata_key,
    }


def _update_job_success(
    job_id: str,
    processed_keys: Dict[str, str],
    stats: Dict[str, Any],
    page_count: int,
    review_status: str,
) -> None:
    jobs_table.update_item(
        Key={"jobId": job_id},
        ConditionExpression="attribute_exists(jobId)",
        UpdateExpression=(
            "SET #status = :status, completedAt = :completedAt, "
            "processedBucket = :processedBucket, "
            "ocrJsonKey = :ocrJsonKey, rawTextKey = :rawTextKey, correctedTextKey = :correctedTextKey, metadataKey = :metadataKey, "
            "ocrConfidence = :ocrConfidence, lineCount = :lineCount, "
            "handwritingLineCount = :handwritingLineCount, printedLineCount = :printedLineCount, "
            "pageCount = :pageCount, reviewStatus = :reviewStatus"
        ),
        ExpressionAttributeNames={"#status": "status"},
        ExpressionAttributeValues={
            ":status": "OCR_COMPLETE",
            ":completedAt": _now_iso(),
            ":processedBucket": PROCESSED_BUCKET_NAME,
            ":ocrJsonKey": processed_keys["ocrJsonKey"],
            ":rawTextKey": processed_keys["rawTextKey"],
            ":correctedTextKey": processed_keys["correctedTextKey"],
            ":metadataKey": processed_keys["metadataKey"],
            ":ocrConfidence": str(stats["avgLineConfidence"]),
            ":lineCount": stats["lineCount"],
            ":handwritingLineCount": stats["handwritingLineCount"],
            ":printedLineCount": stats["printedLineCount"],
            ":pageCount": page_count,
            ":reviewStatus": review_status,
        },
    )


def _update_job_failure(job_id: str, error_message: str) -> None:
    try:
        jobs_table.update_item(
            Key={"jobId": job_id},
            ConditionExpression="attribute_exists(jobId)",
            UpdateExpression="SET #status = :status, failedAt = :failedAt, errorMessage = :errorMessage",
            ExpressionAttributeNames={"#status": "status"},
            ExpressionAttributeValues={
                ":status": "OCR_FAILED",
                ":failedAt": _now_iso(),
                ":errorMessage": error_message[:1000],
            },
        )
    except Exception as exc:
        print(f"Failed to update OCR_FAILED status for job {job_id}: {exc}")


def _put_journal_entry(
    user_id: str,
    entry_id: str,
    filename: str,
    source_bucket: str,
    source_key: str,
    processed_keys: Dict[str, str],
    stats: Dict[str, Any],
    page_count: int,
    review_status: str,
) -> None:
    now = _now_iso()

    entries_table.put_item(
        Item={
            "pk": f"USER#{user_id}",
            "sk": f"ENTRY#{entry_id}",
            "entryId": entry_id,
            "userId": user_id,
            "filename": filename,
            "sourceBucket": source_bucket,
            "sourceKey": source_key,
            "processedBucket": PROCESSED_BUCKET_NAME,
            "ocrJsonKey": processed_keys["ocrJsonKey"],
            "rawTextKey": processed_keys["rawTextKey"],
            "correctedTextKey": processed_keys["correctedTextKey"],
            "metadataKey": processed_keys["metadataKey"],
            "status": "OCR_COMPLETE",
            "reviewStatus": review_status,
            "ocrConfidence": str(stats["avgLineConfidence"]),
            "lineCount": stats["lineCount"],
            "handwritingLineCount": stats["handwritingLineCount"],
            "printedLineCount": stats["printedLineCount"],
            "pageCount": page_count,
            "correctionCount": 0,
            "createdAt": now,
            "updatedAt": now,
        }
    )


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    print(json.dumps(event))

    job_id = event["jobId"]
    user_id = event["userId"]
    entry_id = event["entryId"]
    bucket = event["bucket"]
    key = event["key"]
    filename = event["filename"]

    try:
        # Step 1: Download and preprocess image if applicable
        s3_obj = s3.get_object(Bucket=bucket, Key=key)
        image_bytes = s3_obj['Body'].read()
        content_type = s3_obj.get('ContentType', 'image/jpeg')
        
        if should_preprocess(content_type):
            print(f"Preprocessing image: {filename}")
            image_bytes = preprocess_image(image_bytes)
        
        # Step 2: Run OCR on (possibly preprocessed) image
        response = textract.detect_document_text(
            Document={"Bytes": image_bytes}
        )

        # Step 3: Extract text and stats
        blocks = response.get("Blocks", [])
        lines = _extract_lines(blocks)
        raw_text = _build_clean_text(lines)
        stats = _line_stats(lines)
        page_count = response.get("DocumentMetadata", {}).get("Pages", 1)
        
        # Step 4: Post-process OCR text
        processed = process_ocr_text(
            raw_text=raw_text,
            confidence=stats["avgLineConfidence"],
            line_count=stats["lineCount"],
        )
        
        now_iso = _now_iso()
        year_month = now_iso[:7]  # YYYY-MM format

        metadata = {
            "jobId": job_id,
            "userId": user_id,
            "entryId": entry_id,
            "filename": filename,
            "sourceBucket": bucket,
            "sourceKey": key,
            "processedBucket": PROCESSED_BUCKET_NAME,
            "pageCount": page_count,
            "yearMonth": year_month,
            "ocrConfidence": stats["avgLineConfidence"],
            "reviewStatus": processed["reviewStatus"],
            "fixesApplied": processed["fixesApplied"],
            "fixCount": processed["fixCount"],
            **stats,
            "processedAt": now_iso,
        }

        processed_keys = _put_processed_objects(
            user_id=user_id,
            entry_id=entry_id,
            textract_response=response,
            raw_text=processed["rawText"],
            corrected_text=processed["correctedText"],
            metadata=metadata,
        )

        _update_job_success(
            job_id=job_id,
            processed_keys=processed_keys,
            stats=stats,
            page_count=page_count,
            review_status=processed["reviewStatus"],
        )

        _put_journal_entry(
            user_id=user_id,
            entry_id=entry_id,
            filename=filename,
            source_bucket=bucket,
            source_key=key,
            processed_keys=processed_keys,
            stats=stats,
            page_count=page_count,
            review_status=processed["reviewStatus"],
        )

        return {
            "jobId": job_id,
            "userId": user_id,
            "entryId": entry_id,
            "filename": filename,
            "sourceBucket": bucket,
            "sourceKey": key,
            "processedBucket": PROCESSED_BUCKET_NAME,
            "ocrJsonKey": processed_keys["ocrJsonKey"],
            "rawTextKey": processed_keys["rawTextKey"],
            "correctedTextKey": processed_keys["correctedTextKey"],
            "metadataKey": processed_keys["metadataKey"],
            "pageCount": page_count,
            "reviewStatus": processed["reviewStatus"],
            **stats,
            "status": "OCR_COMPLETE",
        }

    except ClientError as exc:
        error_message = f"AWS client error: {str(exc)}"
        print(error_message)
        _update_job_failure(job_id, error_message)
        raise
    except Exception as exc:
        error_message = f"Unhandled error: {str(exc)}"
        print(error_message)
        _update_job_failure(job_id, error_message)
        raise
