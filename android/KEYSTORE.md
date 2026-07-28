# Android release signing

Google Play rejects debug-signed uploads. Release builds need an upload keystore, which is not in
this repository and never should be.

Until you create one, `flutter build apk --release` still works — it falls back to the debug key and
prints a warning at configuration time. That artifact runs locally and **cannot be uploaded**.

## Create the upload keystore

Run once, from anywhere. `keytool` ships with the JDK.

```bash
keytool -genkey -v \
  -keystore upload-keystore.jks \
  -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

It will ask for a keystore password, a key password, and identifying details. Use a password
manager — see "If you lose this" below.

**Store the `.jks` file outside the repository.** `*.jks` and `*.keystore` are gitignored, but the
safest arrangement is one where an accidental `git add -f` cannot reach it.

## Point the build at it

Create `android/key.properties` (gitignored):

```properties
storePassword=<keystore password>
keyPassword=<key password>
keyAlias=upload
storeFile=C:/Users/markl/keys/upload-keystore.jks
```

`storeFile` takes an absolute path with **forward slashes**, even on Windows. A relative path is
resolved against `android/app/`, which is rarely what you want.

Once the file exists, `hasReleaseKeystore` in `app/build.gradle` flips to true, the warning stops,
and release builds use the real key.

## Verify

```bash
flutter build appbundle --release
```

Confirm the signer is not the debug key:

```bash
# The debug key always reports CN=Android Debug. Anything else means real signing.
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

## If you lose this

The upload key is your app's identity on Google Play. Losing it without **Play App Signing** enabled
means you cannot publish another update to the same listing — ever. Users would have to install a
new app under a different package name.

Enable Play App Signing when you first upload. Google then holds the app signing key, your upload
key becomes recoverable through support, and losing it stops being terminal.

Back up the `.jks` and both passwords somewhere durable and separate from this machine.

## Note on minification

The release build sets `minifyEnabled true` and `shrinkResources true`. R8 rules for Firebase and
Flutter mostly ship with their AARs, and `proguard-rules.pro` covers the rest.

R8 problems appear at **runtime**, not build time — typically as a missing class in a reflective
path. If a release build installs but crashes where debug does not, suspect R8 first and check
`build/app/outputs/mapping/release/` for what was stripped.
