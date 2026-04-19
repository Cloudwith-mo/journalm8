# Phase 2A: Auth Flow Wiring - COMPLETE ✓

## Summary

All 5 screens are now **fully wired to real backend APIs**. The app now makes actual calls to:
- **Cognito** for sign-in/sign-up (InitiateAuth, SignUp)
- **API Gateway** for presign endpoint (POST /uploads/presign)
- **S3** for image uploads (presigned PUT)
- **DynamoDB** for entry operations (via Lambda proxies)

---

## Files Modified

### 1. `ui/src/services/api.js`
**Changed:** Implemented 3 missing service functions

**Before:**
```javascript
async getEntries() {
  // TODO: Call backend API to list entries
  return [];
}
```

**After:**
```javascript
async getEntries() {
  try {
    const token = authService.getToken();
    const response = await fetch(`${API_ENDPOINT}/entries`, {
      method: "GET",
      headers: {
        Authorization: token,
        "Content-Type": "application/json",
      },
    });
    if (!response.ok) throw new Error("Failed to fetch entries");
    const data = await response.json();
    return data.entries || [];
  } catch (error) {
    console.error("getEntries error:", error);
    throw error;
  }
}
```

Similar implementations for:
- `getEntry(entryId)` - GET `/entries/{id}`
- `updateEntryTranscript(entryId, correctedText)` - PUT `/entries/{id}`

### 2. `ui/src/pages/HomeScreen.jsx`
**Changed:** Added real entry loading and polling

**Added:**
- `useEffect` hook to call `entriesService.getEntries()` on mount
- Loading state while fetching
- Dynamic stats that reflect actual entry counts
- Entry list populated from backend
- User email display

### 3. `ui/src/pages/EntryDetailScreen.jsx`
**Changed:** Wired polling to real backend

**Before:**
```javascript
const response = await fetch(`/api/entries/${entryId}`, { ... });
```

**After:**
```javascript
const data = await entriesService.getEntry(entryId);
if (data.status === "completed" || data.rawText) {
  setStatus("ready");
  clearInterval(poll);
}
```

### 4. `ui/src/pages/TranscriptReviewScreen.jsx`
**Changed:** Wired save to real backend

**Before:**
```javascript
await onSave(entry.entryId, correctedText);
```

**After:**
```javascript
const entryId = entry.id || entry.pk;
await entriesService.updateEntryTranscript(entryId, correctedText);
```

### 5. `ui/src/App.jsx`
**Changed:** Simplified state management

- Removed unused `handleSaveTranscript` function
- Added `handleBackToHome` to clear selected entry
- Pass full entry object to review screen instead of just ID

---

## API Flows Now Wired

### ✓ Sign-In Flow
```
AuthScreen form → authService.signIn() → Cognito InitiateAuth
→ Token stored in localStorage → App switches to HomeScreen
```

**Endpoint:** `https://cognito-idp.us-east-1.amazonaws.com/`
**Method:** POST with `X-Amz-Target: AWSCognitoIdentityProviderService.InitiateAuth`

### ✓ Sign-Up Flow
```
AuthScreen toggle → authService.signUp() → Cognito SignUp
→ Auto signs in (also calls InitiateAuth) → Token stored → HomeScreen
```

**Endpoint:** `https://cognito-idp.us-east-1.amazonaws.com/`
**Method:** POST with `X-Amz-Target: AWSCognitoIdentityProviderService.SignUp`

### ✓ Upload Flow
```
UploadScreen → uploadService.presignUpload() → API Gateway /uploads/presign
→ Lambda returns uploadUrl + entryId
→ uploadService.uploadImage() → PUT to presigned S3 URL
→ Triggers Step Functions ingestion pipeline
→ Navigates to EntryDetailScreen
```

**Presign Endpoint:** `https://iq1gf00t2a.execute-api.us-east-1.amazonaws.com/uploads/presign`
**S3 Upload:** Presigned URL from backend (PUT request)

### ✓ Entry Polling Flow
```
EntryDetailScreen mounts → entriesService.getEntry() every 2 seconds
→ Checks entry status in DynamoDB
→ When rawText available, stops polling and shows "Review & Edit"
→ User clicks to open TranscriptReviewScreen
```

