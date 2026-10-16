# Architecture

DevPet is a native macOS 14+ SwiftUI/AppKit application with a Foundation/CoreGraphics domain layer. No third-party runtime packages are required.

## Application and windows

`AppModel` owns preferences, snapshots, refresh scheduling, optional notifications and display state. `WindowCoordinator` owns nonactivating floating panels and a standard settings window. Window placement is restored against currently available screen bounds. Always-on-top windows use public AppKit collection behaviors; full-screen eligibility remains controlled by macOS.

Three persisted modes share the same data model:

- **Minimal:** the small panel renders quota cards only, uses statistics visibility and ignores pet click-through. Its width is 120 points at 100%; height is 91.2 for both providers or 48 for one.
- **Pet Only:** the small panel renders a companion, fixed mug and quota cards. A cropped logical viewport removes unused canvas margins without shrinking content.
- **Expanded:** a resizable statistics panel with independent provider disclosures. The pet can be attached or independent.

A native drag surface handles movement, reset tooltips and widget context menus. Preferences preserve animal, theme, opacity and placement across mode changes. All sizes share a 50–250% scale.

## Quota domain

`DevPet/Core` defines providers, windows, snapshots, validation, reset detection and Codable preferences. Missing, invalid, expired or stale windows do not become zero-percent quotas. Reset detection requires an elapsed previous cycle and authoritative new-cycle information.

Only the lowest fresh five-hour remaining quota among enabled providers controls activity: above 50% happy typing, 15–50% tired typing, below 15% sleep. Weekly display choices do not change this rule. `CompanionRoutine` supplies deterministic keyboard-paw timing; the body, laptop and mug stay fixed.

## Provider adapters

- **Claude Code:** the command-line statusline bridge whitelists percentage/reset fields, adds the original observation timestamp and writes a private local JSON file atomically. Re-reading the file never refreshes its observation time. No Claude configuration is changed.
- **Codex:** a bounded subprocess exchanges JSON-lines initialization and `account/rateLimits/read` requests with the installed CLI. The CLI owns authentication. Protocol errors, malformed payloads, timeouts and EOF become sanitized unavailable states.

See [INTEGRATIONS.md](INTEGRATIONS.md) for setup and upstream protocol references. Demo mode supplies explicitly labeled synthetic snapshots and does not issue quota notifications.

## Rendering and assets

`Companions-v6.png` and its crop metadata contain twelve right-facing characters with three states each. All three states register to one common per-animal pixel canvas, aligned at the laptop's right edge and ground. Sleeping art retains its natural proportions. Cup grids are separate native Canvas artwork matching each animal.

Text is rendered at its final point size; sprite images use nearest-neighbor interpolation and display-pixel alignment. Backing-density changes refresh the SwiftUI rendering environment. Quota dimensions are shared across animals and independent of sprite aspect ratio. Reduce Motion and the animation preference pause work animation.

## Validation

`swift test` covers the Core package. `Scripts/provider-tests.py` exercises actual subprocess behavior against fake executables; `Scripts/bridge-tests.py` checks statusline sanitization and permissions. `--smoke-test` uses an isolated demo preference suite to exercise native window behavior without credentials. `--render-gallery` generates demo screenshots for visual review.

Physical monitor hot-plug, every full-screen/Stage Manager configuration, Intel runtime and OS-controlled notification/login-item flows require additional hardware testing. The source target is macOS 14; CI uses macOS 26.
