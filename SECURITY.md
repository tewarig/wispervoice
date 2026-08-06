# Security Policy

## Supported Versions

| Version | Supported |
| ------- | --------- |
| 1.x     | ✅ Yes     |
| < 1.0   | ❌ No      |

We support the latest tagged release on `main`. Please upgrade before reporting.

## Reporting a Vulnerability

**Do not open a public GitHub issue for security reports.**

Instead:

1. Email the maintainers privately. If no security email is configured, open a [private security advisory](../../security/advisories/new) via GitHub's **Security → Advisories** tab.
2. Include:
   - Affected version / commit
   - Steps to reproduce (proof-of-concept if possible)
   - Impact assessment (what an attacker could achieve)
   - Suggested mitigation if you have one
3. You will receive an acknowledgment within **48 hours** and a status update within **7 days**.

We ask that you:

- Give us reasonable time to investigate and patch before public disclosure (coordinated disclosure, typically 90 days).
- Do not access, modify, or exfiltrate data beyond what is necessary to demonstrate the issue.
- Do not perform DoS or social-engineering against other users.

## What to report

- Microphone / audio capture bypass or data exfiltration
- Accessibility / pasteboard injection that could be abused cross-app
- API key handling (OpenAI key stored in `UserDefaults` — know the trade-off; reports on key exfiltration vectors are welcome)
- Code-signing, notarization, or update-mechanism weaknesses
- Dependency or supply-chain issues (SPM, GitHub Actions)

Out of scope: UI spoofing that requires local code execution with the same privileges as the app.

## Handling

- We will confirm, fix, and publish a patched release with a CVE/advisory if applicable.
- Credit is given to reporters unless you prefer to remain anonymous.
- We publish advisories via GitHub Security Advisories and release notes.

## Hardening notes for contributors

- Never log or print `openAIKey` or audio buffers.
- Treat `AXIsProcessTrusted` as untrusted input — fail closed.
- Keep entitlements minimal (`audio-input` only); justify any new entitlement in the PR.
- Pin GitHub Actions to SHAs or tagged majors; enable Dependabot for Actions.
