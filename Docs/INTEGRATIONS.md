# DevPet connection guide

DevPet never changes Claude or Codex configuration and never asks for passwords or tokens. Missing or stale quotas are shown as unavailable. Demo is explicitly labeled and never sends notifications.

## Claude Code: official local statusline bridge

Verified against Claude Code 2.1.296 and the [official statusline documentation](https://code.claude.com/docs/en/statusline) on 2026-10-14. Claude supplies `rate_limits.five_hour` and `rate_limits.seven_day`, with `used_percentage` and `resets_at` in epoch seconds. These fields are optional and may appear only after a Claude.ai subscription session receives an API response. Expired windows can disappear until another response arrives.

1. Move DevPet.app to Applications so the command remains at a stable location.
2. Open DevPet Settings → Providers and copy the displayed configuration.
3. **Manually merge** its `statusLine` entry into `~/.claude/settings.json`. Back up your file first. Do not replace other settings. Example:

```json
{
  "statusLine": {
    "type": "command",
    "command": "'/Applications/DevPet.app/Contents/MacOS/DevPet' --claude-statusline"
  }
}
```

4. Use Claude Code normally. After a new response, DevPet receives quota data on its next refresh.

If you already have a statusline, use a wrapper instead of replacing it:

```sh
#!/bin/sh
# The payload exists only temporarily in this process, never in a file.
input=$(cat)
printf '%s' "$input" | '/Applications/DevPet.app/Contents/MacOS/DevPet' --claude-statusline >/dev/null
printf '%s' "$input" | "$HOME/.claude/your-existing-statusline.sh"
```

Point `statusLine.command` to your wrapper. The DevPet process whitelists only quota percentages, reset timestamps, and its observation time. It atomically writes a mode-0600 file in `~/Library/Application Support/DevPet/claude-usage.json`. No token, transcript, path, prompt, or code fields are retained. No OAuth usage endpoint or Keychain extraction is used.

The bridge is event-driven, not an independent network poll. Even when DevPet reads the file again, it preserves the original observation timestamp. After 15 minutes (or twice the configured refresh interval, whichever is larger), unused data becomes stale. It cannot refresh Claude data while Claude is idle. Do not configure a repeating statusline timer to make old API observations appear fresh.

## Codex: supported local app-server protocol

Verified against Codex CLI 0.159.3, its generated JSON schema, and the [official app-server documentation](https://learn.chatgpt.com/docs/app-server) on 2026-10-14.

Install the Codex CLI and sign in with `codex login` using your ChatGPT subscription. DevPet finds common Homebrew/local installation paths, or accepts an absolute executable path in Settings. It starts the installed binary with:

```sh
codex app-server --listen stdio:// -c analytics.enabled=false
```

It performs the `initialize` / `initialized` handshake, then requests `account/rateLimits/read`. No thread or model turn is created. Credentials stay with Codex; DevPet does not copy, parse, or log them. The CLI may maintain its own ordinary local caches/logs and contacts OpenAI to obtain the quota snapshot.

DevPet selects the `codex` bucket from `rateLimitsByLimitId`, falling back to the legacy `rateLimits` object only when the map is absent or empty. It classifies windows by `windowDurationMins` (300 and 10080), **not** by primary/secondary ordering. Missing windows, unknown durations, and unrelated buckets do not become invented quotas. API-key login may not expose ChatGPT subscription limits.

The app-server command is marked experimental by the installed CLI; although the quota method is documented, the transport/schema can change. The adapter is isolated in `DevPet/Providers/UsageProviders.swift`, has a 20-second timeout and bounded output, ignores unrelated notifications, and safely reports failures. It does not use undocumented HTTP endpoints.

## Data behavior

- Each provider refreshes independently; one failure does not erase the other provider.
- Default refresh is 5 minutes, configurable 1–30 minutes, with bounded exponential backoff after failures and suspension during sleep.
- Manual refresh bypasses backoff.
- Mood uses the lowest valid percentage among selected services/windows. Available partial data still drives mood; unavailable windows visibly show `—`.
- A reset celebration requires a new authoritative cycle timestamp after the previous timestamp elapsed and a higher remaining quota. A mere increase or countdown reaching zero never confirms reset. Deliberate early quota resets cannot be confirmed by this conservative detector.
- `normal` >40%, `alert` 15–40%, `tired` >0–<15%, `sleeping` 0%; no valid data means unknown.

## Türkçe bağlantı özeti

Claude Code ayarları uygulama tarafından değiştirilmez. DevPet Ayarlar → Sağlayıcılar bölümündeki `statusLine` yapılandırmasını `~/.claude/settings.json` dosyasına elle birleştirin. Mevcut statusline komutunuz varsa yukarıdaki sarmalayıcıyı kullanın. Claude’un bir sonraki API yanıtından sonra yalnızca kota alanları yerel dosyaya yazılır; oturum boşta olduğunda veri yenilenmez.

Codex için CLI kurulu ve `codex login` ile ChatGPT oturumu açık olmalıdır. Yol otomatik bulunamazsa Sağlayıcılar bölümünde çalıştırılabilir dosyanın tam yolunu girin. Eksik, eski veya ulaşılamayan veriler uydurulmaz; panelde veri yok olarak gösterilir.
