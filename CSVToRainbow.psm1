<#
===============================================================================
 CSVToRainbow.psm1
===============================================================================
 Module : CSVToRainbow
 Purpose: Turn one or more CSV files into rainbow-colored, scrollable HTML
          tables and email them — with a plain-text fallback for clients that
          don't render HTML.

 Public surface:
   Send-RainbowCsv   Main entry point. See its comment-based help below.

 Mail transport:
   Uses MailKit/MimeKit (auto-installed from NuGet if not already present)
   rather than the deprecated Send-MailMessage cmdlet.

 Layout:
   - Private Functions : helpers — assembly loading, SMTP send, HTML/text
                         rendering, title cleanup. Not exported.
   - Public Functions  : Send-RainbowCsv, the only exported command.
===============================================================================
#>

#region Private Functions

# Locate the MailKit and MimeKit DLLs on disk and load them into the session.
# Searches the common per-user module/package folders first; if either DLL is
# missing, installs both from NuGet and looks again. Throws if still not found.
function Resolve-MailkitAssemblies {
    [CmdletBinding()]
    param()

    # Per-user locations where the DLLs are likely to already exist
    $searchPaths = @(
        "$env:USERPROFILE\Documents\WindowsPowerShell\Modules",
        "$env:USERPROFILE\Documents\PowerShell\Modules",
        "$env:USERPROFILE\AppData\Local\PackageManagement\NuGet\Packages"
    )

    $mailkitPath = $null
    $mimekitPath = $null

    # Scan each search path for the two DLLs, stopping once each is found
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            if (-not $mailkitPath) {
                $mailkitPath = Get-ChildItem -Path $path -Recurse -Filter "MailKit.dll" -ErrorAction SilentlyContinue | Select-Object -First 1
            }
            if (-not $mimekitPath) {
                $mimekitPath = Get-ChildItem -Path $path -Recurse -Filter "MimeKit.dll" -ErrorAction SilentlyContinue | Select-Object -First 1
            }
        }
    }

    # Either DLL missing? Install both from NuGet, then re-locate them
    if (-not $mailkitPath -or -not $mimekitPath) {
        Write-Verbose "MailKit/MimeKit not found. Installing from NuGet..."
        Register-PackageSource -Name MyNuGet -Location "https://www.nuget.org/api/v2" -ProviderName NuGet -ErrorAction SilentlyContinue
        Install-Package MimeKit -SkipDependencies -Source "MyNuGet" -Scope CurrentUser -Force -ErrorAction Stop
        Install-Package MailKit -SkipDependencies -Source "MyNuGet" -Scope CurrentUser -Force -ErrorAction Stop

        $mailkitPath = Get-ChildItem -Path "$env:USERPROFILE\AppData\Local\PackageManagement\NuGet\Packages" -Recurse -Filter "MailKit.dll" -ErrorAction Stop | Select-Object -First 1
        $mimekitPath = Get-ChildItem -Path "$env:USERPROFILE\AppData\Local\PackageManagement\NuGet\Packages" -Recurse -Filter "MimeKit.dll" -ErrorAction Stop | Select-Object -First 1
    }

    if (-not $mailkitPath -or -not $mimekitPath) {
        throw "Unable to locate MailKit/MimeKit DLLs even after installation."
    }

    # Load MimeKit first — MailKit depends on it
    Add-Type -Path $mimekitPath.FullName
    Add-Type -Path $mailkitPath.FullName
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

    # Assemble the message: sender, recipients, and subject
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
        if (Test-Path $file -PathType Leaf) {
            [void]$builder.Attachments.Add($file)
        }
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

# Per-column colors, cycled in order across a table's columns (wraps if there
# are more columns than entries). Pastel shades chosen for readable text.
$script:RainbowPalette = @(
    '#FFB3B3',  # red
    '#FFDDB3',  # orange
    '#FFFAB3',  # yellow
    '#B3FFB8',  # green
    '#B3E5FF',  # blue
    '#D4B3FF',  # purple
    '#FFB3EC'   # pink
)

