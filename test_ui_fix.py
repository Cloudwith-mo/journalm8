#!/usr/bin/env python3
import json
import hmac
import hashlib
from datetime import datetime
import urllib.request
import urllib.error
import os
import sys

# AWS SigV4 signing helper
def sign_aws_request(method, host, path, body="", service="execute-api", region="us-east-1"):
    access_key = os.environ.get("AWS_ACCESS_KEY_ID")
    secret_key = os.environ.get("AWS_SECRET_ACCESS_KEY")
    
    if not access_key:
        try:
            import boto3
            session = boto3.Session()
            creds = session.get_credentials()
            access_key = creds.access_key
            secret_key = creds.secret_key
        except:
            print("ERROR: No AWS credentials found")
            return None
    
    amzdate = datetime.utcnow().strftime('%Y%m%dT%H%M%SZ')
    datestamp = datetime.utcnow().strftime('%Y%m%d')
    
    canonical_uri = path
    canonical_querystring = ""
    canonical_headers = f"host:{host}\nx-amz-date:{amzdate}\n"
    signed_headers = "host;x-amz-date"
    
    payload_hash = hashlib.sha256(body.encode()).hexdigest()
    canonical_request = f"{method}\n{canonical_uri}\n{canonical_querystring}\n{canonical_headers}\n{signed_headers}\n{payload_hash}"
    
    canonical_request_hash = hashlib.sha256(canonical_request.encode()).hexdigest()
    credential_scope = f"{datestamp}/{region}/{service}/aws4_request"
    string_to_sign = f"AWS4-HMAC-SHA256\n{amzdate}\n{credential_scope}\n{canonical_request_hash}"
    
    k_date = hmac.new(f"AWS4{secret_key}".encode(), datestamp.encode(), hashlib.sha256).digest()
    k_region = hmac.new(k_date, region.encode(), hashlib.sha256).digest()
    k_service = hmac.new(k_region, service.encode(), hashlib.sha256).digest()
    k_signing = hmac.new(k_service, b"aws4_request", hashlib.sha256).digest()
    
    signature = hmac.new(k_signing, string_to_sign.encode(), hashlib.sha256).hexdigest()
    
    auth_header = f"AWS4-HMAC-SHA256 Credential={access_key}/{credential_scope}, SignedHeaders={signed_headers}, Signature={signature}"
    
    return {"Authorization": auth_header, "x-amz-date": amzdate}

def fetch_api(path):
    host = "iq1gf00t2a.execute-api.us-east-1.amazonaws.com"
    headers = sign_aws_request("GET", host, path)
    
    if not headers:
        return None
    
    headers["Content-Type"] = "application/json"
    
    url = f"https://{host}{path}"
    req = urllib.request.Request(url, headers=headers)
    
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode())
    except Exception as e:
        print(f"ERROR: {e}")
        return None

# Fetch entries
print("=" * 80)
print("STEP 1: GET /entries RESPONSE")
print("=" * 80)
entries_data = fetch_api("/entries")
if not entries_data:
    print("Failed to fetch entries")
    sys.exit(1)

entries = entries_data.get("entries", [])
print(json.dumps(entries, indent=2, default=str))
print(f"\nTotal entries: {len(entries)}")

# Count OCR_COMPLETE entries
processed = [e for e in entries if e.get("status") in ["OCR_COMPLETE", "REVIEWED"]]
print(f"Processed count (OCR_COMPLETE || REVIEWED): {len(processed)}")

# Get first entry ID for detail test
if entries:
    first_entry_id = entries[0].get("entryId")
    print(f"\n" + "=" * 80)
    print(f"STEP 2: GET /entries/{first_entry_id} RESPONSE")
    print("=" * 80)
    
    entry = fetch_api(f"/entries/{first_entry_id}")
    if entry:
        print(json.dumps(entry, indent=2, default=str))
        
        print(f"\n" + "=" * 80)
        print("STEP 3: UI STATE MAPPING LOGIC")
        print("=" * 80)
        
        # Simulate EntryDetailScreen logic
        status = entry.get("status")
        rawText = entry.get("rawText", "")
        
        print(f"\nEntry status: {status}")
        print(f"Raw text: {repr(rawText)}")
        print(f"Raw text length: {len(rawText)}")
        print(f"Raw text is truthy: {bool(rawText)}")
        
        # OLD LOGIC
        old_condition = (status == "completed") or rawText
        print(f"\nOLD: if (data.status === 'completed' || data.rawText)")
        print(f"  → ({status} === 'completed') || {repr(rawText)}")
        print(f"  → {status == 'completed'} || {bool(rawText)}")
        print(f"  → Result: {old_condition}")
        if not old_condition:
            print(f"  → SPINNER STUCK: Keeps polling because condition is FALSE")
        
        # NEW LOGIC
        new_condition = (status == "OCR_COMPLETE" or status == "REVIEWED")
        print(f"\nNEW: if (data.status === 'OCR_COMPLETE' || data.status === 'REVIEWED')")
        print(f"  → ({status} === 'OCR_COMPLETE' || {status} === 'REVIEWED')")
        print(f"  → {status == 'OCR_COMPLETE'} || {status == 'REVIEWED'}")
        print(f"  → Result: {new_condition}")
        if new_condition:
            print(f"  → SPINNER STOPS ✓: Exits polling loop, shows transcript")
        
        print(f"\n" + "=" * 80)
        print("TRANSCRIPT VISIBILITY STATUS")
        print("=" * 80)
        print(f"rawText: {repr(rawText)}")
        print(f"correctedText: {entry.get('correctedText')}")
        
        if not rawText and not entry.get('correctedText'):
            print(f"\n⚠️  FINDING: Both rawText and correctedText are empty/null")
            print(f"rawTextKey: {entry.get('rawTextKey')}")
            print(f"correctedTextKey: {entry.get('correctedTextKey')}")
            print(f"\nUI will show: Spinner OFF, but no text visible")
            print(f"Backend question: Does get_entry need to fetch text from S3?")
        elif rawText:
            print(f"\n✓ TRANSCRIPT READY: rawText contains {len(rawText)} characters")
        elif entry.get('correctedText'):
            print(f"\n✓ TRANSCRIPT READY: correctedText contains {len(entry.get('correctedText'))} characters")
