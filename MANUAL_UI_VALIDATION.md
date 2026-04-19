# Manual UI Validation - Complete End-to-End Testing

**Date:** April 19, 2026  
**Environment:** Local development (http://localhost:3000)  
**Test Credentials:** e2e_6576874@journalm8.local / TestPass123!  
**Backend API Endpoint:** https://iq1gf00t2a.execute-api.us-east-1.amazonaws.com

---

## Part 1: Backend Endpoint Verification

### Deployed Endpoints (Verified via Terraform Apply)

| Method | Endpoint | Status | Lambda Function | CORS Enabled |
|--------|----------|--------|-----------------|--------------|
| POST | /uploads/presign | ✅ DEPLOYED | journalm8-dev-presign-upload | Yes (POST, OPTIONS) |
| GET | /entries | ✅ DEPLOYED | journalm8-dev-list-entries | Yes (GET, POST, PUT, OPTIONS) |
| GET | /entries/{entryId} | ✅ DEPLOYED | journalm8-dev-get-entry | Yes (GET, POST, PUT, OPTIONS) |
| PUT | /entries/{entryId} | ✅ DEPLOYED | journalm8-dev-update-transcript | Yes (GET, POST, PUT, OPTIONS) |

**CORS Configuration Updated:**  
- Before: `allow_methods = ["POST", "OPTIONS"]`  
- After: `allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]`
- Applied via: `terraform apply -auto-approve` ✅ Complete

---

## Part 2: Manual Validation Steps

### Step 1: Verify Dev Server is Running
**Expected:** Browser opens, sees login screen

```bash
# Terminal 1: Start dev server
cd /Users/muhammadadeyemi/journalm8/journalm8/ui
npm install
npm run dev
```

**Browser Navigation:**  
- Open: http://localhost:3000
- Expected UI: AuthScreen with email/password form

**RESULT:**  
- [ ] PASS - Server running on correct port
- [ ] PASS - AuthScreen renders with form

---

### Step 2: Sign In Flow (AuthScreen → HomeScreen)
**Flow:** Email + Password → Cognito InitiateAuth → JWT Token → Redirect to HomeScreen

**Test Steps:**
1. Navigate to http://localhost:3000
2. Enter credentials:
   - Email: `e2e_6576874@journalm8.local`
   - Password: `TestPass123!`
3. Click "Sign In"
4. Observe network requests

**Expected Behavior:**
- Network call: `POST https://cognito-idp.us-east-1.amazonaws.com/` (InitiateAuth)
- Response: `{ AuthenticationResult: { IdToken: "...", AccessToken: "...", ... } }`
- Browser: Redirects to HomeScreen
- Browser storage: `localStorage.idToken` contains JWT

**Backend Endpoints Hit:**
- Cognito InitiateAuth: ✅ (no API Gateway)

**RESULT:**
- [ ] PASS - Cognito authentication succeeds
- [ ] PASS - JWT token stored in localStorage
- [ ] PASS - HomeScreen displays with user email
- [ ] FAIL - ______

---

### Step 3: List Entries (HomeScreen)
**Flow:** Fetch GET /entries → Display recent entries list

**Test Steps:**
1. After sign in, observe HomeScreen
2. Wait 2 seconds for entries to load
3. Look for "Recent Entries" section

**Expected Behavior:**
- Network call: `GET https://iq1gf00t2a.execute-api.us-east-1.amazonaws.com/entries`
- Headers: `Authorization: Bearer <idToken>`
- Response: `[ { entryId: "...", status: "...", ... }, ... ]` (initially empty array)
- UI: "0 Total Entries" and "Recent Entries (0)"

**Backend Endpoint:**
- `GET /entries` (list_entries Lambda) ✅ Deployed

**RESULT:**
- [ ] PASS - GET /entries call succeeds with 200
- [ ] PASS - Properly formatted response array (even if empty)
- [ ] PASS - Stats display: "0 Total Entries"
- [ ] FAIL - ______

---

### Step 4: Upload Journal Image (UploadScreen)
**Flow:** Select image → POST /uploads/presign → Presign S3 URL → PUT file to S3 → S3 event triggers start_ingestion Lambda

**Test Steps:**
1. From HomeScreen, click "Upload Image"
2. Click "Take Photo" or "Upload from Gallery"
3. Select a real handwritten journal image
4. Click "Upload"
5. Observe spinner while processing
6. Wait for "Processing..." message

**Expected Behavior:**

**Network Call 1: Get Presigned URL**
- `POST https://iq1gf00t2a.execute-api.us-east-1.amazonaws.com/uploads/presign`
- Headers: `Authorization: Bearer <idToken>`
- Body: `{ filename: "journal-<uuid>.png" }`
- Response: `{ uploadUrl: "https://journalm8-dev-raw-*.s3.amazonaws.com/users/...", entryId: "..." }`

**Network Call 2: Upload to S3**
- `PUT <presigned-url>`
- Body: Binary image data
- Response: HTTP 200 (no content)

**Server-Side Events:**
- S3 PutObject triggers S3 event notification
- start_ingestion Lambda invoked automatically
- Step Functions journal-ingestion state machine starts
- OCR Lambda processes image

**Backend Endpoints:**
- `POST /uploads/presign` (presign_upload Lambda) ✅ Deployed
- S3 event notification ✅ Configured (existing)
- start_ingestion Lambda ✅ Configured (existing)

**RESULT:**
- [ ] PASS - Presign endpoint returns valid upload URL
- [ ] PASS - File successfully uploaded to S3 (HTTP 200)
- [ ] PASS - Entry appears with "processing" status
- [ ] PASS - Redirects to EntryDetailScreen
- [ ] FAIL - ______

---

### Step 5: Poll for OCR Processing (EntryDetailScreen)
**Flow:** GET /entries/{entryId} every 2s → Wait for status=completed → Display rawText

**Test Steps:**
1. After upload, EntryDetailScreen displays
2. Observe spinner saying "Processing your image..."
3. Watch CloudWatch logs for OCR completion
4. Wait for "Review & Edit Transcript" button to appear

**Expected Behavior:**

**Polling Loop:**
- Every 2 seconds: `GET https://iq1gf00t2a.execute-api.us-east-1.amazonaws.com/entries/{entryId}`
- Headers: `Authorization: Bearer <idToken>`
- Response format: `{ entryId: "...", status: "processing" | "completed", rawText: "..." }`

**When status=completed:**
- rawText populated with OCR'd journal text
- Stop polling (clear interval)
- Display "Review & Edit Transcript" button
- Spinner disappears

**Timeline Expectations:**
- First request: `{ status: "processing", rawText: "" }`
- After 5-10 seconds: `{ status: "completed", rawText: "<ocr'd text>" }`
- Max wait: 60 seconds (timeout not yet implemented)

**Backend Endpoint:**
- `GET /entries/{entryId}` (get_entry Lambda) ✅ Deployed

**RESULT:**
- [ ] PASS - Polling succeeds with proper response format
- [ ] PASS - Detects status=completed
- [ ] PASS - rawText displays OCR'd journal content
- [ ] PASS - Button appears and clickable
- [ ] FAIL - ______

---

### Step 6: Review & Edit Transcript (TranscriptReviewScreen)
**Flow:** Display rawText (read-only) + textarea for edits → Save → PUT /entries/{entryId}

**Test Steps:**
1. Click "Review & Edit Transcript" button
2. Observe left side: OCR'd text (read-only)
3. Observe right side: textarea with same text
4. Edit 1-2 words in textarea (e.g., fix OCR typos)
5. Click "Save"
6. Observe success checkmark
7. Wait 2 seconds for automatic redirect

**Expected Behavior:**

**Network Call: Save Edited Transcript**
- `PUT https://iq1gf00t2a.execute-api.us-east-1.amazonaws.com/entries/{entryId}`
- Headers: `Authorization: Bearer <idToken>`
- Body: `{ correctedText: "<edited text from textarea>" }`
- Response: `{ message: "Transcript updated successfully", reviewStatus: "REVIEWED", ... }`

**UI Feedback:**
- Disable save button during request
- Show success checkmark (✓) on save button
- After 2s: auto-redirect to HomeScreen

**Backend Endpoint:**
- `PUT /entries/{entryId}` (update_transcript Lambda) ✅ Deployed

**RESULT:**
- [ ] PASS - PUT /entries/{entryId} succeeds with 200
- [ ] PASS - Request body properly formatted (correctedText field)
- [ ] PASS - Success checkmark displays
- [ ] PASS - Auto-redirects to HomeScreen
- [ ] FAIL - ______

---

### Step 7: Verify Entry in List (HomeScreen Redux)
**Flow:** Redirected to HomeScreen → Fetch fresh entries list → New entry visible with "completed" status

**Test Steps:**
1. After save + redirect, observe HomeScreen
2. Wait 2 seconds for list to refresh
3. Look for newly uploaded entry in "Recent Entries" section
4. Verify status shows as completed

**Expected Behavior:**
- New network call: `GET /entries`
- Response now includes: `[ { entryId: "<uploaded-id>", status: "completed", correctedText: "<...>", ... } ]`
- UI updates:
  - "1 Total Entries"
  - "1 Processed Entries"
  - Recent Entries lists the new entry
  - Entry shows status "completed" (if displayed)

**Backend Endpoint:**
- `GET /entries` (list_entries Lambda) ✅ Deployed

**RESULT:**
- [ ] PASS - Entry appears in list with correct ID
- [ ] PASS - Status shows "completed"
- [ ] PASS - Stats update: "1 Total Entries", "1 Processed"
- [ ] PASS - Entry clickable to view details again
- [ ] FAIL - ______

---

## Part 3: Comprehensive PASS/FAIL Summary

### Backend Infrastructure
- [x] POST /uploads/presign deployed
- [x] GET /entries deployed  
- [x] GET /entries/{entryId} deployed
- [x] PUT /entries/{entryId} deployed
- [x] CORS configuration updated for GET/PUT

### Frontend - Authentication
- [ ] AuthScreen renders correctly
- [ ] Sign-in form accepts credentials
- [ ] Cognito authentication succeeds
- [ ] JWT token stored in localStorage
- [ ] User email displayed on HomeScreen

### Frontend - List Entries
- [ ] GET /entries succeeds
- [ ] Empty list displays (0 entries initially)
- [ ] Stats calculated correctly

### Frontend - Upload
- [ ] UploadScreen displays file picker
- [ ] Presign endpoint returns valid URL
- [ ] File uploads to S3 successfully
- [ ] Entry created with "processing" status
- [ ] Redirects to EntryDetailScreen

### Frontend - OCR Polling
- [ ] Polling requests succeed (GET /entries/{entryId})
- [ ] Response format correct
- [ ] Status transitions from "processing" → "completed"
- [ ] rawText populates with OCR result
- [ ] Button becomes clickable

### Frontend - Transcript Review
- [ ] TranscriptReviewScreen displays both panes
- [ ] Left pane read-only
- [ ] Right pane editable
- [ ] Save endpoint PUT succeeds
- [ ] Success feedback displays
- [ ] Auto-redirect to HomeScreen

### Frontend - Entry Visibility
- [ ] Entry appears in HomeScreen list
- [ ] Status displays as "completed"
- [ ] Stats update (total and processed counts)
- [ ] Entry clickable for re-review

---

## Part 4: Known Issues & Blockers

| Issue | Component | Status | Action |
|-------|-----------|--------|--------|
| PostCSS ES module | UI build | ✅ FIXED | Changed postcss.config.js to ESM export |
| Missing list/get/update endpoints | Backend API | ✅ FIXED | Deployed 3 new Lambda functions |
| CORS only allowed POST | API Gateway | ✅ FIXED | Updated to allow GET, POST, PUT |

---

## Test Execution Checklist

**Pre-Test:**
- [ ] Backend infrastructure deployed (Terraform apply complete)
- [ ] Dev server running (npm run dev on port 3000)
- [ ] Credentials ready (e2e_6576874@journalm8.local / TestPass123!)
- [ ] Real journal image available for upload
- [ ] Browser DevTools open (F12) to watch network requests

**Test Execution:**
- [ ] Step 1: Dev Server - PASS/FAIL ____
- [ ] Step 2: Sign In - PASS/FAIL ____
- [ ] Step 3: List Entries - PASS/FAIL ____
- [ ] Step 4: Upload - PASS/FAIL ____
- [ ] Step 5: OCR Polling - PASS/FAIL ____
- [ ] Step 6: Review & Save - PASS/FAIL ____
- [ ] Step 7: Entry Visibility - PASS/FAIL ____

**Overall Result:**  
- [x] All 4 backend endpoints deployed and accessible
- [ ] Complete end-to-end workflow validates through UI
- [ ] No missing functionality detected

---

## How to Run This Test

```bash
# Terminal 1: Start backend infrastructure
cd /Users/muhammadadeyemi/journalm8/journalm8/infra/envs/dev
terraform apply -auto-approve
# Output: http_api_endpoint = "https://iq1gf00t2a.execute-api.us-east-1.amazonaws.com"

# Terminal 2: Start UI dev server
cd /Users/muhammadadeyemi/journalm8/journalm8/ui
npm install
npm run dev
# Output: "Local: http://localhost:3000"

# Browser: http://localhost:3000
# Sign in with: e2e_6576874@journalm8.local / TestPass123!
# Follow Steps 1-7 above
```

---

## Next Steps After Validation

1. **If ALL PASS:** Workflow is production-ready for limited daily use
2. **If ANY FAIL:** Debug specific endpoint, check CloudWatch logs, fix Lambda code
3. **Phase 2B:** Monitor production for errors, add error handling, implement timeouts
4. **Phase 3:** Add Bedrock /ask endpoint for chat with journal history
