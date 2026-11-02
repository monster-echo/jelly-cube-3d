# Jelly Cube 3D — tagged release

This GitHub Release contains the signed release artifacts produced by the tag workflow:

- Android App Bundle (`.aab`)
- iOS App Store distribution IPA (`.ipa`)
- HarmonyOS HAP (`.hap`), when the Harmony runner and signing profile are available
- SHA-256 checksums for every artifact

## Important

- **No App Store, Google Play, or AppGallery submission is performed by this workflow.**
- Store submission remains a manual, human-approved step.
- HarmonyOS HAP signing requires the AppGallery signing profile configured on the
  self-hosted Harmony runner.
- Do not publish a tagged release if any platform job failed or if store
  console/product setup is incomplete.

See `RELEASE.md` for the submission runbook.