# Render one CSV's rows (already imported as objects) into an HTML fragment:
# a titled, scrollable table with rainbow-colored columns and a row/column count.
function Get-RainbowTableHtml {
    param(
        [object[]]$CsvData,
        [string]$SectionTitle
    )

    # Column names come from the first object; every CSV row shares the same set
    $props     = $CsvData[0].PSObject.Properties.Name
    $rowCount  = @($CsvData).Count
    $colCount  = $props.Count
    $summary   = "$rowCount row(s) &bull; $colCount column(s)"

    # Header row — each column gets its rainbow color, sticky on scroll
    $headerCells = for ($i = 0; $i -lt $props.Count; $i++) {
        $color = $script:RainbowPalette[$i % $script:RainbowPalette.Count]
        "<th style='background-color:$color; border:1px solid #aaa; padding:8px 10px; " +
        "text-align:left; position:sticky; top:0; white-space:nowrap; font-family:Arial; font-size:13px;'>" +
        "$($props[$i])</th>"
    }

    # Data rows — zebra stripe + colored left border per column; grey out empty cells
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
                "<td style='background-color:$rowBg; border:1px solid #ddd; border-left:3px solid $color; " +
                "padding:6px 8px; font-family:Arial; font-size:13px;'>$val</td>"
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

# Produce a UTC-timestamped title. If no explicit Title is given, derive a
# clean slug from the CSV filename (strip punctuation, collapse spaces/dashes).
function Get-CleanTitle {
    param([string]$ReportPath, [string]$Title)

    if ([string]::IsNullOrWhiteSpace($Title)) {
        $base  = [System.IO.Path]::GetFileNameWithoutExtension($ReportPath)
        $clean = $base -replace '[^a-zA-Z0-9\s-]', '' -replace '[_\s]+', '-' -replace '-{2,}', '-'
        $clean = $clean.Trim('-')
    }
    else {
        $clean = $Title
    }

    # Prefix with a sortable UTC stamp, e.g. 20260528-1430Z-my-report
    $ts = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmm") + "Z"
    return "$ts-$clean"
}

# Wrap the rendered table fragment(s) in a full HTML document with a header
# showing the title and UTC timestamp. Used as the HTML body of the email.
function Build-HtmlEmailBody {
    param(
        [string]$Title,
        [datetime]$Date,
        [string]$HtmlContent = ''
    )

    return @"
<!DOCTYPE html>
<html>
<head><meta charset='utf-8'></head>
<body style='font-family:Arial; margin:20px; background:#fff;'>
  <div style='font-size:12px; color:#999; margin-bottom:6px;'>$($Date.ToUniversalTime().ToString("yyyy-MM-dd HH:mm")) UTC</div>
  <h1 style='font-size:18px; text-align:center; margin-bottom:24px; color:#222;'>$Title</h1>
  $HtmlContent
</body>
</html>
"@
}

# Build the plain-text fallback body: title, timestamp, and a one-line
# row/column summary per CSV section. Shown by clients that can't render HTML.
function Build-PlainEmailBody {
    param(
        [string]$Title,
        [datetime]$Date,
        [System.Collections.Generic.List[hashtable]]$Sections,
        [bool]$HasAttachments
    )

    $lines = @(
        $Title,
        "$($Date.ToUniversalTime().ToString("yyyy-MM-dd HH:mm")) UTC",
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

#region Public Functions

function Send-RainbowCsv {
<#
.SYNOPSIS
    Sends CSV files as rainbow-colored, scrollable HTML tables in an email.

.DESCRIPTION
    Converts one or more CSV files into styled HTML tables and emails them.
    Each column gets a distinct color. Empty cells are highlighted. Rows alternate
    for readability. A plain-text fallback is included for non-HTML clients.
    Uses MailKit (auto-installed if missing) instead of the deprecated Send-MailMessage.

.PARAMETER ReportPath
    One or more CSV file paths. Accepts pipeline input by value or property name
    (FullName, Path) — compatible with Get-ChildItem output.

.PARAMETER Title
    Optional subject line and heading. Auto-generated from filename + UTC timestamp if omitted.

.PARAMETER EmailTo
    One or more recipient email addresses. Mandatory.

.PARAMETER From
    Sender email address. Mandatory.

.PARAMETER SmtpServer
    SMTP server hostname. Mandatory.

.PARAMETER SmtpPort
    SMTP port. Default: 25.

.PARAMETER NoReport
    Skip CSV processing and send a plain completion notification instead.

.PARAMETER NoAttach
    Send inline HTML only; do not attach the CSV files.

.PARAMETER Credential
    Optional PSCredential for SMTP authentication.

.EXAMPLE
    Send-RainbowCsv -ReportPath "C:\Logs\export.csv" -EmailTo "ops@company.com" -From "noreply@company.com" -SmtpServer "mail.company.com"

.EXAMPLE
    Get-ChildItem C:\Logs\*.csv | Send-RainbowCsv -EmailTo "ops@company.com" -From "noreply@company.com" -SmtpServer "mail.company.com" -NoAttach

.EXAMPLE
    Send-RainbowCsv -NoReport -Title "Job Complete" -EmailTo "ops@company.com" -From "noreply@company.com" -SmtpServer "mail.company.com"
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'Path')]
        [string[]]$ReportPath,

        [string]$Title,

        [Parameter(Mandatory)]
        [ValidatePattern("^[a-zA-Z0-9][a-zA-Z0-9._%+-]*@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")]
        [string[]]$EmailTo,

        [Parameter(Mandatory)]
        [ValidatePattern("^[a-zA-Z0-9][a-zA-Z0-9._%+-]*@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")]
        [string]$From,

        [Parameter(Mandatory)]
        [string]$SmtpServer,

        [int]$SmtpPort = 25,

        [switch]$NoReport,

        [Alias('noa')]
        [switch]$NoAttach,

        [PSCredential]$Credential
    )

    begin {
        # Ensure mail assemblies are loaded once, then gather paths across the pipeline
        Resolve-MailkitAssemblies
        $collectedPaths = @()
        $dateNow        = Get-Date
    }

    process {
        # Accumulate paths from each pipeline item; processing happens in end{}
        if ($ReportPath) { $collectedPaths += $ReportPath }
    }

    end {
        try {
            # Decide the title: completion stamp when there's nothing to report,
            # otherwise a clean title derived from the first CSV / -Title
            $finalTitle = if ($NoReport -or -not $collectedPaths) {
                "$((Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmm"))Z-complete"
            }
            else {
                Get-CleanTitle -ReportPath $collectedPaths[0] -Title $Title
            }

            # NoReport or no input paths: plain completion ping
            if ($NoReport -or -not $collectedPaths) {
                $html  = Build-HtmlEmailBody -Title $finalTitle -Date $dateNow
                $plain = "$finalTitle`n$($dateNow.ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC"
                Invoke-MailkitSend -To $EmailTo -From $From -Subject $finalTitle `
                    -HtmlBody $html -PlainBody $plain `
                    -SmtpServer $SmtpServer -Port $SmtpPort -Credential $Credential
                return
            }

            # Process each CSV into a rainbow table, collecting HTML fragments,
            # plain-text summary data, and the files to attach
            $allHtml   = ''
            $sections  = [System.Collections.Generic.List[hashtable]]::new()
            $attachments = @()

            foreach ($path in $collectedPaths) {
                if (-not (Test-Path $path -PathType Leaf)) { throw "File not found: $path" }

                $csv = Import-Csv -Path $path
                if (-not $csv -or @($csv).Count -eq 0) { throw "No data in file: $path" }

                # One HTML section per file, titled with the file's base name
                $sectionTitle = [System.IO.Path]::GetFileNameWithoutExtension($path)
                $allHtml += Get-RainbowTableHtml -CsvData $csv -SectionTitle $sectionTitle

                # Record counts for the plain-text fallback
                $sections.Add(@{
                    Title    = $sectionTitle
                    RowCount = @($csv).Count
                    ColCount = $csv[0].PSObject.Properties.Name.Count
                })

                if (-not $NoAttach) { $attachments += $path }
            }

            # Compose both body formats and send the message
            $htmlBody  = Build-HtmlEmailBody -Title $finalTitle -Date $dateNow -HtmlContent $allHtml
            $plainBody = Build-PlainEmailBody -Title $finalTitle -Date $dateNow -Sections $sections -HasAttachments (-not $NoAttach)

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

#endregion

Export-ModuleMember -Function Send-RainbowCsv
