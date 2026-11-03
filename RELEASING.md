# Releasing

Cutting a release is one action: **push a version tag.** GitHub Actions
(`.github/workflows/release-android.yml`) then builds a **signed release APK** and
attaches it to a GitHub Release.

```bash
git tag v0.1.2
git push origin v0.1.2
```

The tag drives the version — `v0.1.2` produces an APK with versionName `0.1.2`
(no need to edit `pubspec.yaml` each time). The build number is the workflow run
number, so every release is distinct.

### Shipping a new build of the current version

To ship fixes without a new version, keep the version fixed and only increment
the build number — the same rule as iOS (see
[RELEASING-iOS.md](RELEASING-iOS.md)). Run it from **Actions -> Release Android
-> Run workflow**, or:

```bash
gh workflow run release-android.yml -f version=0.1.3
```

Leave the build number blank and the workflow uses its run number, which only
ever increases. A manual run uploads to the Play internal track (when
configured) and keeps the APK as a downloadable artifact on the run; it does not
create or touch a GitHub Release.

The published APK installs by sideloading: the installer shows the one-time
**"allow installing unknown apps"** prompt the first time. That prompt is a
property of installing outside the Play Store and signing cannot remove it — it
is not a certificate warning and does not reappear for later updates. (A true
zero-prompt install needs a Play Store testing track.)

---

## One-time setup: the signing key

The release workflow needs an upload key. **You generate and own it** — the
passwords never go through anyone else. The signing key is the app's permanent
identity: **back it up somewhere safe. If it is lost, you can never ship an
update** to an installed app (Android rejects a different signature).

### 1. Generate the keystore

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Choose a store password and a key password when prompted (they may be the same).
Keep `upload-keystore.jks` and both passwords in your password manager.

### 2. Add the four repository secrets

Base64-encode the keystore, then set the secrets (each command prompts you to
paste the value, so nothing lands in shell history):

```bash
base64 -i upload-keystore.jks -o keystore.b64

gh secret set ANDROID_KEYSTORE_BASE64   --repo Sarv/Authenticator < keystore.b64
gh secret set ANDROID_KEYSTORE_PASSWORD --repo Sarv/Authenticator   # store password
gh secret set ANDROID_KEY_PASSWORD      --repo Sarv/Authenticator   # key password
gh secret set ANDROID_KEY_ALIAS         --repo Sarv/Authenticator   # upload

rm keystore.b64
```

| Secret                      | Value                                   |
| --------------------------- | --------------------------------------- |
| `ANDROID_KEYSTORE_BASE64`   | base64 of `upload-keystore.jks`         |
| `ANDROID_KEYSTORE_PASSWORD` | the store password                      |
| `ANDROID_KEY_PASSWORD`      | the key password                        |
| `ANDROID_KEY_ALIAS`         | the key alias (`upload` above)          |

That is all the pipeline needs. The workflow decodes the keystore, writes a
temporary `android/key.properties`, builds, and scrubs both afterwards.

---

## Building a signed release locally (optional)

Put the key where Gradle expects it (both paths are git-ignored):

```bash
cp upload-keystore.jks android/app/upload-keystore.jks
cat > android/key.properties <<'EOF'
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
EOF

flutter build apk --release
```

Without `android/key.properties`, release builds fall back to debug signing so
`flutter run --release` keeps working for contributors who don't hold the key.
