# JournalM8 UI - Phase B

Mobile-first PWA built with React + Vite + Tailwind CSS.

## File Structure

```
ui/
├── package.json                 # Dependencies
├── vite.config.js              # Build config
├── tailwind.config.js          # Tailwind setup
├── postcss.config.js           # PostCSS config
├── index.html                  # Entry point
├── public/
│   └── manifest.json           # PWA manifest
└── src/
    ├── main.jsx                # React root
    ├── App.jsx                 # Main app routing
    ├── index.css               # Tailwind imports
    ├── pages/
    │   ├── AuthScreen.jsx      # Sign in/up
    │   ├── HomeScreen.jsx      # Entry list & quick upload
    │   ├── UploadScreen.jsx    # Camera/gallery & upload
    │   ├── EntryDetailScreen.jsx   # Processing status
    │   └── TranscriptReviewScreen.jsx # Edit & save
    └── services/
        └── api.js              # Cognito & S3 API calls
```

## Screen Flow

1. **AuthScreen** - USER_PASSWORD_AUTH login
2. **HomeScreen** - Recent entries + "New Entry" button
3. **UploadScreen** - Camera or gallery picker
4. **EntryDetailScreen** - Poll for OCR status
5. **TranscriptReviewScreen** - Edit raw/corrected text

## Implementation Order

✅ Phase 1: Project structure & scaffolding
  - [x] Vite + React + Tailwind setup
  - [x] All 5 screen components (skeleton)
  - [x] API service layer

→ Phase 2: Auth flow (NEXT)
  - [ ] Wire up Cognito sign in
  - [ ] Token storage & refresh
  - [ ] Protected navigation

→ Phase 3: Upload flow
  - [ ] Camera permission handling
  - [ ] File → presign → S3 upload
  - [ ] Progress tracking

→ Phase 4: Entry polling
  - [ ] DynamoDB query for status
  - [ ] Auto-refresh while processing
  - [ ] Display OCR results

→ Phase 5: Transcript review
  - [ ] Backend endpoint to save corrections
  - [ ] Offline support (optional)

→ Phase 6: Entry list
  - [ ] List recent entries
  - [ ] Quick stats dashboard

→ Phase 7: Real journal E2E test
  - [ ] Use actual handwritten journal image
  - [ ] Full workflow through UI
  - [ ] Verify production readiness

## Setup & Run

```bash
cd ui
npm install
npm run dev
```

Opens at http://localhost:3000

## Backend API Integration Points

1. **Cognito**
   - `InitiateAuth` (USER_PASSWORD_AUTH)
   - `SignUp` (optional self-service)

2. **Upload Presign**
   - `POST /uploads/presign` with JWT token
   - Returns: entryId, uploadUrl, bucket, key

3. **Entry Status** (TODO - create if not exists)
   - `GET /entries/{entryId}` with JWT token
   - Returns: status, rawText, correctedText, timestamps

4. **Save Transcript** (TODO - create)
   - `PUT /entries/{entryId}` with JWT token
   - Updates: correctedText, reviewStatus

## Mobile Optimization

- Phone-first responsive (max-width: 28rem)
- Touch-friendly buttons (min 44px)
- Camera input with native picker
- Zero external dependencies beyond React
- PWA manifest for home screen installation

## Next: Wire up Auth

Ready to implement real Cognito flow & test sign in.
