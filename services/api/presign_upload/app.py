import json
import os
import re
import uuid
from typing import Any, Dict

import boto3

s3 = boto3.client("s3")

RAW_BUCKET_NAME = os.environ["RAW_BUCKET_NAME"]
URL_EXPIRATION_SECONDS = int(os.environ.get("URL_EXPIRATION_SECONDS", "900"))

ALLOWED_CONTENT_TYPES = {
    "image/jpeg",
    "image/png",
    "application/pdf",
}


def _response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
        },
        "body": json.dumps(body),
    }


def _safe_filename(filename: str) -> str:
    filename = filename.strip()
    filename = re.sub(r"[^A-Za-z0-9._-]", "_", filename)
    return filename[:200] or "upload.bin"


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
            return _response(401, {"message": "Unauthorized: missing user identity"})

        raw_body = event.get("body") or "{}"
        body = json.loads(raw_body)

        filename = body.get("filename", "")
        content_type = body.get("contentType", "")

        if not filename:
            return _response(400, {"message": "filename is required"})

        if content_type not in ALLOWED_CONTENT_TYPES:
            return _response(
                400,
                {
                    "message": "Unsupported content type",
                    "allowedContentTypes": sorted(ALLOWED_CONTENT_TYPES),
                },
            )

        entry_id = str(uuid.uuid4())
        safe_filename = _safe_filename(filename)
        object_key = f"users/{user_sub}/raw/{entry_id}/{safe_filename}"

        upload_url = s3.generate_presigned_url(
            ClientMethod="put_object",
            Params={
                "Bucket": RAW_BUCKET_NAME,
                "Key": object_key,
                "ContentType": content_type,
            },
            ExpiresIn=URL_EXPIRATION_SECONDS,
            HttpMethod="PUT",
        )

        return _response(
            200,
            {
                "entryId": entry_id,
                "bucket": RAW_BUCKET_NAME,
                "key": object_key,
                "contentType": content_type,
                "expiresIn": URL_EXPIRATION_SECONDS,
                "uploadUrl": upload_url,
            },
        )

    except json.JSONDecodeError:
        return _response(400, {"message": "Invalid JSON body"})
    except Exception as exc:
        print(f"ERROR: {str(exc)}")
        return _response(500, {"message": "Internal server error"})
