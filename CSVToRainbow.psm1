# =============================================================================
# CSVToRainbow.psm1
# =============================================================================
# Sends CSV files as rainbow-colored, scrollable HTML tables in email.
# Each column gets a distinct color. Empty cells are highlighted. Rows
# alternate for readability. Plain-text fallback included for non-HTML clients.
#
# Works on Windows (PS 5.1+), macOS, and Linux (PS 7.0+).
#
# Exported commands:
#   CSVToRainbow          Convert and send one or more CSV files.
#   Set-RainbowCsvConfig  Save default From / SmtpServer / SmtpPort once.
#
# Config file (optional but recommended — run Set-RainbowCsvConfig to create):
#   Stored alongside the module: env.json in the same folder as this file.
#   Same path on all platforms — no setup required beyond a CurrentUser install.
#
# On every run, CSVToRainbow reads the config file automatically. If it is
# missing or a required field is invalid, the user is prompted and offered
# the option to save for next time.
#
# -----------------------------------------------------------------------------
# Repo:     https://github.com/dcazman/CSVToRainbow
# Author:   Dan Casmas
# Version:  1.0.2
# =============================================================================

#region Module-level state

# Config lives next to the module — works on all platforms with no path logic.
$script:ConfigPath     = Join-Path $PSScriptRoot 'env.json'
$script:EmailRegex     = '^[a-zA-Z0-9][a-zA-Z0-9._%+-]*@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
$script:RainbowPalette = @(
    '#FFB3B3',  # red
    '#FFDDB3',  # orange
    '#FFFAB3',  # yellow
    '#B3FFB8',  # green
    '#B3E5FF',  # blue
    '#D4B3FF',  # purple
    '#FFB3EC'   # pink
)

#endregion

#region Public Functions

