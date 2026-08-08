# Release playbook

How a WisperVoice release is planned, cut, and shipped. The pipeline is
tag-driven: **pushing a `vX.Y.Z` tag is the release button.**

## Versioning

- SemVer: `MAJOR.MINOR.PATCH` (`v0.2.0`, `v0.2.1`, …).
- Pre-releases: `v0.3.0-beta.1` — anything containing `-beta`/`-alpha`/`-rc`
  is automatically marked "pre-release" on GitHub.
- The tag is the single source of truth: CI stamps `CFBundleShortVersionString`
  from the tag and `CFBundleVersion` from the run number. Do not hand-edit
  versions in `Info.plist`.

## Cutting a release

1. **Update `CHANGELOG.md`** — add a `## [X.Y.Z] — date` section at the top.
   This is the "changeset" for the release; write it for users, not for git.
2. Make sure `main` is green (CI runs on every push).
3. Tag and push:
   ```bash
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```
4. `.github/workflows/release.yml` then, automatically:
   - builds the Release configuration,
   - signs it (Developer ID if secrets are configured, **ad-hoc otherwise** —
     required for the binary to run at all on Apple Silicon),
   - zips (+ best-effort DMG) with SHA-256 checksums,
   - generates notes (commit list since the previous tag + install steps),
   - publishes the GitHub Release with the artifacts attached.
5. Sanity-check the release page and download link on the website
   (the site's "Download for Mac" buttons point at `/releases`).

## Re-cutting a bad release

```bash
gh release delete vX.Y.Z --yes
git push --delete origin vX.Y.Z
git tag -d vX.Y.Z
# fix, then tag again
```

## Signing & notarization (upgrade path)

Today's builds are ad-hoc signed: users must clear quarantine once
(`xattr -d com.apple.quarantine`). To ship notarized builds, add these repo
secrets and the workflow's existing signing/notarization steps activate
automatically:

| Secret | What it is |
|---|---|
| `DEVELOPER_ID_CERTIFICATE_P12` | base64 of the Developer ID Application cert (.p12) |
| `P12_PASSWORD` | password for the .p12 |
| `KEYCHAIN_PASSWORD` | any string; protects the temp CI keychain |
| `APPLE_ID` / `APPLE_APP_SPECIFIC_PASSWORD` / `APPLE_TEAM_ID` | notarytool credentials |

Requires a paid Apple Developer membership. Until then, the quarantine
instruction ships in every release's notes.
