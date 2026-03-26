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

## Lawful-use reminder

`CUDA_Mnemonic_Recovery` is intended only for lawful recovery of wallets, backups, and seed phrases that belong to you or that you are explicitly authorized to recover.

The author strongly discourages any malicious use of this software. Any unlawful or abusive use is entirely the responsibility of the user.

For the concise user-facing policy, see [`RESPONSIBLE_USE.md`](./RESPONSIBLE_USE.md).

---

# Политика Безопасности

## Как сообщить об уязвимости

Если вы считаете, что нашли проблему безопасности в `CUDA_Mnemonic_Recovery`, пожалуйста, не открывайте публичный issue до первичной проверки.

Отправьте отчёт автору проекта приватно и приложите:

- чёткое описание проблемы
- затронутую версию или commit
- шаги воспроизведения
- ожидаемое влияние
- при необходимости proof-of-concept данные, которые помогают подтвердить проблему

Пожалуйста, не публикуйте детали эксплуатации до тех пор, пока maintainer не получит разумное время на проверку и выпуск исправления или mitigation.

## Что входит в область рассмотрения

Это CUDA-инструмент, сфокусированный на восстановлении. Особенно полезны отчёты по:

- небезопасному парсингу входных файлов
- memory corruption или ошибкам в GPU/host buffer handling
- падениям, вызываемым специально подготовленными входными файлами
- небезопасной обработке вывода
- случайной записи или утечке секретов в логах

## Ожидания по поддержке

Best-effort поддержка даётся для текущей публичной ветки. Более старые снимки или приватные эксперименты могут не получать такой же скорости реакции.

## Напоминание об ответственном использовании

`CUDA_Mnemonic_Recovery` предназначен только для законного восстановления кошельков, backup-фраз и seed-фраз, которые принадлежат вам или на восстановление которых у вас есть явное разрешение.

Я настоятельно не рекомендую использовать это ПО в злонамеренных целях. Полная ответственность за любые незаконные или злоупотребляющие действия лежит исключительно на пользователе.

Краткая пользовательская политика вынесена в [`RESPONSIBLE_USE.md`](./RESPONSIBLE_USE.md).
