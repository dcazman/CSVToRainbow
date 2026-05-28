# Security Policy

## Supported Versions

CSVToRainbow follows semantic versioning. Security fixes are applied to the
latest released version.

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Security Considerations

- **SMTP certificate validation.** `CSVToRainbow` accepts any server
  certificate (`ServerCertificateValidationCallback = { $true }`) to ease use
  with internal or self-signed relays. This means TLS connections are *not*
  validated against a trusted CA. Only point the module at SMTP servers you
  trust, ideally on a trusted network.
- **Credentials.** When using `-Credential`, the password is read from the
  `PSCredential` at send time and passed to the SMTP server. Avoid hard-coding
  credentials in scripts; use `Get-Credential` or a secret store.
- **CSV content is rendered as HTML.** Cell values are inserted directly into
  the HTML body without escaping. Only send CSV files from sources you trust.

## Reporting a Vulnerability

Please report security issues by opening a
[GitHub issue](https://github.com/dcazman/CSVToRainbow/issues) or contacting
the maintainer directly. Include steps to reproduce and the affected version.

You can expect an initial response within a few business days. Accepted issues
will be addressed in a patch release; declined reports will receive an
explanation.
