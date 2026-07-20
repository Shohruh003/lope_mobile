# Deep Link Deployment — Universal Links & Android App Links

This folder holds the three artifacts the **web/nginx side of `lopestyle.uz`** needs to publish before mobile deep links (SMS/Telegram/email → in-app) actually verify.

Until these are live, tapping `https://lopestyle.uz/book/xxx` opens the browser instead of the app.

---

## 1. Android — `assetlinks.json`

**Where it must be served:**
`https://lopestyle.uz/.well-known/assetlinks.json`

**What needs to be filled in:**
`sha256_cert_fingerprints[]` — one or more colon-separated SHA256 hashes of the **APK signing keys**. You need at least the **release** key; add the **debug** key too if you want deep links to work during local development.

**Get the release fingerprint (Play Store signing):**

```bash
# On your Mac/Linux/Windows machine with the release keystore:
keytool -list -v \
  -keystore ~/path/to/lopestyle-release.jks \
  -alias <your-key-alias> \
  | grep SHA256
```

**Get the Play App Signing fingerprint (recommended, if you use Play App Signing):**

1. Go to Google Play Console → your app → **Setup → App signing**
2. Copy the SHA-256 certificate fingerprint from the "App signing key certificate" section
3. Paste it as the first entry in `sha256_cert_fingerprints[]`

**Get the debug fingerprint (optional, for dev testing):**

```bash
keytool -list -v \
  -keystore ~/.android/debug.keystore \
  -alias androiddebugkey \
  -storepass android -keypass android \
  | grep SHA256
```

Replace `REPLACE_WITH_YOUR_RELEASE_SHA256` and `REPLACE_WITH_YOUR_DEBUG_SHA256_IF_TESTING` in `assetlinks.json` with the values (keep the colons: `AB:CD:EF:...`).

---

## 2. iOS — `apple-app-site-association`

**Where it must be served:**
`https://lopestyle.uz/.well-known/apple-app-site-association`

⚠️ **No file extension**. iOS rejects `.json`. Content-Type must still be `application/json`.

**What needs to be filled in:**
`appIDs[0]` — format: `<TEAM_ID>.<BUNDLE_ID>`
- Bundle ID (already correct in file): `uz.lopestyle.lopeMobile`
- Team ID: 10-character alphanumeric string from Apple Developer

**Get the Apple Team ID:**

1. Sign in at https://developer.apple.com/account
2. Top-right → **Membership Details**
3. Copy "Team ID" (looks like `A1B2C3D4E5`)

Then edit `apple-app-site-association`, replacing:

```
"REPLACE_WITH_APPLE_TEAM_ID.uz.lopestyle.lopeMobile"
```

with:

```
"A1B2C3D4E5.uz.lopestyle.lopeMobile"
```

**Also required in Xcode:**

1. Open `ios/Runner.xcworkspace`
2. Runner target → **Signing & Capabilities**
3. Click **+ Capability** → add **Associated Domains**
4. Add two entries:
   - `applinks:lopestyle.uz`
   - `applinks:app.lopestyle.uz`
5. Re-archive & re-upload to App Store Connect.

Without this Xcode capability, iOS won't even try to fetch the file.

---

## 3. Nginx — serve the two files

See `nginx.conf.snippet`. Two things matter:
- **No redirects.** Android/iOS refuse to follow 3xx during verification. If you have an `http → https` global redirect, the files still need to answer at both `http` and `https` (or verify the tools follow the redirect — safer to serve them from https directly).
- **Content-Type `application/json`** on both files (the snippet forces this via `default_type`).

Deploy the files to `/var/www/lopestyle/deep-links/` (or wherever the `alias` in the snippet points), reload nginx, then verify:

```bash
curl -sI https://lopestyle.uz/.well-known/assetlinks.json
curl -sI https://lopestyle.uz/.well-known/apple-app-site-association
```

Both must return `HTTP/2 200` and `content-type: application/json`.

---

## 4. Verify the setup

**Android:**

```bash
# Once the app is installed on a device, ask the system whether the
# domain is verified. `1` means yes, `0` no.
adb shell pm get-app-links uz.lopestyle.lope_mobile
```

Or use Google's live validator: <https://developers.google.com/digital-asset-links/tools/generator>

**iOS:**

Apple's live validator: <https://branch.io/resources/aasa-validator/> — paste `lopestyle.uz` and confirm all sections are green.

---

## 5. What breaks if you skip a step

| Skipped step                    | Symptom                                                        |
|---------------------------------|----------------------------------------------------------------|
| Wrong SHA256 in assetlinks      | Android opens browser instead of app                           |
| Wrong Team ID in AASA           | iOS opens Safari instead of app                                |
| `.json` extension on iOS file   | iOS silently fails verification, opens Safari                  |
| Missing Content-Type            | Both platforms fail verification, open browser                 |
| 3xx redirect in the way         | Verification fails; browser opens                              |
| Missing Xcode Associated Domain | iOS never checks the AASA file at all                          |

---

## Ready-to-deploy summary

1. **You** (developer): run the `keytool` command for release + debug SHA256, get Apple Team ID.
2. **You**: edit `assetlinks.json` and `apple-app-site-association` in this folder with those values.
3. **Web/DevOps**: copy the two edited files to the server, apply the nginx snippet, reload nginx.
4. **You**: in Xcode, add the Associated Domains capability, re-archive iOS build.
5. **You**: verify with the two curl commands + Google/Branch validators.
6. Send a test SMS with `https://lopestyle.uz/book/<some-barber-id>` to a real device with the app installed — it should open directly in the app.