function CSVToRainbow {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'Path')]
        [string[]]$ReportPath,

        [string]$Title,

        [Parameter(Mandatory)]
        [string[]]$EmailTo,

        [string]$From,

        [string]$SmtpServer,

        [Nullable[int]]$SmtpPort,

        [Alias('noa')]
        [switch]$NoAttach,

        [PSCredential]$Credential
    )

    begin {
        Resolve-MailkitAssemblies
        $collectedPaths = [System.Collections.Generic.List[string]]::new()
        $ts             = Get-LocalStamp

        # Read config — prompts for any missing/invalid required fields,
        # offers to save if the user had to type anything in.
        $cfg = Read-RainbowConfig -FromParam $From -SmtpServerParam $SmtpServer

        # Apply resolved values (param always wins over config)
        if ([string]::IsNullOrWhiteSpace($From))       { $From       = $cfg.From }
        if ([string]::IsNullOrWhiteSpace($SmtpServer)) { $SmtpServer = $cfg.SmtpServer }
        if ($null -eq $SmtpPort)                       { $SmtpPort   = $cfg.SmtpPort }

        # Validate recipients
        foreach ($addr in $EmailTo) {
            if ($addr -notmatch $script:EmailRegex) {
                throw "Invalid -EmailTo address: '$addr'"
            }
        }

        if ($SmtpPort -lt 1 -or $SmtpPort -gt 65535) {
            throw "Invalid -SmtpPort: $SmtpPort. Must be between 1 and 65535."
        }
    }

    process {
        if ($null -ne $ReportPath) {
            $collectedPaths.AddRange($ReportPath)
        }
    }

    end {
        try {
            if ($collectedPaths.Count -eq 0) {
                throw "No CSV files provided. Use -ReportPath to specify one or more CSV files."
            }

            $finalTitle = Get-CleanTitle -ReportPath $collectedPaths[0] -Title $Title -Stamp $ts.FileStamp

            # Process each CSV into a rainbow table
            $allHtml     = ''
            $sections    = [System.Collections.Generic.List[hashtable]]::new()
            $attachments = @()

            foreach ($path in $collectedPaths) {
                if (-not (Test-Path $path -PathType Leaf)) { throw "File not found: $path" }

                $csv = Import-Csv -Path $path
                if (-not $csv -or @($csv).Count -eq 0) { throw "No data in file: $path" }

                $sectionTitle = [System.IO.Path]::GetFileNameWithoutExtension($path)
                $allHtml     += Get-RainbowTableHtml -CsvData $csv -SectionTitle $sectionTitle

                $sections.Add(@{
                    Title    = $sectionTitle
                    RowCount = @($csv).Count
                    ColCount = $csv[0].PSObject.Properties.Name.Count
                })

                if (-not $NoAttach) { $attachments += $path }
            }

            $htmlBody  = Build-HtmlEmailBody -Title $finalTitle -Display $ts.Display -HtmlContent $allHtml
            $plainBody = Build-PlainEmailBody -Title $finalTitle -Display $ts.Display -Sections $sections -HasAttachments (-not $NoAttach)

            Invoke-MailkitSend -To $EmailTo -From $From -Subject $finalTitle `
                -HtmlBody $htmlBody -PlainBody $plainBody `
                -SmtpServer $SmtpServer -Port $SmtpPort `
                -Attachments $attachments -Credential $Credential
        }
        catch {
            Write-Error $_.Exception.Message
            throw
        }
    }
}

function Set-RainbowCsvConfig {
    # Saves From, SmtpServer, and SmtpPort to env.json next to the module so
    # you don't have to pass them on every CSVToRainbow call. Validates before
    # writing. Creates the config file if it does not exist.
    #
    # PARAMETERS:
    #   -From        Sender email address (mandatory).
    #   -SmtpServer  SMTP server hostname (mandatory).
    #   -SmtpPort    SMTP port (default: 25).
    #
    # EXAMPLES:
    #   Set-RainbowCsvConfig -From "noreply@company.com" -SmtpServer "mail.company.com"
    #   Set-RainbowCsvConfig -From "noreply@company.com" -SmtpServer "mail.company.com" -SmtpPort 587
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$From,

        [Parameter(Mandatory)]
        [string]$SmtpServer,

        [ValidateRange(1, 65535)]
        [int]$SmtpPort = 25
    )

    if ($From -notmatch $script:EmailRegex) {
        throw "Invalid -From address: '$From'"
    }
    if ([string]::IsNullOrWhiteSpace($SmtpServer)) {
        throw "-SmtpServer cannot be empty."
    }

    $config = @{ From = $From.Trim(); SmtpServer = $SmtpServer.Trim(); SmtpPort = $SmtpPort }

    if ($PSCmdlet.ShouldProcess($script:ConfigPath, "Write config")) {
        $config | ConvertTo-Json | Set-Content -Path $script:ConfigPath -Encoding UTF8
        Write-Host "Saved to: $($script:ConfigPath)"
        Write-Host "  From:       $From"
        Write-Host "  SmtpServer: $SmtpServer"
        Write-Host "  SmtpPort:   $SmtpPort"
        Write-Verbose "Config written to $($script:ConfigPath)"
    }
}

#endregion

#region Private Functions

# Resolves and loads local MimeKit and MailKit DLLs.
# Looks in $PSScriptRoot/bin/net48 (Windows PS) or $PSScriptRoot/bin/net6.0 (PS Core).
# If DLLs are missing, bootstraps by downloading latest versions directly from NuGet.
function Resolve-MailkitAssemblies {
    [CmdletBinding()]
    param()

    $subFolder  = if ($PSEdition -eq 'Core') { 'net6.0' } else { 'net48' }
    $binPath    = Join-Path $PSScriptRoot 'bin' $subFolder   # fix: was "bin\$subFolder" (backslash breaks macOS/Linux)
    $mimekitDll = Join-Path $binPath 'MimeKit.dll'
    $mailkitDll = Join-Path $binPath 'MailKit.dll'

    if (-not (Test-Path $mimekitDll) -or -not (Test-Path $mailkitDll)) {
        Write-Warning "CSVToRainbow: Required dependencies missing. Bootstrapping from NuGet..."

        $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) "CSVToRainbow_Bootstrap_$(Get-Random)"
        New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
        New-Item -ItemType Directory -Path $binPath  -Force | Out-Null

        try {
            foreach ($pkg in @('MimeKit', 'MailKit')) {
                $url     = "https://www.nuget.org/api/v2/package/$pkg"
                $zipFile = Join-Path $tempPath "$pkg.zip"

                Write-Verbose "Downloading $pkg (latest)..."
                Invoke-WebRequest -Uri $url -OutFile $zipFile -UseBasicParsing -ErrorAction Stop

                $extractPath = Join-Path $tempPath $pkg
                Expand-Archive -Path $zipFile -DestinationPath $extractPath -Force

                if ($subFolder -eq 'net48') {
                    $src = Join-Path $extractPath "lib" "net48" "$pkg.dll"   # fix: was string interpolation with backslashes
                    if (Test-Path $src) { Copy-Item $src -Destination $binPath -Force }
                }
                else {
                    # Prefer net6.0 over netstandard2.1 when both are present
                    $src = Get-ChildItem -Path $extractPath -Recurse -Filter "$pkg.dll" |
                           Where-Object { $_.DirectoryName -match 'net6\.0' } |
                           Select-Object -First 1

                    if (-not $src) {
                        $src = Get-ChildItem -Path $extractPath -Recurse -Filter "$pkg.dll" |
                               Where-Object { $_.DirectoryName -match 'netstandard2\.1' } |
                               Select-Object -First 1
                    }

                    if ($src) { Copy-Item $src.FullName -Destination $binPath -Force }
                }
            }
            Write-Verbose "Dependencies staged to: $binPath"
        }
        catch {
            throw "Failed to bootstrap MailKit/MimeKit: $($_.Exception.Message)"
        }
        finally {
            if (Test-Path $tempPath) { Remove-Item $tempPath -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    if (-not (Test-Path $mimekitDll) -or -not (Test-Path $mailkitDll)) {
        throw "Required dependencies could not be resolved or downloaded into: '$binPath'."
    }

    # Load MimeKit first — MailKit depends on it
    Add-Type -Path $mimekitDll
    Add-Type -Path $mailkitDll
}

# Returns a hashtable with two timestamp strings using the system's local timezone.
# Falls back to UTC if the conversion fails.
#   FileStamp — file/title-safe:  2026-05-29_02-06PM
#   Display   — human-readable:   2026-05-29 2:06 PM (Eastern Standard Time)
function Get-LocalStamp {
    try {
        $tz  = [System.TimeZoneInfo]::Local
        $now = [System.TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $tz)
        @{
            FileStamp = $now.ToString('yyyy-MM-dd_hh-mmtt')
            Display   = "$($now.ToString('yyyy-MM-dd h:mm tt')) ($($tz.DisplayName))"
        }
    }
    catch {
        $now = [DateTime]::UtcNow
        @{
            FileStamp = $now.ToString('yyyy-MM-dd_HH-mm') + 'Z'
            Display   = "$($now.ToString('yyyy-MM-dd HH:mm')) UTC"
        }
    }
}

# Called automatically at the start of every CSVToRainbow run.
#
# Resolution order:
#   1. If From or SmtpServer were passed directly as params, skip prompting for those.
#   2. Read env.json — if missing, warn and prompt for any values not already supplied.
#   3. Validate each field from the file — warn and prompt for anything bad.
#   4. SmtpPort: if missing or invalid, silently default to 25 (no prompt).
#   5. If the user was prompted for anything, offer to save to env.json for next time.
function Read-RainbowConfig {
    param(
        [string]$FromParam,
        [string]$SmtpServerParam
    )

    $result   = @{ From = $null; SmtpServer = $null; SmtpPort = 25 }
    $prompted = $false

    $needFrom       = [string]::IsNullOrWhiteSpace($FromParam)
    $needSmtpServer = [string]::IsNullOrWhiteSpace($SmtpServerParam)

    if (-not (Test-Path $script:ConfigPath)) {
        Write-Warning "CSVToRainbow: No config file found at $($script:ConfigPath)."
        Write-Warning "CSVToRainbow: Run Set-RainbowCsvConfig to create one, or enter values below."
    }
    else {
        try {
            $raw = Get-Content -Path $script:ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        }
        catch {
            Write-Warning "CSVToRainbow: env.json could not be parsed — $($_.Exception.Message)"
            $raw = $null
        }

        if ($raw) {
            # Warn on unknown keys
            $known = @('From', 'SmtpServer', 'SmtpPort')
            $raw.PSObject.Properties.Name | Where-Object { $_ -notin $known } | ForEach-Object {
                Write-Warning "CSVToRainbow: Unknown key '$_' in env.json — ignored."
            }

            if ($needFrom) {
                if ($raw.PSObject.Properties['From'] -and $raw.From -match $script:EmailRegex) {
                    $result.From = $raw.From.Trim()
                }
                elseif ($raw.PSObject.Properties['From']) {
                    Write-Warning "CSVToRainbow: 'From' in env.json ('$($raw.From)') is not a valid email address."
                }
            }

            if ($needSmtpServer) {
                if ($raw.PSObject.Properties['SmtpServer'] -and -not [string]::IsNullOrWhiteSpace($raw.SmtpServer)) {
                    $result.SmtpServer = $raw.SmtpServer.Trim()
                }
                elseif ($raw.PSObject.Properties['SmtpServer']) {
                    Write-Warning "CSVToRainbow: 'SmtpServer' in env.json is empty."
                }
            }

            # SmtpPort — silent fallback to 25 if bad
            if ($raw.PSObject.Properties['SmtpPort']) {
                $port = $raw.SmtpPort -as [int]
                if ($port -ge 1 -and $port -le 65535) {
                    $result.SmtpPort = $port
                }
                else {
                    Write-Warning "CSVToRainbow: 'SmtpPort' in env.json ('$($raw.SmtpPort)') is invalid — defaulting to 25."
                }
            }
        }
    }

    # --- Prompt for anything still missing ---

    if ($needFrom -and -not $result.From) {
        do {
            $result.From = (Read-Host "  From (sender email)").Trim()
            if ($result.From -notmatch $script:EmailRegex) {
                Write-Warning "  Not a valid email address. Try again."
                $result.From = $null
            }
        } while (-not $result.From)
        $prompted = $true
    }

    if ($needSmtpServer -and -not $result.SmtpServer) {
        do {
            $result.SmtpServer = (Read-Host "  SMTP server hostname").Trim()
            if ([string]::IsNullOrWhiteSpace($result.SmtpServer)) {
                Write-Warning "  SMTP server cannot be empty. Try again."
                $result.SmtpServer = $null
            }
        } while (-not $result.SmtpServer)
        $prompted = $true
    }

    # --- Offer to save if the user typed anything in ---
    if ($prompted) {
        $save = (Read-Host "  Save these settings for next time? (Y/N)").Trim()
        if ($save -match '^[Yy]') {
            Set-RainbowCsvConfig -From $result.From -SmtpServer $result.SmtpServer -SmtpPort $result.SmtpPort
        }
    }

    return $result
}

# Build a MimeMessage from the supplied parts and send it over SMTP via MailKit.
# Honors -WhatIf/-Confirm through ShouldProcess and always disposes the client.
function Invoke-MailkitSend {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string[]]$To,
        [string]$From,
        [string]$Subject,
        [string]$HtmlBody,
        [string]$PlainBody,
        [string]$SmtpServer,
        [int]$Port = 25,
        [string[]]$Attachments = @(),
        [PSCredential]$Credential
    )

    $message = [MimeKit.MimeMessage]::new()
    $message.From.Add([MimeKit.MailboxAddress]::Parse($From))
    foreach ($addr in $To) {
        $message.To.Add([MimeKit.MailboxAddress]::Parse($addr))
    }
    $message.Subject = $Subject

    # Multipart body: plain-text + HTML alternatives, plus any file attachments
    $builder = [MimeKit.BodyBuilder]::new()
    $builder.TextBody = $PlainBody
    $builder.HtmlBody = $HtmlBody
    foreach ($file in $Attachments) {
        if (Test-Path $file -PathType Leaf) { [void]$builder.Attachments.Add($file) }
    }
    $message.Body = $builder.ToMessageBody()

    # Accept any server certificate — convenient for internal/self-signed relays
    $smtp = [MailKit.Net.Smtp.SmtpClient]::new()
    $smtp.ServerCertificateValidationCallback = { $true }

    try {
        Write-Verbose "Connecting to $SmtpServer`:$Port..."
        $smtp.Connect($SmtpServer, $Port, [MailKit.Security.SecureSocketOptions]::Auto)

        if ($Credential) {
            Write-Verbose "Authenticating..."
            $smtp.Authenticate($Credential.UserName, $Credential.GetNetworkCredential().Password)
        }

        if ($PSCmdlet.ShouldProcess("$SmtpServer`:$Port", "Send mail to $($To -join ', ')")) {
            $smtp.Send($message)
        }

        Write-Verbose "Disconnecting..."
        $smtp.Disconnect($true)
    }
    finally {
        $smtp.Dispose()
    }
}

