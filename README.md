[![PSGallery Version](https://img.shields.io/powershellgallery/v/CSVToRainbow)](https://www.powershellgallery.com/packages/CSVToRainbow)
[![PSGallery Downloads](https://img.shields.io/powershellgallery/dt/CSVToRainbow)](https://www.powershellgallery.com/packages/CSVToRainbow)
# CSVToRainbow

Send CSV files as beautiful, rainbow-colored HTML tables directly in email — no Excel required.

Each column gets a distinct color, rows alternate for readability, empty cells are highlighted, and a plain-text fallback is included for non-HTML clients. Powered by [MailKit](https://github.com/jstedfast/MailKit) instead of the deprecated `Send-MailMessage`. Works on Windows, macOS, and Linux.

---

## Features

- **Rainbow column coloring** — each column header gets a distinct hue, carried through as a colored left border on every cell
- **Zebra row striping** — alternating row backgrounds for wide or tall tables
- **Sticky header** — column headers stay visible while scrolling
- **Empty cell highlighting** — blank cells render as a grey `—` so gaps are obvious at a glance
- **Per-table summary** — row and column count shown above each table
- **Local timestamp** — email subject and header show the sender's local time with timezone; falls back to UTC automatically
- **Plain-text fallback** — multipart email so non-HTML clients get something readable
- **Pipeline-aware** — accepts `Get-ChildItem` output directly
- **Optional config file** — save your `From` address and SMTP server once; never pass them again
- **Interactive setup** — if config is missing or invalid, prompts you for values and offers to save them
- **MailKit-powered** — bootstraps MailKit/MimeKit from NuGet on first use; no dependency on the deprecated `Send-MailMessage`
- **Cross-platform** — Windows (PS 5.1+), macOS, and Linux (PS 7.0+)

---

## Installation

### From PowerShell Gallery

```powershell
Install-Module -Name CSVToRainbow -Scope CurrentUser
```

### Manual

Clone or download the repo and copy the `CSVToRainbow` folder to your PowerShell modules directory:

| OS | Path |
|---|---|
| Windows | `$HOME\Documents\PowerShell\Modules\CSVToRainbow\` |
| macOS / Linux | `$HOME/.local/share/powershell/Modules/CSVToRainbow/` |

---

## Quick Start

Save your sender address and SMTP server once:

```powershell
Set-RainbowCsvConfig -From "noreply@company.com" -SmtpServer "mail.company.com"
```

Then send a CSV — no need to pass `-From` or `-SmtpServer` again:

```powershell
CSVToRainbow -ReportPath "C:\Logs\export.csv" -EmailTo "ops@company.com"
```

If you skip the setup step, CSVToRainbow will prompt you on first run and offer to save your settings.

---

## Configuration

CSVToRainbow stores its config file (`env.json`) in the same folder as the module itself. This means the same path works on all platforms with no extra setup.

**Option 1 — use the command (recommended):**

```powershell
Set-RainbowCsvConfig -From "noreply@company.com" -SmtpServer "mail.company.com"

# Optional: non-default port
Set-RainbowCsvConfig -From "noreply@company.com" -SmtpServer "mail.company.com" -SmtpPort 587
```

**Option 2 — copy `example.json` from the repo:**

Copy `example.json` to the module folder and rename it `env.json`, then fill in your values:

```json
{
    "From":       "noreply@company.com",
    "SmtpServer": "mail.company.com",
    "SmtpPort":   25
}
```

Config values are used as fallbacks. Anything passed directly to `CSVToRainbow` always wins. If a required value is missing or invalid, you will be prompted and offered the option to save your answer for next time.

---

## Usage

### Minimal — From and SmtpServer come from config

```powershell
CSVToRainbow -ReportPath "C:\Logs\export.csv" -EmailTo "ops@company.com"
```

### Explicit — no config file needed

```powershell
CSVToRainbow -ReportPath "C:\Logs\export.csv" `
             -EmailTo "ops@company.com" `
             -From "noreply@company.com" `
             -SmtpServer "mail.company.com"
```

### Multiple files

```powershell
CSVToRainbow -ReportPath "C:\Logs\users.csv","C:\Logs\groups.csv" `
             -Title "Weekly Audit" `
             -EmailTo "ops@company.com"
```

### Pipeline from Get-ChildItem

```powershell
Get-ChildItem C:\Logs\*.csv | CSVToRainbow -EmailTo "ops@company.com"
```

### Inline only — no attachments

```powershell
Get-ChildItem C:\Logs\*.csv | CSVToRainbow -EmailTo "ops@company.com" -NoAttach
```

---

## Commands

### `CSVToRainbow`

| Parameter | Type | Required | Default | Description |
|---|---|---|---|---|
| `ReportPath` | `string[]` | No | — | CSV file path(s). Pipeline-aware (`FullName`, `Path` aliases). |
| `Title` | `string` | No | Auto-generated | Subject line and email heading. Timestamped filename used if omitted. |
| `EmailTo` | `string[]` | **Yes** | — | One or more recipient addresses. |
| `From` | `string` | No* | — | Sender address. Prompted if not in config. |
| `SmtpServer` | `string` | No* | — | SMTP server hostname. Prompted if not in config. |
| `SmtpPort` | `int` | No | `25` | SMTP port. Config value used if not passed. |
| `NoAttach` | `switch` | No | — | Send inline HTML only; do not attach CSV files. Alias: `-noa` |
| `Credential` | `PSCredential` | No | — | SMTP authentication credentials. |

*Not required if saved via `Set-RainbowCsvConfig` or entered at the prompt.

### `Set-RainbowCsvConfig`

| Parameter | Type | Required | Default | Description |
|---|---|---|---|---|
| `From` | `string` | **Yes** | — | Default sender address to save. |
| `SmtpServer` | `string` | **Yes** | — | Default SMTP server hostname to save. |
| `SmtpPort` | `int` | No | `25` | Default SMTP port to save. |

---

## Requirements

| OS | PowerShell Version |
|---|---|
| Windows | 5.1 or later |
| macOS | 7.0 or later |
| Linux | 7.0 or later |

Internet access is required on first use to bootstrap MailKit/MimeKit from NuGet. After that, the DLLs are cached in the module folder and no internet access is needed.

---
## License

MIT License — see [LICENSE](LICENSE) for details.
