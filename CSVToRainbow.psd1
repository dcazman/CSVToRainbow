@{
    ModuleVersion     = '1.0.0'
    GUID              = '5afbbe01-81b0-4a5c-8219-2ffa8be74aff'
    Author            = 'Dan Casmas'
    CompanyName       = ''
    Copyright         = '(c) 2025 Dan Casmas. All rights reserved.'
    Description       = 'Sends CSV files as rainbow-colored, scrollable HTML tables in email. Column-colored headers, zebra rows, empty-cell highlighting, plain-text fallback, and optional attachments — powered by MailKit (auto-installed if missing).'
    PowerShellVersion = '5.1'
    RootModule        = 'CSVToRainbow.psm1'
    FunctionsToExport = @('Send-RainbowCsv')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('CSV', 'Email', 'HTML', 'MailKit', 'Rainbow', 'Table', 'SMTP', 'Report')
            ProjectUri   = ''
            LicenseUri   = ''
            ReleaseNotes = 'Initial release.'
        }
    }
}
