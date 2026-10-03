# Aegis Safety — Personal Safety App (Flutter + Firebase)

A production-grade personal safety application built with Flutter, Riverpod, Firebase Auth (Phone OTP), Cloud Firestore, Cloud Functions (Node.js/TypeScript), Google Maps Platform, AI-assisted Check-in, Companion Tracking, and Twilio SMS fallbacks.

---

## Features Overview

1. **Onboarding & Phone OTP Authentication** (`lib/features/auth/`)
2. **Home Screen with Central Long-Press SOS Trigger** (`lib/features/home/`) — 2-second hold prevents accidental fires.
3. **SOS Countdown & Auto-Escalation** (`lib/features/sos/`) — Visual countdown ring with server-side Cloud Function backup check.
4. **Live Location Sharing** (`lib/features/location/`) — Real-time location stream with duration controls and recipient picker.
5. **Trusted Contacts Manager** (`lib/features/contacts/`) — Priority drag-to-reorder list.
6. **Nearby Emergency Services** (`lib/features/emergency/`) — Police & Hospitals via Google Places API with 1-tap call (`ACTION_CALL`) and deep-link directions.
7. **AI Check-in / Safety Chat** (`lib/features/ai_checkin/`) — Multimodal fusion engine combining on-device audio CNN + text classifier scores.
8. **Active Emergency Status Feed** (`lib/features/sos/`) — Real-time dispatch telemetry for notified guardians and police network.
9. **Settings & Profile** (`lib/features/profile/`) — DigiLocker KYC official ID verification toggle and offline SMS fallback switch.
10. **GPS-Off Blocking Modal** (`lib/features/location/`) — System `PROVIDERS_CHANGED_ACTION` listener showing last known location sent to guardians.
11. **Companion Mode Setup** (`lib/features/companion/`) — Destination autocomplete and ETA picker.
12. **Companion Tracking** (`lib/features/companion/`) — Live route polyline check with guardian watching banner.
13. **Companion Route Deviation Alert** (`lib/features/companion/`) — Off-route threshold (>250m) and ETA delay check with auto-escalation timer.
14. **Location & Power Protection** (`lib/features/location/`) — Background sync status and power-off guardian telemetry documentation.

---

## Directory Structure

```text
├── lib/
│   ├── main.dart                          # App shell & top-level route controller
│   ├── core/
│   │   ├── models/                        # Firestore data models (User, Contact, SosEvent, etc.)
│   │   ├── providers/                     # Riverpod state notifiers (Auth, Location, SOS, Companion, AI)
│   │   ├── services/                      # AI Fusion Engine, Companion Deviation Engine, Secure Storage
│   │   └── theme/                         # Navy, Light Background, SOS Red color palette & typography
│   ├── features/                          # Feature modules (auth, home, sos, location, companion, etc.)
│   └── shared/
│       └── widgets/                       # Reusable components (PrimaryButton, DangerButton, AppCard, etc.)
├── functions/                             # Firebase Cloud Functions (TypeScript)
│   ├── src/
│   │   ├── index.ts                       # Function exports
│   │   ├── onSosCreated.ts                # SOS Firestore creation trigger
│   │   ├── checkSosTimeout.ts             # Server-side countdown check & FCM/Twilio dispatch
│   │   ├── onCompanionTripUpdate.ts       # Route deviation trigger
│   │   ├── onLocationPing.ts              # High-frequency location ping updater
│   │   ├── sendSmsFallback.ts             # Server-side Twilio Programmable SMS API call
│   │   └── verifyGovtId.ts                # DigiLocker KYC API endpoint
│   ├── package.json
│   └── tsconfig.json
├── test/                                  # Unit tests (AI Risk Fusion & Companion Deviation logic)
├── firestore.rules                        # User isolation & scoped guardian read security rules
├── firestore.indexes.json                 # Firestore composite indexes
├── .env.example                           # Client environment variable template
└── pubspec.yaml                           # Flutter dependencies
```

---

## Prerequisites & Required API Keys

### 1. Client Environment (`.env`)
Create a `.env` file in the root directory based on `.env.example`:
```ini
GOOGLE_MAPS_API_KEY=AIzaSyYourGoogleMapsApiKey
FIREBASE_API_KEY=YourFirebaseApiKey
FIREBASE_APP_ID=1:1234567890:android:example
FIREBASE_MESSAGING_SENDER_ID=1234567890
FIREBASE_PROJECT_ID=personal-safety-app-prod
FUNCTIONS_BASE_URL=https://us-central1-personal-safety-app-prod.cloudfunctions.net
```

### 2. Google Maps API Setup
1. Enable **Maps SDK for Android**, **Places API**, **Directions API**, and **Geocoding API** in the Google Cloud Console.
2. Restrict the Google Maps API key by **Android package name** and **SHA-1 fingerprint**.

### 3. Server-Side Cloud Function Secrets (Twilio & DigiLocker)
Set secrets in Firebase Functions environment (Secret Manager):
```bash
firebase functions:secrets:set TWILIO_ACCOUNT_SID
firebase functions:secrets:set TWILIO_AUTH_TOKEN
firebase functions:secrets:set TWILIO_PHONE_NUMBER
firebase functions:secrets:set DIGILOCKER_API_KEY
```

---

## Building and Running

### Running Flutter Unit Tests
```bash
flutter test
```

### Running the App Locally
```bash
flutter pub get
flutter run
```

### Building Cloud Functions
```bash
cd functions
npm install
npm run build
```

### Deploying Rules and Cloud Functions
```bash
firebase deploy --only firestore:rules,functions
```