# Render one CSV into an HTML fragment: titled scrollable table with
# rainbow-colored columns, zebra rows, sticky header, and row/col summary.
# Cell and header values are HTML-encoded via [System.Net.WebUtility]::HtmlEncode
# to safely handle special characters (<, >, &, quotes, etc.).
function Get-RainbowTableHtml {
    param(
        [object[]]$CsvData,
        [string]$SectionTitle
    )

    $props    = $CsvData[0].PSObject.Properties.Name
    $rowCount = @($CsvData).Count
    $colCount = $props.Count
    $summary  = "$rowCount row(s) &bull; $colCount column(s)"

    $headerCells = for ($i = 0; $i -lt $props.Count; $i++) {
        $color         = $script:RainbowPalette[$i % $script:RainbowPalette.Count]
        $escapedHeader = [System.Net.WebUtility]::HtmlEncode($props[$i])
        "<th style='background-color:$color; border:1px solid #aaa; padding:8px 10px; " +
        "text-align:left; position:sticky; top:0; white-space:nowrap; font-family:Arial; font-size:13px;'>" +
        "$escapedHeader</th>"
    }

    $rows = for ($r = 0; $r -lt $CsvData.Count; $r++) {
        $rowBg = if ($r % 2 -eq 0) { '#ffffff' } else { '#f5f5f5' }
        $cells = for ($i = 0; $i -lt $props.Count; $i++) {
            $color = $script:RainbowPalette[$i % $script:RainbowPalette.Count]
            $val   = $CsvData[$r].($props[$i])
            if ([string]::IsNullOrWhiteSpace($val)) {
                "<td style='background-color:#e8e8e8; border:1px solid #ddd; border-left:3px solid $color; " +
                "padding:6px 8px; color:#aaa; font-style:italic; font-family:Arial; font-size:13px;'>&#8212;</td>"
            }
            else {
                $escapedVal = [System.Net.WebUtility]::HtmlEncode($val)
                "<td style='background-color:$rowBg; border:1px solid #ddd; border-left:3px solid $color; " +
                "padding:6px 8px; font-family:Arial; font-size:13px;'>$escapedVal</td>"
            }
        }
        "<tr>$($cells -join '')</tr>"
    }

    return @"
<h2 style='margin-top:24px; margin-bottom:4px; font-family:Arial; font-size:15px; color:#333;'>$SectionTitle</h2>
<div style='font-size:11px; color:#999; margin-bottom:6px; font-family:Arial;'>$summary</div>
<div style='max-height:300px; overflow-y:auto; border:1px solid #ccc; border-radius:3px; margin-bottom:28px;'>
  <table style='border-collapse:collapse; width:100%;'>
    <thead><tr>$($headerCells -join '')</tr></thead>
    <tbody>$($rows -join '')</tbody>
  </table>
</div>
"@
}

