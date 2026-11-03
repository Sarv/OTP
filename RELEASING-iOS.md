# Releasing to iOS (TestFlight / App Store)

Once the one-time setup below is done, cutting an iOS release is the same single
action as Android: **push a version tag.** GitHub Actions
(`.github/workflows/release-ios.yml`) builds a **signed App Store `.ipa`** on a
macOS runner and uploads it to **TestFlight**. From TestFlight you install on
your own devices immediately, and promote the same build to the **App Store**
(for public release) in App Store Connect.

```bash
git tag v0.1.2
git push origin v0.1.2
```

The tag drives the version — `v0.1.2` produces `CFBundleShortVersionString`
`0.1.2`. The build number is the workflow run number, so every upload to App
Store Connect is unique (it rejects a repeated build number).

### Shipping a new build of the approved version

**0.1.3 is the current version.** Day to day, keep that version fixed and only
increment the build number — a new build of an approved version goes straight
to TestFlight testers without another App Review. Do **not** push a new version
tag for this; a tag creates a new marketing version that has to be reviewed.

Run it from **Actions -> Release iOS -> Run workflow**, or:

```bash
gh workflow run release-ios.yml -f version=0.1.3
```

Leave the build number blank and the workflow uses its run number, which only
ever increases, so it is always past the last upload. Pass
`-f build_number=<n>` only to force a specific number; it must exceed the last
upload for that version. Manual runs upload to TestFlight only and do not create a
GitHub Release.

> **Why TestFlight and not a downloadable `.ipa`?** iOS has no sideloading
> equivalent to an Android APK — an `.ipa` only installs on devices listed in its
> provisioning profile. TestFlight is the zero-friction "share a link, tap
> Install" path, and is the staging area the App Store promotes from. The GitHub
> Release still carries the `.ipa` as a build artifact for archival.

---

## What you need from Apple (requires the org Apple account)

All of this is created once, in accounts you (as Admin) control. None of it is in
this repo yet — the pipeline is ready and waiting for these values.

1. **Apple Developer Program enrollment** for the org ($99/yr). Gives you a
   **Team ID** (App Store Connect -> Membership, 10 chars like `A1B2C3D4E5`).
2. **An Apple Distribution certificate** exported as a password-protected
   **`.p12`** (Keychain Access -> export the "Apple Distribution: <Org>" identity,
   or create one in the Developer portal -> Certificates).
3. **An App ID** for `com.sarv.otp` (Developer portal ->
   Identifiers), then an **App Store provisioning profile** for that App ID,
   downloaded as a **`.mobileprovision`**. Note its exact **name**.
4. **An App Store Connect record** for the app (App Store Connect -> Apps -> +),
   bundle id `com.sarv.otp`, plus the listing metadata (see the
   App Store checklist at the bottom).
5. **An App Store Connect API key** (App Store Connect -> Users and Access ->
   Integrations -> App Store Connect API). Download the **`.p8`** (shown once) and
   note the **Key ID** and **Issuer ID**. Give the key the **App Manager** role so
   it can upload builds.

### Fill in `ios/ExportOptions.plist`

Two placeholders in that committed file must be replaced with your values, then
committed:

| Placeholder                        | Replace with                                             |
| ---------------------------------- | -------------------------------------------------------- |
| `REPLACE_TEAM_ID`                  | your 10-char Team ID                                     |
| `REPLACE_PROVISIONING_PROFILE_NAME`| the App Store profile's **name** (not its file name)     |

---

## Add the repository secrets

Each `gh secret set` without a value prompts you to paste it, so nothing lands in
shell history. Base64-encode the two binary files first:

```bash
base64 -i dist-cert.p12          -o cert.b64
base64 -i profile.mobileprovision -o profile.b64
base64 -i AuthKey_XXXXXXXXXX.p8   -o asckey.b64

gh secret set IOS_DIST_CERT_BASE64            --repo Sarv/Authenticator < cert.b64
gh secret set IOS_DIST_CERT_PASSWORD          --repo Sarv/Authenticator   # .p12 export password
gh secret set IOS_PROVISIONING_PROFILE_BASE64 --repo Sarv/Authenticator < profile.b64
gh secret set IOS_KEYCHAIN_PASSWORD           --repo Sarv/Authenticator   # any random string
gh secret set APP_STORE_CONNECT_API_KEY_BASE64 --repo Sarv/Authenticator < asckey.b64
gh secret set APP_STORE_CONNECT_KEY_ID        --repo Sarv/Authenticator   # the API Key ID
gh secret set APP_STORE_CONNECT_ISSUER_ID     --repo Sarv/Authenticator   # the API Issuer ID

rm cert.b64 profile.b64 asckey.b64
```

| Secret                             | Value                                                        |
| ---------------------------------- | ------------------------------------------------------------ |
| `IOS_DIST_CERT_BASE64`             | base64 of the Apple Distribution `.p12`                      |
| `IOS_DIST_CERT_PASSWORD`           | the password set when exporting the `.p12`                   |
| `IOS_PROVISIONING_PROFILE_BASE64`  | base64 of the App Store `.mobileprovision`                   |
| `IOS_KEYCHAIN_PASSWORD`            | any random string — unlocks the throwaway CI keychain        |
| `APP_STORE_CONNECT_API_KEY_BASE64` | base64 of the `.p8` API key                                  |
| `APP_STORE_CONNECT_KEY_ID`         | the API **Key ID**                                           |
| `APP_STORE_CONNECT_ISSUER_ID`      | the API **Issuer ID**                                        |

The workflow imports the cert into a throwaway keychain, installs the profile,
builds, uploads via the API key, and scrubs all of it afterwards.

> **Protect the signing material like the Android key.** The `.p12` is the app's
> App Store identity — keep it and its password in your password manager. A lost
> certificate can be re-created, but keep backups to avoid churn.

---

## App Store listing checklist (one-time, in App Store Connect)

Review is stricter for a 2FA app. Have these ready so the first submission isn't
bounced:

- **Privacy policy URL** — publish [`docs/PRIVACY.md`](docs/PRIVACY.md) at a
  stable URL (e.g. GitHub Pages) and paste it into the App Privacy section.
- **App Privacy "nutrition label"** — answer **"Data Not Collected"** across the
  board; it matches the privacy policy (nothing leaves the device).
- **Export compliance** — already handled: `ITSAppUsesNonExemptEncryption` is set
  to `false` in `ios/Runner/Info.plist`, so no per-upload prompt and no annual
  self-classification report.
- **Screenshots** — iOS-sized (6.7" and 5.5" at minimum). The Android captures in
  `docs/screenshots/` show the same UI if you need a reference for composition.
- **App Review notes** — paste [`docs/APP_REVIEW_NOTES.md`](docs/APP_REVIEW_NOTES.md)
  into the "Notes" field so the reviewer can get past the empty state (a 2FA app
  with no visible account enrollment is the usual rejection cause).

---

## Building a signed release locally (optional)

With Xcode, the certificate in your login keychain and the profile installed:

```bash
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
# upload the result in build/ios/ipa/ via Xcode's Organizer or Transporter
```

Contributors without the signing material can still run and test on the
Simulator (`flutter run`) — signing is only needed to upload to App Store Connect.
