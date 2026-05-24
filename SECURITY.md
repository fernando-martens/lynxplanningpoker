# Security Policy

## Reporting a vulnerability

If you believe you have found a security vulnerability in Lynx Planning Poker, please report it **privately** — do **not** open a public GitHub issue.

**Email:** [contact@lynxplanningpoker.com](mailto:contact@lynxplanningpoker.com)

Please include:

- A description of the issue and its impact.
- Steps to reproduce (a minimal proof of concept is ideal).
- The affected version, commit, or URL.
- Any logs, screenshots, or payloads that help reproduce the issue.
- Your name or handle if you would like to be credited in the fix.

If possible, give us a reasonable window to investigate and patch before any public disclosure.

## What to expect

- **Acknowledgement** of your report within **3 business days**.
- An initial assessment (severity, scope, reproducibility) within **7 business days**.
- Regular updates while a fix is being prepared.
- Credit in the release notes once the fix ships, unless you prefer to stay anonymous.

## Scope

In scope:

- The application code in this repository.
- The production deployment at <https://lynxplanningpoker.com>.

Out of scope:

- Findings from automated scanners without a working proof of concept.
- Denial-of-service via raw traffic volume.
- Social-engineering attacks against maintainers or users.
- Vulnerabilities in third-party dependencies that are already tracked upstream — please report those to the upstream project (we run `mix deps.audit` as part of `mix precommit`).
- Missing security headers or best-practice hardening with no demonstrable exploit.

## Supported versions

Only the `main` branch and the currently deployed production version receive security updates. There are no long-term-support branches.