# Produce a local-timestamped title slug from the CSV filename or the -Title param.
function Get-CleanTitle {
    param([string]$ReportPath, [string]$Title, [string]$Stamp)

    if ([string]::IsNullOrWhiteSpace($Title)) {
        $base  = [System.IO.Path]::GetFileNameWithoutExtension($ReportPath)
        $clean = $base -replace '[^a-zA-Z0-9\s-]', '' -replace '[_\s]+', '-' -replace '-{2,}', '-'
        $clean = $clean.Trim('-')
    }
    else {
        $clean = $Title
    }

    return "$Stamp-$clean"
}

# Wrap table HTML fragment(s) in a full HTML document with title and local timestamp.
function Build-HtmlEmailBody {
    param(
        [string]$Title,
        [string]$Display,
        [string]$HtmlContent = ''
    )

    return @"
<!DOCTYPE html>
<html>
<head><meta charset='utf-8'></head>
<body style='font-family:Arial; margin:20px; background:#fff;'>
  <div style='font-size:12px; color:#999; margin-bottom:6px;'>$Display</div>
  <h1 style='font-size:18px; text-align:center; margin-bottom:24px; color:#222;'>$Title</h1>
  $HtmlContent
</body>
</html>
"@
}

# Build the plain-text fallback body with a one-line summary per CSV section.
function Build-PlainEmailBody {
    param(
        [string]$Title,
        [string]$Display,
        [System.Collections.Generic.List[hashtable]]$Sections,
        [bool]$HasAttachments
    )

    $lines = @(
        $Title,
        $Display,
        ""
    )

    foreach ($s in $Sections) {
        $lines += "$($s.Title): $($s.RowCount) row(s), $($s.ColCount) column(s)"
    }

    if ($HasAttachments) {
        $lines += ""
        $lines += "CSV files attached."
    }

    return $lines -join "`n"
}
#endregion

Export-ModuleMember -Function CSVToRainbow, Set-RainbowCsvConfig
