# EXACT MANUAL VALIDATION STEPS - Copy & Paste Ready

## Prerequisites (Already Complete ✅)

```
✅ All 4 backend endpoints deployed via Terraform
✅ UI dev server running at http://localhost:3000
✅ Test credentials available
✅ Real journal image available for upload
```

---

## Backend Endpoints Verification

### Command: Verify All Endpoints Are Live

```bash
# Get API endpoint URL
API="https://iq1gf00t2a.execute-api.us-east-1.amazonaws.com"

# Test 1: POST /uploads/presign
curl -X POST "$API/uploads/presign" \
  -H "Authorization: Bearer test" \
  -H "Content-Type: application/json" \
  -d '{"filename":"test.jpg"}'
# Expected: 401 Unauthorized (JWT invalid, but endpoint exists ✅)

# Test 2: GET /entries  
curl -X GET "$API/entries" \
  -H "Authorization: Bearer test"
# Expected: 401 Unauthorized (but endpoint exists ✅)

# Test 3: GET /entries/{id}
curl -X GET "$API/entries/test-id" \
  -H "Authorization: Bearer test"
# Expected: 401 Unauthorized (but endpoint exists ✅)

# Test 4: PUT /entries/{id}
curl -X PUT "$API/entries/test-id" \
  -H "Authorization: Bearer test" \
  -H "Content-Type: application/json" \
  -d '{"correctedText":"test"}'
# Expected: 401 Unauthorized (but endpoint exists ✅)
```

**Expected Result:** All 4 endpoints return 401 (not 404), proving they exist ✅

---

## Browser-Based UI Validation

### STEP 1: Sign In

**Action:** Go to http://localhost:3000

**Expected Screen:**
```
┌─────────────────────────────────────┐
│         journalm8                   │
│                                     │
│  Email: [_________________]         │
│  Password: [_____________]          │
│                                     │
│  [Sign In] [Create Account]         │
└─────────────────────────────────────┘
```

**Input:**
- Email: `e2e_6576874@journalm8.local`
- Password: `TestPass123!`
- Click: "Sign In"

**Network Tab Watch:**
1. Request to Cognito (AWS domain, not our API)
2. Response: 200 with `AuthenticationResult`

**Expected Result:**
- ✅ PASS: Token appears in browser DevTools → Application → LocalStorage → `idToken`
- ✅ PASS: Page redirects to HomeScreen
- ✅ PASS: User email visible at top: `e2e_6576874@journalm8.local`
- ❌ FAIL: [describe issue]

---

### STEP 2: Verify Empty Entry List

**Screen After Sign In:**
```
┌──────────────────────────────────┐
│ journalm8 | Logout               │
│ user@... (logged in)             │
│                                  │
│ Your Journal                     │
│ ═══════════════════════════      │
│ 0 Total Entries                  │
│ 0 Processed Entries              │
│                                  │
│ Recent Entries                   │
│ ───────────────────────────      │
│ No entries yet                   │
│                                  │
│ [Upload Image] [Ask...]          │
└──────────────────────────────────┘
```

**Network Tab Watch:**
- Request: `GET https://iq1gf00t2a.execute-api.us-east-1.amazonaws.com/entries`
- Headers: `Authorization: Bearer eyJ...` (JWT token)
- Response: `200 OK` with `[]` (empty array)

**Expected Result:**
- ✅ PASS: GET /entries succeeds (200)
- ✅ PASS: Stats show "0 Total Entries"
- ✅ PASS: Empty state displays
- ❌ FAIL: [describe issue]

---

### STEP 3: Upload Journal Image

**Action:** 
1. Click "Upload Image" button
2. Select "Take Photo" or "Upload from Gallery"
3. Select a real handwritten journal image (with text)
4. Click "Upload"

**Expected Screen During Upload:**
```
┌──────────────────────────────────┐
│ Processing your image...         │
│ ▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯ 50%          │
│                                  │
│ This may take 5-30 seconds       │
│ Please don't close this window    │
└──────────────────────────────────┘
```

**Network Tab Watch - Phase 1 (Presigning):**
- Request: `POST /uploads/presign`
- Body: `{ "filename": "..." }`
- Response: `200 OK` with `{ "uploadUrl": "https://s3.amazonaws.com/...", "entryId": "..." }`

**Network Tab Watch - Phase 2 (S3 Upload):**
- Request: `PUT https://journalm8-dev-raw-...s3.amazonaws.com/users/...`
- This is a direct S3 PUT (presigned), NOT through our API
- Response: `200 OK` (no body)

