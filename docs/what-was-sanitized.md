# What Was Sanitized

This repository is a public demo derived from a real embedded Linux workflow. It intentionally removes product-specific behavior while keeping the engineering shape useful for review.

## Removed

- company names and product branding,
- private domains and customer API URLs,
- credentials, tokens, VPN paths and production certificates,
- product-specific hardware maps,
- customer-specific deployment scripts,
- production database schema,
- private infrastructure paths,
- product logic that would reveal the original product domain.

## Kept

- custom Yocto layer structure,
- Raspberry Pi 4 target,
- custom image recipe,
- systemd integration,
- RAUC update flow,
- SDK generation,
- release packaging,
- shell automation,
- security hardening examples,
- a neutral telemetry service fetched from a separate public repository as an application payload.

## Why this matters

The goal is to show practical embedded Linux and Yocto experience without exposing confidential implementation details.

The public version should answer these questions:

- Can the project define and build a custom image?
- Can it package an application into that image?
- Can it produce OTA and SDK artifacts?
- Does it show realistic service, security and release concerns?
- Is the workflow understandable to another engineer?

It should not expose real customers, infrastructure, credentials or proprietary product behavior.
