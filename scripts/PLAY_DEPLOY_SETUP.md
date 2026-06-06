# Google Play Deployment Setup

Automated AAB uploads to Google Play Internal Testing for TV Parser (`com.quasar.tvparser`).

---

## Architecture

```
You (manual)                              Script (automated)
─────────────                             ──────────────────
1. Create service account in GCP    →     
2. Download JSON key                →     Reads key from env var
3. Store key OUTSIDE this repo      →     Rejects in-repo keys
4. Add service account to Play Console →  
5. Run deploy script                →     Uploads AAB → Internal Testing
                                          STOPS. No auto-promotion.
6. Review in Play Console           →     Manual production decision
```

---

## Step 1: Google Cloud Console

1. Go to [console.cloud.google.com](https://console.cloud.google.com/)
2. Create or select a project (e.g., "TV Parser Deploy")
3. Go to **APIs & Services → Library**
4. Search **Google Play Android Developer API** → Click **Enable**
5. Go to **IAM & Admin → Service Accounts**
6. Click **Create Service Account**
   - Name: `tv-parser-play-deploy`
   - Skip project-level IAM roles
7. Click on the created account → **Keys** tab → **Add Key → JSON**
8. Save the downloaded file to a **secure location outside this repo**:
   ```
   C:\Users\YourName\secrets\tv-parser-play-deploy.json
   ```

> ⚠️ **Never store this file inside the TV Parser project folder.**
> The deploy script actively rejects keys located inside the repo.

---

## Step 2: Google Play Console

1. Go to [play.google.com/console](https://play.google.com/console)
2. Navigate to **Users and permissions**
3. Click **Invite new users**
4. Enter the service account email:
   ```
   tv-parser-play-deploy@YOUR-PROJECT-ID.iam.gserviceaccount.com
   ```
5. Under **App permissions**, click **Add app** → select **TV Parser**
6. Grant **only** these permissions:
   - ✅ View app information and download bulk reports
   - ✅ Create, edit, and roll out releases to testing tracks
   - ✅ Manage testing tracks and edit tester lists
7. Do **NOT** grant:
   - ❌ Release to production
   - ❌ Manage store presence
   - ❌ View financial data
   - ❌ Manage users
8. Click **Invite user**

---

## Step 3: Set Environment Variable

```powershell
# Set for current session
$env:GOOGLE_PLAY_SERVICE_ACCOUNT_JSON = "C:\Users\YourName\secrets\tv-parser-play-deploy.json"

# Or set permanently (user-level)
[Environment]::SetEnvironmentVariable("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", "C:\Users\YourName\secrets\tv-parser-play-deploy.json", "User")
```

---

## Step 4: Build and Deploy

```powershell
# Build the signed AAB
cd android
.\gradlew.bat :app:bundleRelease
cd ..

# Deploy to Internal Testing
.\scripts\deploy-internal.ps1
```

With release notes:
```powershell
.\scripts\deploy-internal.ps1 -ReleaseNotes "AI search, Premium Plus curation, Android TV support"
```

---

## What the Script Does

1. Reads `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` env var — **fails if not set**
2. Validates the JSON key file exists and is **outside the repo**
3. Authenticates via OAuth2 JWT with the Android Publisher API
4. Creates an edit session
5. Checks existing versionCodes — **fails on duplicates**
6. Uploads `build/app/outputs/bundle/release/app-release.aab`
7. Assigns the upload to the **internal** track only
8. Commits the edit
9. Prints: track, versionCode, AAB size, timestamp

**The script never promotes to Production.** That requires manual action in Play Console.

---

## What is NOT in this repo

| File | Location | Status |
|------|----------|--------|
| Service account JSON key | Outside repo (your secrets folder) | ✅ .gitignore blocks all patterns |
| Keystore (.jks) | Outside repo or android/app/ | ✅ .gitignore blocks |
| key.properties | Outside repo or android/ | ✅ .gitignore blocks |

---

## Security

- **Key compromised?** → Google Cloud Console → IAM → Service Accounts → Keys → Delete key → Generate new one
- **Key rotation**: Recommended every 90 days
- **CI/CD**: Store as encrypted secret, write to temp file, delete after use
- **Audit**: Check Play Console → Activity log for unexpected uploads

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON is not set` | Set the environment variable (Step 3) |
| `key must be stored OUTSIDE the repository` | Move the JSON key to a folder outside the project |
| `versionCode already exists` | Bump `+N` in `pubspec.yaml` version, rebuild |
| `The caller does not have permission` | Check Play Console permissions (Step 2) |
| `Google Play Developer API not enabled` | Enable it in Cloud Console (Step 1) |
| `Authentication failed` | Regenerate the JSON key, check it's not expired |
