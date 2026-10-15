# BLABAN-SWEETS — TWA build preparation

This branch is an isolated preparation branch. It is not merged into `main`, and it does not deploy anything by itself.

## Intended Android identity
- Display name: `BLABAN-SWEETS | حلو ب لبن`
- Application ID: `com.blabansweets.app`
- TWA website origin: `https://blaban-sweets.pages.dev`
- Web manifest: `https://blaban-sweets.pages.dev/manifest.webmanifest`
- Customer launch path: `/`
- Admin path: `/admin.html` must remain a separate admin entry point, not an app shortcut.

## Before generating Android files
1. Open the production storefront and confirm checkout works with test data.
2. Confirm the live manifest loads at the URL above and its icons load successfully.
3. Confirm that `com.blabansweets.app` is the intended permanent application ID and is not already in use in the intended Play Console account.
4. Build on a trusted computer with Node.js/npm and Android build prerequisites installed. Do not put passwords, keystores, or private signing keys in this repository.

## TWA generation (run on a trusted computer)
Install the Bubblewrap CLI, then initialize from the **production** web manifest:

```sh
npm install --global @bubblewrap/cli
bubblewrap init --manifest=https://blaban-sweets.pages.dev/manifest.webmanifest
```

During initialization, verify the generated configuration uses:
- package ID: `com.blabansweets.app`
- start URL: `/`
- origin: `https://blaban-sweets.pages.dev`
- the intended app name and existing storefront icons

Do not accept a different package ID or website origin without reviewing the change. Follow the CLI prompts for Android SDK/build prerequisites. If asked to create a signing key, create it on the trusted computer and store it in a secure backup outside this repository. Never commit the keystore or its passwords.

After reviewing the generated Android project and confirming the signing-key backup, run:

```sh
bubblewrap build
```

Bubblewrap should report the output paths for the generated Android packages. Verify the AAB exists and record its SHA-256 locally. A successful command alone is not a substitute for installing and testing the signed package on a real Android device.

## Digital Asset Links
Do **not** create or publish `/.well-known/assetlinks.json` with guessed values. After the final package ID and signing certificate are known, extract the certificate's SHA-256 fingerprint using the appropriate Android signing/certificate tooling, then construct the Digital Asset Links JSON with:
- relation: `delegate_permission/common.handle_all_urls`
- namespace: `android_app`
- package_name: `com.blabansweets.app`
- sha256_cert_fingerprints: the exact fingerprint for the certificate that will sign the Play release

If Google Play App Signing is enabled, the fingerprint used for production verification may be the **Play app-signing certificate** fingerprint shown in Play Console, not merely the upload-key fingerprint. Verify this before publishing the file.

## Release gates
- Test checkout/order creation with test data, sign-in/admin separation, external links, back navigation, and loss/recovery of connectivity on a physical device.
- Confirm admin pages and authenticated/API responses are never cached as public content.
- Re-check Supabase RLS and order-creation RPC behavior with anonymous and non-admin sessions before release.
- Do not claim offline checkout works; the service worker only caches a limited storefront shell.
- Do not merge to `main`, change Supabase, or deploy production as part of this preparation without explicit owner approval.

## Current status
This document is a safe build procedure, **not** an Android project, signed APK/AAB, or proof of successful device testing. Those require the trusted build environment and the real signing certificate.
