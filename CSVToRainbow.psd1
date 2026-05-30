@{
    ModuleVersion     = '1.0.2'
    GUID              = '5afbbe01-81b0-4a5c-8219-2ffa8be74aff'
    Author            = 'Dan Casmas'
    CompanyName       = ''
    Copyright         = '(c) 2026 Dan Casmas. All rights reserved.'
    Description       = 'Sends CSV files as rainbow-colored, scrollable HTML tables in email. Column-colored headers, zebra rows, empty-cell highlighting, plain-text fallback, and optional attachments — MailKit bootstrapped from NuGet on first use. Works on Windows, macOS, and Linux.'
    PowerShellVersion = '5.1'
    RootModule        = 'CSVToRainbow.psm1'
    FunctionsToExport = @('CSVToRainbow', 'Set-RainbowCsvConfig')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    FileList          = @(
        'CSVToRainbow.psd1',
        'CSVToRainbow.psm1',
        'example.json',
        'LICENSE',
        'README.md',
        'SECURITY.md'
    )
    PrivateData       = @{
        PSData = @{
            Tags         = @('CSV', 'Email', 'HTML', 'MailKit', 'Rainbow', 'Table', 'SMTP', 'Report', 'CrossPlatform', 'PowerShell')
            ProjectUri   = 'https://github.com/dcazman/CSVToRainbow'
            LicenseUri   = 'https://github.com/dcazman/CSVToRainbow/blob/main/LICENSE'
            ReleaseNotes = @'
1.0.1
- Fixed cross-platform bin path (Join-Path replaces hardcoded backslash)
- net6.0 DLL now preferred over netstandard2.1 during NuGet bootstrap
- Corrected SECURITY.md: cell values are HTML-encoded via HtmlEncode
- Updated license to MIT throughout
'@
        }
    }
}
