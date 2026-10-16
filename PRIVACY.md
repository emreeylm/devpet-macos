# DevPet privacy

DevPet collects no analytics and includes no tracking SDKs. It does not read your code, prompts, conversations, Claude transcripts or Codex token files. It sends no data to a DevPet-owned server.

Preferences, window coordinates and notification deduplication identifiers are stored locally in the `app.devpet.mac` UserDefaults domain. Demo/verification runs use a separate preference suite. Quota snapshots are held in memory, except the sanitized Claude bridge file at `~/Library/Application Support/DevPet/claude-usage.json`. The bridge stores only quota window names, percentages, authoritative reset timestamps and its observation time, with owner-only file permissions. The input payload is discarded; no credential or transcript fields are saved.

Codex integration starts the installed CLI, which uses its existing authentication and makes requests to OpenAI according to Codex's own privacy policy. DevPet disables app-server analytics for this invocation and does not log unfiltered CLI output, tokens or account identifiers. Claude Code supplies statusline data locally and is responsible for its own networking/authentication. DevPet does not own credentials, so no separate Keychain secret is stored by this application.

Local native notifications can show service names, quota percentages and reset events. They are optional and disabled by default. Their visibility is controlled by macOS notification settings. Launch at login is optional and uses Apple's ServiceManagement API.

To remove local data, quit DevPet, remove its Claude statusline command from your configuration manually, delete its Application Support folder and remove its preference domain using the macOS `defaults` utility if desired. Deleting DevPet does not sign you out of Claude or Codex or alter either provider's settings.
