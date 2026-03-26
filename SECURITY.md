# Security Policy

## Reporting a vulnerability

If you believe you found a security issue in `CUDA_Mnemonic_Recovery`, please do not open a public issue first.

Send the report privately to the maintainer with:

- a clear description of the issue
- the affected version or commit
- reproduction steps
- expected impact
- any proof-of-concept data that helps validate the report

Please avoid publishing exploit details until the maintainer has had a reasonable chance to investigate and ship a fix or mitigation.

## Scope

This repository is a recovery-focused CUDA tool. Security reports are especially helpful for:

- unsafe file parsing
- memory corruption or GPU/host buffer misuse
- crashes triggered by crafted input files
- unsafe output handling
- secrets accidentally written or exposed in logs

## Support expectations

Best-effort support is provided for the current public branch. Older snapshots or private experiments may not receive the same response time.
