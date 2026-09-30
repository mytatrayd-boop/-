# Asraty (أسرتي) — Project instructions for Claude Code

Family chores & rewards app for Saudi families. Parents/admins assign tasks, members (mostly kids 6–16) complete them, admins approve, points unlock reward tiers. Arabic-only, RTL.

## Source of truth
- `docs/SPEC.md` — full product spec (Arabic). Read it before any feature work.
- `design/prototype.html` — working clickable prototype. It is the reference for every screen, flow, copy text, color and avatar. Open it in a browser and match it. Its JS (`avatarSVG`, `AVS`, scoring functions, permission checks) is the reference logic.
- `design/app-icon.svg`, `design/app-icon-1024.png` — app icon. `design/logo-full.jpg` — full logo for splash/store listing.

## Stack (decided)
- **Flutter** (latest stable), single codebase for iOS + Android. State: Riverpod. Routing: go_router.
- **Firebase (free Spark plan)**: Auth (custom token), Cloud Firestore (`me-central2`), Cloud Messaging (push). No Cloud Storage / Cloud Functions: Blaze billing in Saudi Arabia goes through CNTXT, which requires a commercial registration.
- **API server**: TypeScript in `functions/`, deployed to **Vercel** (`api/[name].ts`) speaking the Firebase callable protocol; the app calls it with `httpsCallableFromUri(SERVER_URL/api/<name>)`. `functions/src/index.ts` can still deploy the same handlers as Cloud Functions if the project moves to Blaze.
- Email: Gmail SMTP with an app password (`GMAIL_USER`, `GMAIL_APP_PASSWORD`), or Resend (`RESEND_API_KEY`, `MAIL_FROM`). Server env vars only, never in the app.
- Fonts: Tajawal (body), Baloo Bhaijaan 2 (headings), bundled in `app/assets/fonts` (no runtime download).
- SVG avatars via `flutter_svg`; port the 12 avatars from `avatarSVG()` in the prototype as SVG strings.

## Non-negotiable rules
- App is RTL Arabic everywhere (`Locale('ar')`, `TextDirection.rtl`). All user-facing strings in an `l10n` ARB file, copy taken from the prototype.
- **All point changes, approvals, competition ranking and permission checks happen server-side** (callable Cloud Functions + Firestore security rules). The client never writes points or ledger entries directly.
- Competition rank must be assigned inside a Firestore transaction (race-safe).
- Time periods use `Asia/Riyadh`; the week starts on **Sunday**.
- Auth codes: 6 digits, stored **hashed** with expiry (30 min) and max 5 attempts; rate-limit sends per email.
- Children's data: collect the minimum (name, email, avatar key). No ads, no third-party analytics SDKs that collect personal data. Support in-app account deletion (App Store requirement) and family deletion by the owner.
- Proof photos are optional; resized on device, stored as base64 in `families/{fid}/proofs/{completionId}` (server-written), deleted on approve/reject.
- Feedback emails go to `asraty200@gmail.com` (config value `SUPPORT_EMAIL`).

## Colors (from prototype)
brand `#2F6158`, gold `#D9B26A`, gold-deep `#B8893A`, background `#F6F2E8`, card `#FFFFFF`, ink `#1E302C`, muted `#66736F`, mint `#2E9E78`, red `#C8424A`. Dark mode tokens are in the prototype CSS.

## Layout
- `app/` Flutter app · `functions/` API server (TypeScript; `src/` shared handlers, `api/` Vercel entry, `public/` privacy & account-deletion pages) · `firestore.rules`, `firebase.json` · `docs/RELEASE.md` store release guide.
- `app/env.prod.json` holds the Firebase client config and `SERVER_URL` (public values, committed); the store build workflows use it.
- `app/lib/backend/backend.dart` is the single interface the UI uses; `FirebaseBackend` (real) and `DemoBackend` (on-device quick trial, mirrors the server rules — keep the two in sync with `functions/src/api.ts`).
- Build config comes from `--dart-define-from-file=env.json` (see `app/env.example.json`); without Firebase values the app runs demo-only.
- Tests: `cd app && flutter test` · `cd functions && npm test && npm run test:rules && npm run test:api` (emulators, needs Java). `npm run dev` runs the API locally against the emulators on :5055.

## Working style
- Build in the phases listed in `docs/SPEC.md` §10. Finish, test and summarize each phase before starting the next.
- Write Firestore security rules and their emulator tests alongside each feature.
- Use the Firebase Emulator Suite for local development; seed script creates the demo family from the prototype (`demoSeed`).
- Keep code identifiers and comments in English; UI text in Arabic.