**Backend Events (CloudWatch - check logs):**
- S3 PutObject event fires
- start_ingestion Lambda triggered (automatic)
- Step Functions state machine starts
- OCR Lambda processes image

**Expected Result:**
- ✅ PASS: Presign endpoint returns valid URL
- ✅ PASS: S3 upload succeeds (200)
- ✅ PASS: Progress bar completes
- ✅ PASS: Screen shows "Processing..." spinner
- ❌ FAIL: [describe issue]

---

### STEP 4: Wait for OCR Processing

**Expected Screen:**
```
┌──────────────────────────────────┐
│ Processing your image...         │
│ ◴ Loading...                     │
│                                  │
│ Waiting for OCR results          │
│ (this takes 5-30 seconds)        │
│                                  │
│ Estimated time: <depends on size>
└──────────────────────────────────┘
```

**Network Tab Watch (every 2 seconds):**
- Request: `GET /entries/{entryId}`
- Response Format - WHILE PROCESSING:
  ```json
  {
    "entryId": "abc123",
    "status": "processing",
    "rawText": "",
    "correctedText": null,
    "createdAt": "2026-04-19T...",
    "updatedAt": "2026-04-19T..."
  }
  ```

- Response Format - AFTER OCR COMPLETE:
  ```json
  {
    "entryId": "abc123",
    "status": "completed",
    "rawText": "This is my handwritten journal entry from today...",
    "correctedText": null,
    "createdAt": "2026-04-19T...",
    "updatedAt": "2026-04-19T..."
  }
  ```

**When You See this Response:**
- Polling automatically stops
- Spinner disappears
- Button appears: "Review & Edit Transcript"

**Expected Result:**
- ✅ PASS: Polling requests succeed (200) every 2s
- ✅ PASS: Response format matches (status + rawText fields)
- ✅ PASS: After OCR: status changes to "completed"
- ✅ PASS: rawText populated with OCR'd journal text
- ✅ PASS: Button appears when ready
- ❌ FAIL: [describe issue]
- ⚠️  WARNING: Takes > 30 seconds - check CloudWatch for OCR Lambda errors

---

### STEP 5: Review & Edit Transcript

**Action:**
1. Click "Review & Edit Transcript" button
2. Observe two panels side-by-side

**Expected Screen:**
```
┌─────────────────────┬──────────────────┐
│ Original (Read-only)│ Your Edits       │
├─────────────────────┼──────────────────┤
│ This is my journal  │ This is my journal│
│ entry from today    │ entry from today  │
│                     │                   │
│ I went to the park  │ I went to the park│
│ and saw...          │ and saw beautiful │
│                     │ trees with birds  │
└─────────────────────┴──────────────────┘
                [Save]
```

**Edit Steps:**
1. Find 1-2 OCR mistakes in right panel (e.g., "adn" instead of "and")
2. Fix the typos in textarea
3. Click "Save"

**Network Tab Watch:**
- Request: `PUT /entries/{entryId}`
- Headers: `Authorization: Bearer eyJ...`
- Body: `{ "correctedText": "This is my edited journal entry..." }`
- Response: `200 OK` with `{ "message": "Transcript updated successfully", "reviewStatus": "REVIEWED" }`

**UI After Save:**
```
[Save ✓]  ← checkmark appears
(wait 2 seconds)
→ Automatically redirects to HomeScreen
```

**Expected Result:**
- ✅ PASS: PUT /entries/{entryId} succeeds (200)
- ✅ PASS: Request body has correctedText field
- ✅ PASS: Response indicates success
- ✅ PASS: Checkmark displays
- ✅ PASS: Auto-redirect to HomeScreen after 2s
- ❌ FAIL: [describe issue]

---

### STEP 6: Verify Entry in List

**Expected Screen (HomeScreen After Save):**
```
┌──────────────────────────────────┐
│ journalm8 | Logout               │
│ user@... (logged in)             │
│                                  │
│ Your Journal                     │
│ ═══════════════════════════      │
│ 1 Total Entries                  │ ← Changed from 0!
│ 1 Processed Entries              │ ← Changed from 0!
│                                  │
│ Recent Entries                   │
│ ───────────────────────────      │
│ [Entry from Apr 19]              │
│ Status: completed ✓              │
│ Text: "This is my edited..."     │
│                                  │
│ [Upload Image] [Ask...]          │
└──────────────────────────────────┘
```

