# Security Policy

Sleep Guard is a local macOS utility that reads power-management data and can quit or restore user-approved apps. Security and data-loss reports are treated as high priority.

## Supported Versions

The current `main` branch and the latest tagged release are supported.

## Reporting A Vulnerability

Please report security-sensitive issues privately through GitHub Security Advisories when the repository is public. If advisories are unavailable, contact the primary maintainer through the GitHub profile linked to this repository.

Please include:

- affected version or commit,
- macOS version,
- reproduction steps,
- expected and actual behavior,
- whether app termination, restore, log parsing, or stored report data is involved.

## Scope

High-priority issues include:

- unsafe force termination or broadened termination policy,
- restoring untrusted paths, URL schemes, or non-`.app` bundles,
- persistence of full or unrelated `pmset` logs,
- leaking local app lists, report data, or logs over the network,
- command execution behavior that bypasses the PMSet command runner safety model.

## Disclosure

Please do not publicly disclose a vulnerability until a fix or mitigation is available.
