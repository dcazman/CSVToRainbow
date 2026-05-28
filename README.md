# CSVToRainbow

Send CSV files as beautiful, rainbow-colored HTML tables directly in email — no Excel required.

Each column gets a distinct color, rows alternate for readability, empty cells are highlighted, and a plain-text fallback is included for non-HTML clients. Powered by [MailKit](https://github.com/jstedfast/MailKit) instead of the deprecated `Send-MailMessage`.

---

## Features

- **Rainbow column coloring** — each column header gets a distinct hue, carried through as a colored left border on every cell
- **Zebra row striping** — alternating row backgrounds for wide or tall tables
- **Sticky header** — column headers stay visible while scrolling
- **Empty cell highlighting** — blank cells render as a grey `—` so gaps are obvious at a glance
- **Per-table summary** — row and column count shown above each table
- **Plain-text fallback** — multipart email so non-HTML clients get something readable
- **Pipeline-aware** — accepts `Get-ChildItem` output directly
- **MailKit-powered** — auto-installs MailKit/MimeKit via NuGet if not already present; no dependency on the deprecated `Send-MailMessage`

---

## Installation

### From PowerShell Gallery

```powershell
Install-Module -Name CSVToRainbow -Scope CurrentUser
```

### Manual

Clone or download the repo and copy the `CSVToRainbow` folder to your PowerShell modules directory:

```
# PowerShell 7+
$env:USERPROFILE\Documents\PowerShell\Modules\CSVToRainbow\

# Windows PowerShell 5.1
$env:USERPROFILE\Documents\WindowsPowerShell\Modules\CSVToRainbow\
```

---

## Usage

### Single file

```powershell
Send-RainbowCsv `
    -ReportPath "C:\Logs\export.csv" `
    -EmailTo "ops@company.com" `
    -From "noreply@company.com" `
    -SmtpServer "mail.company.com"
```

### Multiple files

```powershell
Send-RainbowCsv `
    -ReportPath "C:\Logs\users.csv","C:\Logs\groups.csv" `
    -Title "Weekly Audit" `
    -EmailTo "ops@company.com" `
    -From "noreply@company.com" `
    -SmtpServer "mail.company.com"
```

### Pipeline from Get-ChildItem

```powershell
Get-ChildItem C:\Logs\*.csv | Send-RainbowCsv `
    -EmailTo "ops@company.com" `
    -From "noreply@company.com" `
    -SmtpServer "mail.company.com"
```

### Inline only — no attachments

```powershell
Get-ChildItem C:\Logs\*.csv | Send-RainbowCsv `
    -EmailTo "ops@company.com" `
    -From "noreply@company.com" `
    -SmtpServer "mail.company.com" `
    -NoAttach
```

### Completion ping — no CSV

```powershell
Send-RainbowCsv `
    -NoReport `
    -Title "Nightly Job Complete" `
    -EmailTo "ops@company.com" `
    -From "noreply@company.com" `
    -SmtpServer "mail.company.com"
```

---

## Parameters

| Parameter | Type | Required | Default | Description |
|---|---|---|---|---|
| `ReportPath` | `string[]` | No | — | CSV file path(s). Pipeline-aware (`FullName`, `Path` aliases). |
| `Title` | `string` | No | Auto-generated | Subject line and email heading. Timestamped filename used if omitted. |
| `EmailTo` | `string[]` | **Yes** | — | One or more recipient addresses. |
| `From` | `string` | **Yes** | — | Sender address. |
| `SmtpServer` | `string` | **Yes** | — | SMTP server hostname. |
| `SmtpPort` | `int` | No | `25` | SMTP port. |
| `NoReport` | `switch` | No | — | Skip CSV processing; send a plain completion notification. |
| `NoAttach` | `switch` | No | — | Send inline HTML only; do not attach CSV files. Alias: `-noa` |
| `Credential` | `PSCredential` | No | — | SMTP authentication credentials. |

---

## Requirements

- PowerShell 5.1 or later
- Internet access on first run (to install MailKit/MimeKit from NuGet if not already present)

---

## License

MIT