**Network Tab Watch:**
- Request: `GET /entries` (automatic after redirect)
- Response: `200 OK` with array containing 1 entry:
  ```json
  [
    {
      "entryId": "abc123",
      "status": "completed",
      "rawText": "...",
      "correctedText": "...(your edited version)",
      "createdAt": "2026-04-19T...",
      "updatedAt": "2026-04-19T..."
    }
  ]
  ```

**Expected Result:**
- ✅ PASS: GET /entries shows 1 entry
- ✅ PASS: Entry status = "completed"
- ✅ PASS: Stats updated to "1 Total" and "1 Processed"
- ✅ PASS: Entry displays with date
- ✅ PASS: Entry clickable to re-view
- ❌ FAIL: [describe issue]

---

## Final Validation Checklist

| Step | Endpoint | Expected | Result |
|------|----------|----------|--------|
| 1 | Cognito | Sign in succeeds, JWT stored | ✅ ✗ |
| 2 | GET /entries | Initial empty list | ✅ ✗ |
| 3 | POST /uploads/presign | Valid S3 URL returned | ✅ ✗ |
| 3 | S3 PutObject | File uploaded (200) | ✅ ✗ |
| 4 | GET /entries/{id} (polling) | Status → completed | ✅ ✗ |
| 5 | PUT /entries/{id} | Save succeeds (200) | ✅ ✗ |
| 6 | GET /entries | Entry visible in list | ✅ ✗ |

**Overall Result:**  
- [ ] ALL PASS - Workflow complete and working ✅
- [ ] SOME FAIL - Debug specific endpoint
- [ ] CRITICAL FAIL - Stop and check backend logs

---

## Troubleshooting

### Issue: Can't Sign In
**Check:**
1. Email correct: `e2e_6576874@journalm8.local`
2. Password correct: `TestPass123!`
3. Browser console for JS errors
4. Check Cognito pool exists in AWS Console

### Issue: "0 Total Entries" stays after save
**Check:**
1. Network tab: Does GET /entries return 200?
2. Response has entryId in array?
3. Check CloudWatch for list_entries Lambda errors

### Issue: Upload never completes
**Check:**
1. Network tab: Does presign POST return 200 with uploadUrl?
2. Is the S3 PUT request made to returned URL?
3. Check S3 bucket exists and is readable
4. Check CloudWatch start_ingestion Lambda logs

### Issue: OCR stuck on "processing"
**Check:**
1. Network tab: Are GET /entries/{id} requests returning 200?
2. Check CloudWatch ocr_document Lambda logs
3. Check Step Functions execution status
4. Image too large or corrupted?

### Issue: "Save" button doesn't work
**Check:**
1. Network tab: Is PUT /entries/{id} being sent?
2. Does it return 200 or error?
3. Check update_transcript Lambda logs in CloudWatch
4. Verify database permissions

---

## How to Read CloudWatch Logs

```bash
# Get log group names
aws logs describe-log-groups --query 'logGroups[].logGroupName' | grep journalm8

# View recent logs for list_entries
aws logs tail /aws/lambda/journalm8-dev-list-entries --follow

# View recent logs for get_entry (polling)
aws logs tail /aws/lambda/journalm8-dev-get-entry --follow

# View recent logs for update_transcript (save)
aws logs tail /aws/lambda/journalm8-dev-update-transcript --follow

# View OCR Lambda logs
aws logs tail /aws/lambda/journalm8-dev-ocr-document --follow

# View start_ingestion Lambda logs
aws logs tail /aws/lambda/journalm8-dev-start-ingestion --follow
```

---

## Success Criteria

✅ **WORKFLOW COMPLETE** when:

1. Sign in works (Cognito accepts credentials)
2. POST /uploads/presign returns valid S3 URL
3. S3 upload succeeds (file appears in bucket)
4. GET /entries/{id} polling shows status transition
5. OCR Lambda completes (rawText appears)
6. PUT /entries/{id} succeeds (save button works)
7. GET /entries shows entry in list
8. Stats update correctly

❌ **WORKFLOW INCOMPLETE** if:
- Any endpoint returns 404
- Any endpoint returns 5xx error
- Lambda fails with timeout
- OCR never completes
- Entry doesn't appear in list

---

## Do Not Claim Success Unless...

- [ ] I have personally tested all 7 steps above
- [ ] All network requests returned 200 (not 401, 404, 5xx)
- [ ] OCR completed within 30 seconds
- [ ] Entry appeared in list with correct data
- [ ] Stats updated to reflect new entry
- [ ] I've documented any issues found

**Next Step:** Open http://localhost:3000 and start testing now
