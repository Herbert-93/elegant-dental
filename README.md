# Elegant Dental Care – Management System (Flutter Web + Firebase)

Two sides, one app:

| | Operations staff | Admin |
|---|---|---|
| Register patients (day no., name, age, address, phone, treatment) | Yes | Yes |
| Record treatment cost / payment | Yes | Yes |
| Patient records + receipts (print / PDF) | Yes | Yes |
| Dashboard (live patients, treated, waiting, revenue, any date) | **No** | Yes |
| Staff accounts, delete records | **No** | Yes |

Access control is enforced twice: the app never builds admin screens for operations users, and `firestore.rules` blocks them at the database level.

---------------------------------------------------------------------
## HOW THIS REPO IS ORGANISED
This folder is a **complete, ready-to-push repository**. It already contains `web/`, `Dockerfile`, `nginx.conf.template`, `render.yaml`, `.gitignore` and `firestore.rules`. You do NOT need to run `flutter create`. Render builds Flutter itself inside Docker, so you do not even need Flutter installed to deploy (you only need it if you want to test on your own computer).

## STEP 1 - Firebase setup (do this first, in the browser)
1. https://console.firebase.google.com -> **Add project** (e.g. elegant-dental-care).
2. **Build -> Authentication -> Get started -> Sign-in method -> Email/Password -> Enable -> Save.**
3. **Build -> Firestore Database -> Create database** -> pick a location -> **Production mode**.
4. **Firestore -> Rules** -> delete everything, paste the contents of `firestore.rules` -> **Publish**.
5. **Project settings (gear) -> General -> Your apps -> Web `</>`** -> register app (do not tick Hosting) -> copy the config values.

## STEP 2 - Put your details in the code
1. Open `lib/firebase_options.dart` and replace every `PASTE_...` with your values (apiKey, authDomain, projectId, storageBucket, messagingSenderId, appId). Firebase web keys are not secrets, so committing them is normal; your data is protected by the Firestore rules.
2. Open `lib/config.dart`: set the clinic address, phone, currency (default UGX).

## STEP 3 - Create the FIRST admin (one-time, manual)
1. **Authentication -> Users -> Add user** -> email + password. Copy the **User UID**.
2. **Firestore -> Start collection** -> ID `users` -> Document ID = that UID (paste exactly) -> fields:
   - `name` (string) e.g. Dr. Admin
   - `email` (string) same email
   - `role` (string) `admin`
   - `active` (boolean) `true`
All other staff are created later inside the app (Admin -> Staff -> Add Staff).

## STEP 4 - Push to GitHub
1. On https://github.com click **New repository** -> name `elegant-dental` -> keep it empty (no README/.gitignore) -> Create.
2. Open a terminal inside this project folder (the one containing `pubspec.yaml`):
```bash
git init
git add .
git commit -m "Elegant Dental Care system"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/elegant-dental.git
git push -u origin main
```
(If asked for a password, use a GitHub Personal Access Token: GitHub -> Settings -> Developer settings -> Personal access tokens.)
3. Check on GitHub that `Dockerfile`, `pubspec.yaml`, `lib/` and `web/` are visible at the **top level** of the repo (not inside a sub-folder).

## STEP 5 - Deploy on Render from the GitHub repo
**Option A - Blueprint (easiest, uses render.yaml):**
1. https://dashboard.render.com -> **New + -> Blueprint** -> connect GitHub -> select `elegant-dental` -> **Apply**.

**Option B - Manual:**
1. **New + -> Web Service** -> connect GitHub -> select the repo.
2. Language/Runtime: **Docker**. Branch: `main`. Root Directory: leave blank. Instance type: Free (it sleeps after inactivity and wakes in ~1 min) or Starter (always on).
3. **Create Web Service.**

The first build takes about 5-10 minutes (watch the Logs tab; it ends with "Your service is live"). You get a URL like `https://elegant-dental-care.onrender.com`.

## STEP 6 - Authorise your Render domain in Firebase (required)
Firebase Console -> **Authentication -> Settings -> Authorized domains -> Add domain** -> `elegant-dental-care.onrender.com` (your real Render URL, without https://). Without this, login fails on the live site.

## STEP 7 - Test the live site
Open your Render URL -> log in as admin -> Staff -> Add Staff (Operations) -> sign out -> sign in as that user -> register a patient -> Record treatment -> Receipt (Print / Download PDF) -> sign in as admin and check the Dashboard.

## Updating the system later
Edit code -> `git add . && git commit -m "change" && git push`. Render rebuilds and redeploys automatically.

## Optional: run on your own computer first
Install Flutter 3.24.5, then in the project folder: `flutter pub get` and `flutter run -d chrome`.

## Troubleshooting
- **"Could not load your profile / no access"** after login: the `users/<UID>` document is missing, UID doesn't match, `active` isn't boolean `true`, or rules weren't published.
- **Login works locally but not on Render**: add the Render domain to Authorized domains (Step 6).
- **Blank page on Render**: check Render logs; confirm `firebase_options.dart` has real values.
- **Version conflicts on `flutter pub get`**: run `flutter pub upgrade`.
- Patient numbers are typed by staff (suggested automatically); the same number can't be reused on the same day.
- Receipts use the receipt number `EDC-YYYYMMDD-NNN`.
- **Render build fails**: open the Logs tab and read the last error. Make sure `Dockerfile` and `pubspec.yaml` are in the repo's top level and Runtime is Docker.
- **Page refresh shows 404**: not possible with this setup (nginx rewrites every path to index.html).
