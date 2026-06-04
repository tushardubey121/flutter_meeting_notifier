# ✈ Meeting Notifier — Setup Guide

A Flutter desktop app that shows a plane flying across your screen with a flag
banner 5 minutes before every Google Calendar meeting.

---

## What You'll Need

- Flutter SDK 3.10+ installed → https://docs.flutter.dev/get-started/install
- A Google account with Google Calendar
- ~15 minutes for first-time setup

---

## Step 1 — Set Up Google Cloud OAuth Credentials

This is a one-time setup so the app can read your calendar.

### 1.1 Create a Google Cloud Project

1. Go to → https://console.cloud.google.com/
2. Click **"New Project"** (top left dropdown)
3. Name it `MeetingNotifier` → click **Create**

### 1.2 Enable Google Calendar API

1. In your new project, go to **APIs & Services → Library**
2. Search for **"Google Calendar API"**
3. Click it → click **"Enable"**

### 1.3 Set Up the OAuth Consent Screen

1. Go to **APIs & Services → OAuth consent screen**
2. Choose **"External"** → click **Create**
3. Fill in:
   - App name: `Meeting Notifier`
   - User support email: your email
   - Developer contact email: your email
4. Click **Save and Continue** (skip Scopes for now)
5. On "Test users" → click **"Add Users"** → add your Gmail address
6. Click **Save and Continue**

### 1.4 Create OAuth Client ID (Desktop app)

1. Go to **APIs & Services → Credentials**
2. Click **"+ Create Credentials" → "OAuth client ID"**
3. Application type: **Desktop app**
4. Name: `Meeting Notifier Desktop`
5. Click **Create**
6. A popup shows your **Client ID** and **Client Secret** — keep this open!

---

## Step 2 — Configure the App

### 2.1 Add your credentials

Open `lib/services/calendar_service.dart` and find the `GoogleSignIn` initialization.

Then open `android/app/src/main/res/values/strings.xml` (create it if missing)
and add your client ID — OR — for macOS/Windows desktop, the `google_sign_in`
package uses a different flow. 

**For desktop, create this file:**

```
lib/google_client_id.dart
```

```dart
// ⚠️ Add to .gitignore — never commit credentials!
const googleClientId = 'YOUR_CLIENT_ID.apps.googleusercontent.com';
const googleClientSecret = 'YOUR_CLIENT_SECRET';
```

Then update `lib/services/calendar_service.dart`:

```dart
final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: _scopes,
  clientId: googleClientId,      // add this line
  clientSecret: googleClientSecret, // add this line
);
```

### 2.2 Add to .gitignore

```
lib/google_client_id.dart
```

---

## Step 3 — Install Flutter Dependencies

```bash
# Navigate to the project folder
cd meeting_notifier

# Get all packages
flutter pub get
```

---

## Step 4 — Run the App

### macOS
```bash
flutter run -d macos
```

### Windows
```bash
flutter run -d windows
```

---

## Step 5 — Build Release Executables

### macOS (.app)
```bash
flutter build macos --release
# Output: build/macos/Build/Products/Release/meeting_notifier.app
```

### Windows (.exe)
```bash
flutter build windows --release
# Output: build/windows/x64/runner/Release/meeting_notifier.exe
```

---

## How It Works

```
App starts
  └─ Tries silent Google Sign-In (remembers you next time)
  └─ If not signed in, shows Sign In button

After sign-in
  └─ Fetches your Google Calendar events for the next 24 hours
  └─ Starts a 60-second polling timer
  └─ Every minute: checks if any meeting starts in ≤ 5 minutes

When a meeting is 5 minutes away
  └─ ✈ A plane flies across your screen from left to right
  └─ 🚩 A flag banner unfurls with:
       - Meeting title
       - "In X minutes" countdown
       - Start time
       - [Join] button (if Google Meet link found)
  └─ Auto-dismisses after 12 seconds
  └─ Click [Join] to open Google Meet in your browser
```

---

## Testing Without Waiting for a Meeting

Click the ✈ plane icon in the top-right of the app to trigger
a test fly-over animation instantly.

---

## Troubleshooting

**"Sign in failed"**
- Make sure your email is added as a Test User in the OAuth consent screen
- Check that Google Calendar API is enabled in your Cloud project

**"Failed to load calendar"**
- Check your internet connection
- Try signing out and back in (click your avatar → Sign out)

**Plane doesn't appear**
- Make sure the app window isn't in full-screen mode
- The overlay uses Flutter's Overlay system and renders above the app content

**macOS: "App can't be opened" warning**
- Right-click the .app → Open → Open anyway
- Or: System Settings → Privacy & Security → Open Anyway

**Windows: SmartScreen warning**
- Click "More info" → "Run anyway" (expected for unsigned apps)

---

## Project Structure

```
lib/
├── main.dart                    # Entry point, window setup
├── models/
│   └── meeting.dart             # Meeting data model
├── screens/
│   └── home_screen.dart         # Main UI + overlay trigger
├── services/
│   └── calendar_service.dart    # Google Auth + Calendar API
└── widgets/
    ├── plane_notification.dart  # ✈ The fly-over animation
    └── meeting_card.dart        # Meeting list item
```

---

## Next Steps (after MVP)

- [ ] System tray icon so the window stays hidden until needed
- [ ] Configurable alert timing (1 min, 5 min, 10 min)
- [ ] Support for Zoom and Teams meeting links
- [ ] Sound notification when the plane flies
- [ ] macOS notification center integration
- [ ] Auto-launch at login
