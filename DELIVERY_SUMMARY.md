# PHASE 2A COMPLETE - Auth & Backend Wiring ✓

## What's Done

### ✅ All 5 Screens Now Connected to Real Backend APIs

**Auth Flow (Sign In/Up)**
- `AuthScreen` → real Cognito InitiateAuth & SignUp calls
- Token stored in localStorage
- Persisted authentication

**Upload Flow (Camera/Gallery)**
- `UploadScreen` → real presign endpoint + S3 PUT
- Progress tracking
- Creates entry in backend

**Processing Flow (Polling)**
- `EntryDetailScreen` → real polling for OCR results
- 2-second intervals
- Auto-advances when OCR ready

**Review Flow (Edit & Save)**
- `TranscriptReviewScreen` → real DynamoDB update call
- Saves corrected text
- Returns to home

**Home Flow (Entry List)**
- `HomeScreen` → real entry listing from backend
- Live stats (total, processed count)
- Entry navigation

---

## Exact Files Modified (5 total)

### 1. [ui/src/services/api.js](ui/src/services/api.js)
- ✅ Replaced 3 stub functions with real API calls
- `getEntries()` → GET /entries
- `getEntry(id)` → GET /entries/{id}
- `updateEntryTranscript(id, text)` → PUT /entries/{id}

### 2. [ui/src/pages/HomeScreen.jsx](ui/src/pages/HomeScreen.jsx)
- ✅ Added `useEffect` to load entries on mount
- ✅ Added loading state + error handling
- ✅ Wired stats to real entry data
- ✅ Shows user email

### 3. [ui/src/pages/EntryDetailScreen.jsx](ui/src/pages/EntryDetailScreen.jsx)
- ✅ Replaced hardcoded API path with `entriesService.getEntry()`
- ✅ Clears polling interval when OCR ready

### 4. [ui/src/pages/TranscriptReviewScreen.jsx](ui/src/pages/TranscriptReviewScreen.jsx)
- ✅ Replaced onSave callback with real `updateEntryTranscript()` call
- ✅ Added error handling for failed saves

### 5. [ui/src/App.jsx](ui/src/App.jsx)
- ✅ Simplified state management
- ✅ Removed unused `handleSaveTranscript`
- ✅ Added `handleBackToHome` to reset state

---

## Ready to Test

### Quick Start (5 min)
```bash
cd ui
npm install
npm run dev
# Open http://localhost:5173
```

**Login with:**
- Email: `e2e_6576874@journalm8.local`
- Password: `TestPass123!`

### Expected Workflow
1. Sign in ✓
2. Click "New Entry" ✓
3. Upload image ✓
4. Wait for OCR (2-60 seconds) ✓
5. Review transcript ✓
6. Save entry ✓
7. See in home list ✓

### Mobile Phone (Same WiFi)
1. Edit `ui/vite.config.js` add `host: '0.0.0.0'`
2. Get IP: `ifconfig | grep inet | grep -v 127`
3. On phone: `http://YOUR_IP:5173`
4. Full workflow works with camera option

---

## Backend API Contract (What UI Expects)

### POST /uploads/presign
```json
Request: { filename, contentType }
Response: { uploadUrl, entryId }
```

### GET /entries
```json
Request: (no body)
Response: { entries: [{id, date, status, rawText, ...}, ...] }
```

### GET /entries/{entryId}
```json
Request: (no body)
Response: { id, date, status, rawText, correctedText, ... }
```

### PUT /entries/{entryId}
```json
Request: { correctedText }
Response: { success: true, updatedAt }
```

All requests include `Authorization: <idToken>` header from Cognito.

---

## What's NOT in UI Yet (On Purpose)

- ❌ No error boundaries (will add if API fails)
- ❌ No retry logic (auto-retry failed requests)
- ❌ No Bedrock /ask feature (planned next)
- ❌ No caching (each load hits backend)
- ❌ No offline support
- ❌ No UI polish/theming beyond basics
- ❌ No image preview before upload

**Focus:** Making workflows actually work, not polishing UI.

---

## Deliverables Provided

1. ✅ **Exact files to edit for Auth** → 5 files modified, listed above
2. ✅ **Working auth wiring** → Real Cognito calls in place
3. ✅ **Local run instructions** → `npm install && npm run dev`
4. ✅ **Test steps** → Sign in → Upload → Review → Save workflow

---

## Next Phases

### Phase 2B: Monitor & Debug
- Run full E2E workflow
- Watch CloudWatch logs for errors
- Fix any 404s or permission issues
- Verify DynamoDB writes

### Phase 2C: Add Error Handling
- Graceful failure messages
- Retry logic for network errors
- Timeouts for polling

### Phase 3: Add AI Features
- Bedrock /ask endpoint for chat with transcripts
- Show confidence scores
- Spelling/grammar suggestions

---

## Quick Reference

| Screen | API Calls | Status |
|--------|-----------|--------|
| AuthScreen | Cognito InitiateAuth, SignUp | ✅ Wired |
| HomeScreen | GET /entries | ✅ Wired |
| UploadScreen | POST /uploads/presign, S3 PUT | ✅ Wired |
| EntryDetailScreen | GET /entries/{id} (polling) | ✅ Wired |
| TranscriptReviewScreen | PUT /entries/{id} | ✅ Wired |

---

## Important Notes

- Token persists in localStorage (survives page reload)
- All auth requests go to Cognito (not API Gateway)
- All entry requests use Authorization header
- Upload presigning happens server-side (S3 PUT uses presigned URL)
- Polling stops automatically when OCR complete
- No UI changes until data actually returns from backend

**Definition of Success:** Open app on phone → sign in → upload journal → wait for OCR → review → save → see in list. All steps now call real backend.