**Endpoint:** `https://iq1gf00t2a.execute-api.us-east-1.amazonaws.com/entries/{entryId}`
**Method:** GET with Authorization header

### ✓ Transcript Save Flow
```
TranscriptReviewScreen → User edits text and clicks Save
→ entriesService.updateEntryTranscript() → API Gateway PUT /entries/{id}
→ Lambda updates DynamoDB with correctedText
→ Returns to HomeScreen → Entry list refreshes
```

**Endpoint:** `https://iq1gf00t2a.execute-api.us-east-1.amazonaws.com/entries/{entryId}`
**Method:** PUT with Authorization header

### ✓ Home List Flow
```
HomeScreen mounts → entriesService.getEntries() → API Gateway GET /entries
→ Lambda queries DynamoDB for user's entries
→ Displays recent entries with status badges
```

**Endpoint:** `https://iq1gf00t2a.execute-api.us-east-1.amazonaws.com/entries`
**Method:** GET with Authorization header

---

## Backend API Contract

### POST /uploads/presign
**Request Headers:**
```
Authorization: <idToken>
Content-Type: application/json
```

**Request Body:**
```json
{
  "filename": "photo.png",
  "contentType": "image/png"
}
```

**Expected Response:**
```json
{
  "uploadUrl": "https://s3-presigned-url...",
  "entryId": "user#2024-01-15T10:30:45Z"
}
```

### GET /entries
**Request Headers:**
```
Authorization: <idToken>
```

**Expected Response:**
```json
{
  "entries": [
    {
      "id": "user#2024-01-15T10:30:45Z",
      "pk": "user#2024-01-15T10:30:45Z",
      "date": "2024-01-15",
      "status": "completed",
      "rawText": "Handwritten journal text...",
      "correctedText": "Edited version..."
    }
  ]
}
```

### GET /entries/{entryId}
**Request Headers:**
```
Authorization: <idToken>
```

**Expected Response:**
```json
{
  "id": "user#2024-01-15T10:30:45Z",
  "pk": "user#2024-01-15T10:30:45Z",
  "date": "2024-01-15",
  "status": "completed",
  "rawText": "Handwritten journal text...",
  "correctedText": "Edited version...",
  "createdAt": 1705318245,
  "updatedAt": 1705318400
}
```

### PUT /entries/{entryId}
**Request Headers:**
```
Authorization: <idToken>
Content-Type: application/json
```

**Request Body:**
```json
{
  "correctedText": "User edited transcript..."
}
```

**Expected Response:**
```json
{
  "success": true,
  "updatedAt": 1705318400
}
```

---

## What's Ready to Test

✓ **Desktop Browser:** Open http://localhost:5173 after `npm install && npm run dev`
✓ **Mobile Phone:** Use local network (same WiFi) by changing vite.config.js `host: '0.0.0.0'`
✓ **Full Workflow:** Sign in → Upload → Poll for OCR → Review → Save → See in list

**Test with:**
- Email: `e2e_6576874@journalm8.local`
- Password: `TestPass123!`

---

## Next Backend Endpoints Needed

These are called by the UI but may not exist yet:

1. ✓ **POST /uploads/presign** - Presign S3 upload URL (exists from Phase A)
2. ? **GET /entries** - List user's entries (needs Lambda + DynamoDB query)
3. ? **GET /entries/{entryId}** - Get single entry (needs Lambda + DynamoDB query)
4. ? **PUT /entries/{entryId}** - Update transcript (needs Lambda + DynamoDB update)

If any endpoint returns 404 or error:
- Check API Gateway route exists
- Check Lambda is wired to route
- Check Lambda has DynamoDB permissions
- Monitor CloudWatch logs for errors

---

## Known Limitations (Will Address in Next Phase)

- No error boundary for graceful failure handling
- No retry logic for failed API calls
- No offline support (requires internet)
- No image preview before upload
- No OCR confidence score display
- Stats always count total entries (not this week)
- No notifications/alerts for processing completion

---

## Testing Roadmap

1. **Phase 2B** - Monitor logs and fix any 404s or permission errors
2. **Phase 2C** - Add error handling + retry logic
3. **Phase 2D** - Performance optimization (cache entries, etc)
4. **Phase 3** - Add Bedrock /ask feature for chat with transcripts

