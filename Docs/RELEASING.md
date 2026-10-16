# Release DevPet

## Local build

Run `swift test`, `Scripts/build.sh`, `Scripts/dmg.sh`, then `Scripts/validate.sh`. Outputs: universal `dist/DevPet.app`, compressed `dist/DevPet.dmg`. The local app is ad-hoc signed to provide code integrity; that signature does not establish a Developer ID or Apple notarization.

The DMG includes DevPet.app, an Applications shortcut, concise installation instructions and original dark-background artwork. If `Scripts/DMG.DS_Store` exists, it preserves the reviewed Finder layout. Never claim notarization solely because hdiutil or codesign verification succeeds.

For a local GUI session, `DMG_LAYOUT=1 Scripts/dmg.sh` asks Finder to set the background and icon layout before converting the mounted image to its final read-only DMG. This requires macOS Automation permission for Finder. CI uses the committed layout without GUI automation.

## Developer ID signing

Join the Apple Developer Program, create a **Developer ID Application** certificate, and install it with its private key in your signing Keychain. Set `DEVELOPER_ID_APPLICATION` to the exact identity from `security find-identity -v -p codesigning`. Run `Scripts/sign.sh` before creating the DMG. The script uses hardened runtime and Apple's timestamp server. No sandbox entitlement is enabled because the app invokes the installed Codex CLI and reads the user-approved Claude bridge file.

Create a notarytool profile interactively:

```sh
xcrun notarytool store-credentials devpet-notary
# Enter your Apple ID, team ID and app-specific password at the prompts.
export NOTARY_PROFILE=devpet-notary
Scripts/notarize.sh
REQUIRE_NOTARIZATION=1 Scripts/validate.sh
```

Submit the DMG, wait for acceptance, staple it, then validate. A stapled DMG supplies the ticket for installation. The script never falls back to calling an unsigned artifact notarized or disables Gatekeeper. If you need the app itself stapled independently (for a zip distribution), submit an app zip first and run `xcrun stapler staple dist/DevPet.app` before packaging.

## GitHub

The public repository is https://github.com/emreeylm/devpet-macos. Local distribution files belong in GitHub Releases, not Git history.

Configure Actions secrets:

| Secret | Purpose |
|---|---|
| `APPLE_CERTIFICATE_P12_BASE64` | Base64 export of Developer ID certificate/private key |
| `APPLE_CERTIFICATE_PASSWORD` | Password for that P12 |
| `BUILD_KEYCHAIN_PASSWORD` | Temporary CI keychain password |
| `DEVELOPER_ID_APPLICATION` | Exact signing identity |
| `APPLE_ID` | Notarization Apple ID |
| `APPLE_TEAM_ID` | Developer team ID |
| `APPLE_APP_SPECIFIC_PASSWORD` | Notarization app-specific password |

GitHub's automatically supplied `github.token` creates draft releases; no separate PAT is needed. Update the bundle version in the generator before creating a version tag. Inspect the draft, indicate whether it is notarized, attach appropriate screenshots, and publish after review. The signed app zip needs its own app stapling step as noted above if you distribute it separately from the notarized DMG.

## Release checks

- Tests and universal build pass.
- Menu bar survives hidden/click-through pet; recover positions works.
- Demo cannot masquerade as live data; reset celebrations are authoritative.
- Every character is present, no emoji substitute or unlicensed copied artwork.
- Claude bridge preserves existing settings and saves no sensitive session fields.
- Correct version, real signing identity and notarization acceptance/ticket validation when claimed.
- Inspect final DMG mounted read-only and verify Applications points to `/Applications`.
