# Getting SshMagic onto your phone

The `CI/CD` GitHub Actions workflow (`.github/workflows/ci-cd.yml`) builds the
app on every pull request and every push to `main`:

| Job | Runs on | Output |
|---|---|---|
| Analyze & test | Ubuntu | `flutter analyze` + `flutter test` |
| Android | Ubuntu | `SshMagic-N.apk` and `SshMagic-N.aab` (artifact `android-release`); APK attached to a GitHub Release when you push a `v*` tag |
| iOS | macOS 15 | **With secrets, on push to `main` / manual run:** signed IPA uploaded to TestFlight (artifact `ios-appstore`). **Otherwise:** unsigned IPA (artifact `ios-unsigned`) |

Download artifacts from the run page: *Actions → CI/CD → (run) → Artifacts*.

---

## iPhone: your three options

Apple only runs apps signed by Apple-issued certificates, so every route needs
an Apple ID. Pick based on cost and how often you want to re-install.

| Option | Cost | Re-install needed | Best for |
|---|---|---|---|
| **A. TestFlight** (recommended) | Apple Developer Program, $99/year | Each build lasts 90 days; updates arrive automatically via the TestFlight app | Using it daily, sharing with up to 10,000 testers |
| **B. Ad-hoc / development install** | $99/year | Profile lasts 1 year | Installing a specific IPA without TestFlight (up to 100 registered devices) |
| **C. Free sideload** (AltStore / Sideloadly) | Free Apple ID | **Every 7 days**, max 3 apps | Trying it out before paying |

### A. TestFlight (fully automated by CI)

One-time setup (about 30 minutes, needs a browser; a Mac is **not** required):

1. **Enrol** in the [Apple Developer Program](https://developer.apple.com/programs/enroll/) ($99/year). Note your **Team ID** (Membership details page, 10 characters).
2. **Register the bundle id**: [Identifiers](https://developer.apple.com/account/resources/identifiers/list) → `+` → App IDs → App → Bundle ID (explicit) `com.shristov92.sshmagic`.
3. **Create the app** in [App Store Connect](https://appstoreconnect.apple.com/apps) → `+` → New App → iOS, name *SshMagic*, bundle id from step 2, any SKU.
4. **App Store Connect API key**: Users and Access → Integrations → App Store Connect API → Team Keys → `+`, role **App Manager**. Download the `.p8` (only downloadable once) and note the **Key ID** and **Issuer ID**.
5. **Apple Distribution certificate** (`.p12`):
   - *With a Mac:* Xcode → Settings → Accounts → Manage Certificates → `+` → Apple Distribution. Then Keychain Access → My Certificates → right-click it → Export → `.p12` with a password.
   - *Without a Mac:*
     ```bash
     openssl req -new -newkey rsa:2048 -nodes -keyout dist.key -out dist.csr -subj "/CN=SshMagic Distribution"
     # Upload dist.csr at developer.apple.com → Certificates → + → Apple Distribution, download distribution.cer
     openssl x509 -inform der -in distribution.cer -out distribution.pem
     openssl pkcs12 -export -legacy -inkey dist.key -in distribution.pem -out dist.p12   # choose a password
     ```
6. **Add GitHub secrets**: repo → Settings → Secrets and variables → Actions → New repository secret:

   | Secret | Value |
   |---|---|
   | `APPLE_TEAM_ID` | Team ID from step 1 |
   | `ASC_KEY_ID` | Key ID from step 4 |
   | `ASC_ISSUER_ID` | Issuer ID from step 4 |
   | `ASC_KEY_P8_BASE64` | `base64 -i AuthKey_XXXX.p8 \| tr -d '\n'` |
   | `IOS_DIST_CERT_P12_BASE64` | `base64 -i dist.p12 \| tr -d '\n'` |
   | `IOS_DIST_CERT_PASSWORD` | the `.p12` export password |

   The provisioning profile is created/downloaded automatically by fastlane through the API key, so it is not a secret.

7. Push to `main` (or *Actions → CI/CD → Run workflow*). The `ios` job runs `bundle exec fastlane ios beta` (see `fastlane/Fastfile`), which signs, builds, and uploads.
8. In App Store Connect → your app → **TestFlight**: wait for processing (5 to 30 minutes), answer the **export compliance** question (SshMagic uses encryption because SSH is encrypted; standard algorithms usually qualify for the exemption, but that is your call), then add yourself under *Internal Testing*.
9. On the iPhone install **TestFlight** from the App Store, accept the invite, tap *Install*. New builds from CI show up there automatically.

### B. Ad-hoc install

Same developer account. Register the iPhone's UDID under *Devices*, create an *Ad Hoc* provisioning profile, and build with `method: ad-hoc` in the export options. Install the IPA with Apple Configurator (Mac), Finder drag-and-drop, or a service like Diawi. TestFlight is less work, so this is not wired into CI.

### C. Free sideload (no paid account)

1. Download the `ios-unsigned` artifact from any CI run and unzip it to get `SshMagic-N-unsigned.ipa`.
2. Install [Sideloadly](https://sideloadly.io/) (Windows/macOS) or [AltStore](https://altstore.io/) on a computer.
3. Connect the iPhone by USB, drop the IPA in, sign in with your Apple ID. The tool re-signs the app with a free 7-day certificate.
4. On the phone: Settings → General → VPN & Device Management → trust your Apple ID. On iOS 16+ also enable Settings → Privacy & Security → **Developer Mode**.
5. Repeat (or let AltStore auto-refresh over Wi-Fi) every 7 days.

---

## Android

* **No setup needed** to try it: download the `android-release` artifact, copy the `.apk` to the phone and open it (allow "install unknown apps"). Without signing secrets it is signed with a debug key.
* **Play Store / stable signing**: create an upload key once and add four secrets:
  ```bash
  keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
  base64 -i upload-keystore.jks | tr -d '\n'   # → ANDROID_KEYSTORE_BASE64
  ```
  | Secret | Value |
  |---|---|
  | `ANDROID_KEYSTORE_BASE64` | base64 of the `.jks` |
  | `ANDROID_KEYSTORE_PASSWORD` | keystore password |
  | `ANDROID_KEY_ALIAS` | `upload` |
  | `ANDROID_KEY_PASSWORD` | key password |

  Then upload the `.aab` to a Google Play Console internal testing track ($25 one-time). Automated Play upload (fastlane `supply`) can be added later.

## Releases

Tag a version to publish the APK on GitHub Releases:

```bash
git tag v0.1.0 && git push origin v0.1.0
```

Bump `version:` in `pubspec.yaml` for user-visible version changes; the build number comes from CI automatically.
