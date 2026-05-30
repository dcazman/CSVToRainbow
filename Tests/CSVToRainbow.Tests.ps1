# =============================================================================
# Tests/CSVToRainbow.Tests.ps1
# =============================================================================
# Pester v5 tests for CSVToRainbow private utility functions.
# Run from the repo root:
#   Invoke-Pester ./Tests/CSVToRainbow.Tests.ps1 -Output Detailed
# =============================================================================

# Import at script scope so InModuleScope can resolve it during discovery
$modulePath = Join-Path $PSScriptRoot '..' 'CSVToRainbow.psm1'
Import-Module $modulePath -Force

Describe 'Get-LocalStamp' {

    InModuleScope CSVToRainbow {

        It 'Returns a hashtable with FileStamp and Display keys' {
            $result = Get-LocalStamp
            $result           | Should -BeOfType [hashtable]
            $result.FileStamp | Should -Not -BeNullOrEmpty
            $result.Display   | Should -Not -BeNullOrEmpty
        }

        It 'FileStamp matches safe filename pattern yyyy-MM-dd_hh-mmtt' {
            $result = Get-LocalStamp
            $result.FileStamp | Should -Match '^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}(AM|PM)$'
        }

        It 'Display contains a timezone label in parentheses' {
            $result = Get-LocalStamp
            $result.Display | Should -Match '\(.+\)$'
        }
    }
}

Describe 'Get-CleanTitle' {

    InModuleScope CSVToRainbow {

        It 'Uses filename base when Title is empty' {
            $result = Get-CleanTitle -ReportPath 'C:\logs\my_report.csv' -Title '' -Stamp '2026-01-01_12-00PM'
            $result | Should -Be '2026-01-01_12-00PM-my-report'
        }

        It 'Uses supplied Title when provided' {
            $result = Get-CleanTitle -ReportPath 'C:\logs\anything.csv' -Title 'Weekly Audit' -Stamp '2026-01-01_12-00PM'
            $result | Should -Be '2026-01-01_12-00PM-Weekly Audit'
        }

        It 'Strips special characters from filename' {
            $result = Get-CleanTitle -ReportPath 'C:\logs\report (v2)!.csv' -Title '' -Stamp 'STAMP'
            $result | Should -Be 'STAMP-report-v2'
        }

        It 'Collapses multiple dashes' {
            $result = Get-CleanTitle -ReportPath 'C:\logs\a___b---c.csv' -Title '' -Stamp 'S'
            $result | Should -Be 'S-a-b-c'
        }
    }
}

Describe 'Build-PlainEmailBody' {

    InModuleScope CSVToRainbow {

        It 'Includes title and display timestamp' {
            $sections = [System.Collections.Generic.List[hashtable]]::new()
            $sections.Add(@{ Title = 'report'; RowCount = 5; ColCount = 3 })
            $result = Build-PlainEmailBody -Title 'My Title' -Display 'Today' -Sections $sections -HasAttachments $false
            $result | Should -Match 'My Title'
            $result | Should -Match 'Today'
        }

        It 'Includes section summary line' {
            $sections = [System.Collections.Generic.List[hashtable]]::new()
            $sections.Add(@{ Title = 'users'; RowCount = 10; ColCount = 4 })
            $result = Build-PlainEmailBody -Title 'T' -Display 'D' -Sections $sections -HasAttachments $false
            $result | Should -Match 'users: 10 row\(s\), 4 column\(s\)'
        }

        It 'Appends attachment note when HasAttachments is true' {
            $sections = [System.Collections.Generic.List[hashtable]]::new()
            $result = Build-PlainEmailBody -Title 'T' -Display 'D' -Sections $sections -HasAttachments $true
            $result | Should -Match 'CSV files attached'
        }

        It 'Does not include attachment note when HasAttachments is false' {
            $sections = [System.Collections.Generic.List[hashtable]]::new()
            $result = Build-PlainEmailBody -Title 'T' -Display 'D' -Sections $sections -HasAttachments $false
            $result | Should -Not -Match 'CSV files attached'
        }
    }
}

Describe 'Build-HtmlEmailBody' {

    InModuleScope CSVToRainbow {

        It 'Returns a string containing the title' {
            $result = Build-HtmlEmailBody -Title 'Test Title' -Display 'Now' -HtmlContent '<p>hi</p>'
            $result | Should -BeOfType [string]
            $result | Should -Match 'Test Title'
        }

        It 'Includes the display timestamp' {
            $result = Build-HtmlEmailBody -Title 'T' -Display '2026-01-01 12:00 PM' -HtmlContent ''
            $result | Should -Match '2026-01-01 12:00 PM'
        }

        It 'Injects HtmlContent into the body' {
            $result = Build-HtmlEmailBody -Title 'T' -Display 'D' -HtmlContent '<table>test</table>'
            $result | Should -Match '<table>test</table>'
        }
    }
}

Describe 'Get-RainbowTableHtml' {

    InModuleScope CSVToRainbow {

        BeforeAll {
            $script:csv = @(
                [PSCustomObject]@{ Name = 'Alice'; Age = '30'; City = 'NY' }
                [PSCustomObject]@{ Name = 'Bob';   Age = '';   City = 'LA' }
            )
        }

        It 'Returns a non-empty string' {
            $result = Get-RainbowTableHtml -CsvData $script:csv -SectionTitle 'People'
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Includes the section title' {
            $result = Get-RainbowTableHtml -CsvData $script:csv -SectionTitle 'People'
            $result | Should -Match 'People'
        }

        It 'Shows row and column count summary' {
            $result = Get-RainbowTableHtml -CsvData $script:csv -SectionTitle 'People'
            $result | Should -Match '2 row'
            $result | Should -Match '3 column'
        }

        It 'HTML-encodes special characters in cell values' {
            $dangerousCsv = @(
                [PSCustomObject]@{ Col = '<script>alert(1)</script>' }
            )
            $result = Get-RainbowTableHtml -CsvData $dangerousCsv -SectionTitle 'Test'
            $result | Should -Not -Match '<script>'
            $result | Should -Match '&lt;script&gt;'
        }

        It 'Renders empty cells with the em-dash placeholder' {
            $result = Get-RainbowTableHtml -CsvData $script:csv -SectionTitle 'People'
            $result | Should -Match '&#8212;'
        }
    }
}
