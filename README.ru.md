<p align="center">
  <a href="./README.md">English</a> |
  <strong>Русский</strong>
</p>

<p align="center">
  <img src="./docs/media/hero.svg" alt="CUDA_Mnemonic_Recovery hero" width="960">
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-Windows%20%7C%20Linux-0f172a?style=for-the-badge">
  <img alt="CUDA" src="https://img.shields.io/badge/CUDA-ready-0ea5e9?style=for-the-badge">
  <img alt="Focus" src="https://img.shields.io/badge/focus-BIP39%20Recovery-22c55e?style=for-the-badge">
  <img alt="Targets" src="https://img.shields.io/badge/targets-BTC%20%7C%20ETH%20%7C%20SOL%20%7C%20TON-f59e0b?style=for-the-badge">
</p>

# CUDA_Mnemonic_Recovery

Автор: Mikhail Khoroshavin aka "XopMC"

`CUDA_Mnemonic_Recovery` — это специализированный CUDA-инструмент для одной конкретной задачи: восстановление неполных BIP39 mnemonic-фраз с реальной проверкой кандидатов по нужным целям, без лишнего шума и без ощущения “перегруженного комбайна”.

Он рассчитан на практическую работу: реальные wildcard-шаблоны, реальные derivation-path’ы, реальные фильтры, реальные MultiGPU-запуски и вывод, который остаётся удобным даже в длинной сессии восстановления.

## Для Чего Этот Проект

- У вас есть реальная BIP39-фраза, где часть слов потеряна и заменена на `*`.
- Вы хотите проверять кандидатов не вручную, а по реальному `-hash`, Bloom/XOR-фильтрам или CPU verify.
- Вам нужен один recovery flow для Bitcoin, Ethereum, Solana и TON.
- Вам нужна MultiGPU-поддержка, но без хаоса из несвязанных режимов и случайных веток.

## Визуальный Обзор

### Меню Помощи

<p>
  <img src="./docs/media/help-terminal.svg" alt="Скриншот help" width="920">
</p>

### Обычный Recovery Запуск

<p>
  <img src="./docs/media/single-recovery.svg" alt="Скриншот single GPU recovery" width="920">
</p>

### Multi-GPU Recovery

<p>
  <img src="./docs/media/multigpu-recovery.svg" alt="Скриншот multi GPU recovery" width="920">
</p>

### Схема Recovery Pipeline

<p>
  <img src="./docs/media/pipeline-diagram.svg" alt="Схема recovery pipeline" width="920">
</p>

### Схема Multi-GPU Разделения Нагрузки

<p>
  <img src="./docs/media/multigpu-diagram.svg" alt="Схема multi GPU split" width="920">
</p>

## Что Умеет Проект

- Восстанавливать BIP39-фразы с пропущенными словами `*`.
- Использовать встроенные словари BIP39 или внешний `-wordlist FILE`.
- Принимать шаблоны как из командной строки, так и из файлов.
- Проверять кандидатов по `-hash`, Bloom-фильтрам, XOR-фильтрам и optional CPU verify.
- Создавать XOR-фильтры с помощью [XorFilter](https://github.com/XopMC/XorFilter) и сразу использовать их в recovery flow.
- Работать с target-семействами Bitcoin-like, Ethereum, Solana и TON.
- Переопределять тип derivation через `-d_type`, если кошелёк использует не стандартную схему.
- Работать на одной GPU или сразу на нескольких.
- Получать компактный и практичный `Found` вывод, удобный для длинных recovery-сессий.

## Поддерживаемые Target Families

`-c` задаёт, какие именно целевые семейства нужно строить и проверять.

| Буква | Семейство | Что обычно получается |
| --- | --- | --- |
| `c` | Compressed | Bitcoin compressed address / hash160 |
| `u` | Uncompressed | Legacy uncompressed address / hash160 |
| `s` | SegWit | P2SH-wrapped SegWit style output |
| `r` | Taproot | Bech32m taproot output |
| `x` | XPoint | X-only/public point style match |
| `e` | Ethereum | Ethereum address / hash |
| `S` | Solana | Solana public address / raw target |
| `t` | TON | Базовый sweep по TON |
| `T` | TON-all | Расширенный sweep по TON |

Любые другие буквы в `-c` в публичной версии отвергаются.

## Сборка

### Windows через CMake

```powershell
cmake --preset windows-release
cmake --build --preset windows-release --config Release
```

### Windows через Visual Studio

```powershell
msbuild CUDA_Mnemonic_Recovery.sln /p:Configuration=Release /p:Platform=x64
```

### Linux / WSL

```bash
make configure
make build
```

### Локальная сборка только под `sm_89`

```powershell
cmake --preset windows-release -D CMAKE_CUDA_ARCHITECTURES=89
cmake --build --preset windows-release --config Release
```

## Готовые GitHub-Сборки

GitHub Actions подготавливает два дистрибутивных архива:

- `CUDA_Mnemonic_Recovery-windows-builds.zip`
- `CUDA_Mnemonic_Recovery-linux-builds.tar.gz`

Внутри каждого архива лежат такие профили:

| Профиль | Для каких карт | Примечание |
| --- | --- | --- |
| `sm_61-dlto` | GTX 10xx / Pascal | Отдельная сборка для старших Pascal-карт |
| `sm_75-dlto` | RTX 20xx / Turing | Лучший выбор для RTX 20xx |
| `sm_86-dlto` | RTX 30xx / Ampere | Отдельная сборка под Ampere |
| `sm_89-dlto` | RTX 40xx / Ada | Отдельная сборка под Ada |
| `sm_120-dlto` | RTX 50xx / Blackwell | Отдельная сборка под Blackwell |
| `universal-sm_86-sm_120-dlto` | RTX 30xx / 40xx / 50xx | Один бинарник для `sm_86`...`sm_120` |

Release-сборки делаются на CUDA `12.8` с включённым CUDA device link-time optimization (`-dlto`). Это сделано специально: CUDA `12.8` всё ещё покрывает `sm_61`, а универсальная сборка `sm_86-sm_120` остаётся сфокусированной на RTX `30xx`...`50xx`. Для RTX `20xx` остаётся отдельный профиль `sm_75`.

Пакеты подготовлены так, чтобы их было удобно переносить между машинами:

- Windows-сборки используют статический MSVC runtime и статический CUDA runtime.
- Linux-сборки используют статический CUDA runtime и статические `libstdc++` / `libgcc`.
- Совместимый NVIDIA driver на целевой машине всё равно обязателен.

## Быстрый Старт

### Восстановление одного пропущенного слова из командной строки

```bash
CUDA_Mnemonic_Recovery -recovery "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon *" -d examples/derivations/default.txt
```

### Восстановление из файла с шаблонами

```bash
CUDA_Mnemonic_Recovery -recovery -i examples/templates.txt -d examples/derivations/default.txt
```

### Проверка по реальному точному hash target

```bash
CUDA_Mnemonic_Recovery -device 2 -recovery "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon * *" -d examples/derivations/default.txt -c c -hash d986ed01b7a22225a70edbf2ba7cfb63a15cb3aa
```

### Проверка через XOR filter

```bash
CUDA_Mnemonic_Recovery -recovery -i examples/templates.txt -d examples/derivations/default.txt -xc wallet.xor_c -xx wallet.xor_u -c cus
```

### Recovery с passphrase из файла

```bash
CUDA_Mnemonic_Recovery -recovery -i examples/templates.txt -d examples/derivations/default.txt -pass examples/passphrases.txt -c e
```

### Проверка Solana через BTC-style derivation

```bash
CUDA_Mnemonic_Recovery -recovery -i examples/templates.txt -d examples/derivations/default.txt -c S -d_type 1
```

## Форматы Входных Файлов

### Файл шаблонов восстановления

Каждая строка — это один mnemonic-шаблон. Пропущенные слова помечаются как `*`.

Пример: [`examples/templates.txt`](./examples/templates.txt)

```text
abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon *
legal winner thank year wave sausage worth useful legal winner thank *
```

Правила:

- одна фраза на строку
- слова разделяются пробелами
- каждый неизвестный слот — это отдельный `*`
- строка должна выглядеть как обычная mnemonic-фраза, только с заменой неизвестных слов на `*`

### Файл derivation-path’ов

Каждая строка — это один derivation path.

Пример: [`examples/derivations/default.txt`](./examples/derivations/default.txt)

```text
m/44'/0'/0'/0/0
m/49'/0'/0'/0/0
m/84'/0'/0'/0/0
m/86'/0'/0'/0/0
m/44'/60'/0'/0/0
m/44'/501'/0'/0'
m/44'/607'/0'/0/0
```

### Файл passphrase

Каждая строка — это одна passphrase.

Пример: [`examples/passphrases.txt`](./examples/passphrases.txt)

```text
TREZOR
wallet-passphrase-example
```

## Справка По Аргументам

### Источники recovery-входа

| Аргумент | Что делает | Примечание |
| --- | --- | --- |
| `-recovery "..."` | Добавляет один шаблон прямо из CLI | Можно повторять |
| `-recovery -i FILE` | Загружает шаблоны из файла | Можно повторять |
| `-wordlist FILE` | Подменяет встроенный словарь BIP39 | Должен быть корректный 2048-word BIP39 список |
| `-d FILE` | Загружает derivation-path’ы | Обязательный аргумент |

### Цели и тип derivation

| Аргумент | Что делает |
| --- | --- |
| `-c TYPES` | Выбор target families. По умолчанию `cus` |
| `-d_type 1|2|3` | Переопределяет derivation engine: `1=bip32-secp256k1`, `2=slip0010-ed25519`, `3=оба варианта` |

Если `-d_type` не указан, остаётся target-native логика:

- secp-ориентированные цели идут через обычный BIP32/secp256k1
- Solana и TON остаются на своём native ed25519-маршруте

### Filters и direct targets

| Аргумент | Что делает |
| --- | --- |
| `-hash HEX` | Проверка по точному hash / hash prefix |
| `-bf FILE` | Загружает Bloom filter |
| `-xu FILE` | Загружает `.xor_u`, несжатый формат XOR filter |
| `-xc FILE` | Загружает `.xor_c`, компактный GPU-side XOR prefilter |
| `-xuc FILE` | Загружает `.xor_uc`, ещё более компактный GPU-side XOR prefilter |
| `-xh FILE` | Загружает `.xor_hc`, самый компактный GPU-side XOR prefilter |
| `-xx FILE` | CPU verify через несжатый `.xor_u` filter |
| `-xb FILE` | CPU verify через Bloom filter |

## XOR Фильтры И XorFilter

Если вам нужны XOR-фильтры для этого проекта, создавать их лучше через [XorFilter](https://github.com/XopMC/XorFilter).

Рекомендуемая схема:

- `.xor_u` — единственный XOR-формат, который подходит как финальный standalone-вариант без дополнительной CPU-проверки.
- `.xor_c`, `.xor_uc` и `.xor_hc` — это компактные GPU-side prefilter’ы. Они отлично подходят для экономии памяти и ускорения широкого сканирования, но их нельзя считать финальной истиной в полноценной recovery-сессии.
- Для `.xor_c`, `.xor_uc` и `.xor_hc` добавляйте `-xx wallet.xor_u`, чтобы прошедшие кандидаты перепроверялись на CPU по несжатому `.xor_u`.

Практический пример:

```bash
CUDA_Mnemonic_Recovery -recovery -i examples/templates.txt -d examples/derivations/default.txt -xc wallet.xor_c -xx wallet.xor_u -c cus
```

Такой шаблон даёт компактный GPU-фильтр на входе и точную CPU-перепроверку на выходе.

### Runtime и вывод

| Аргумент | Что делает |
| --- | --- |
| `-pbkdf N` | Переопределяет число PBKDF2 итераций. По умолчанию `2048` |
| `-pass VALUE|FILE` | Одна passphrase строкой или файл passphrase |
| `-device LIST` | Выбор одной или нескольких GPU, например `2`, `2,3`, `0-3` |
| `-b N` | Принудительное число CUDA blocks |
| `-t N` | Принудительное число threads per block |
| `-fsize N` | Размер found-buffer |
| `-o FILE` | Файл результатов. По умолчанию `result.txt` |
| `-save` | Переключает последний столбец с raw hash на адресный вывод |
| `-silent` | Не печатать hits в консоль |
| `-h`, `-help` | Показать публичное help-меню |

## Как Работает `-save`

Инструмент сохраняет компактные `Found` строки в плоском формате через `:`.

Без `-save` последний сегмент строки — это raw matched hash/target bytes:

```text
[!] Found: <mnemonic>:<derivation>:<private_key_hex>:COMPRESSED:<matched_hash>
```

С `-save` последний сегмент становится адресно-ориентированным:

```text
[!] Found: <mnemonic>:<derivation>:<private_key_hex>:COMPRESSED:<address>
```

Что остаётся всегда:

- приватный ключ
- путь деривации
- label типа/монеты

Что меняется:

- raw hash заменяется на адресный вывод
- для compressed Bitcoin добавляется дополнительная строка `P2WPKH`

Примеры:

```text
[!] Found: ...:COMPRESSED:1LqBGSKuX5yYUonjxT5qGfpUsXKYYWeabA
[!] Found: ...:P2WPKH:bc1qmxrw6qdh5g3ztfcwm0et5l8mvws4eva24kmp8m
[!] Found: ...:ETH:0x9858effd232b4033e47d90003d41ec34ecaeda94
[!] Found: ...:SOLANA:EHqmfkN89RJ7Y33CXM6uCzhVeuywHoJXZZLszBHHZy7o
```

В mixed-режиме non-default derivation engine помечается рядом с derivation path, а не внутри названия монеты:

```text
[!] Found: ...:(bip32-secp256k1) m/44'/501'/0'/0':<private_key>:SOLANA:<value>
```

## Multi-GPU

Multi-GPU включается через `-device LIST`.

Примеры:

```bash
CUDA_Mnemonic_Recovery -device 2,3 -recovery -i examples/templates.txt -d examples/derivations/default.txt -c c
CUDA_Mnemonic_Recovery -device 0-3 -recovery -i examples/templates.txt -d examples/derivations/default.txt -c cusrxeStT
```

Что делает инструмент в multi-GPU режиме:

- создаёт отдельный recovery slot на каждую выбранную GPU
- делит workload между слотами
- ведёт per-slot статистику
- агрегирует итоговые tested / checksum-valid totals
- сохраняет async save workers до конца выполнения

### Воспроизводимый benchmark fixture

Fixture: [`examples/bench/templates-8x-2missing.txt`](./examples/bench/templates-8x-2missing.txt)

Референсная benchmark-команда:

```bash
CUDA_Mnemonic_Recovery -device 0-3 -recovery -i examples/bench/templates-8x-2missing.txt -d examples/derivations/default.txt -c c -hash d986ed01b7a22225a70edbf2ba7cfb63a15cb3aa -silent
```

Локальный замер на этой машине после фикса multi-GPU totals:

| GPU | Устройства | Нагрузка | Wall-clock |
| --- | --- | --- | --- |
| 1 | `2` | 8 шаблонов, по 2 пропущенных слова, default derivations, exact hash target | `5.42 s` |
| 2 | `2,3` | Та же нагрузка | `4.62 s` |
| 4 | `0,1,2,3` | Та же нагрузка | `4.13 s` |

Что это даёт на этом коротком benchmark:

- `2 GPU`: примерно `1.17x`
- `4 GPU`: примерно `1.31x`

Важная честная оговорка:

- это реальные локальные измерения, а не маркетинговые цифры
- benchmark короткий и заметно платит за инициализацию GPU
- на более длинных и тяжёлых задачах масштабирование может выглядеть иначе

## Troubleshooting

### Инструмент пишет `-d FILE is required`

Это ожидаемо. В публичной документации recovery-запуски всегда предполагают явный файл с derivation-path’ами.

### Я хочу восстанавливать из файла, а не печатать phrase вручную

Используйте:

```bash
CUDA_Mnemonic_Recovery -recovery -i examples/templates.txt -d examples/derivations/default.txt
```

### У моего кошелька необычная derivation-логика

Пробуйте `-d_type`:

- `-d_type 1` — принудительный BIP32/secp256k1
- `-d_type 2` — принудительный SLIP-0010 ed25519
- `-d_type 3` — оба варианта

### С `-save` перестал показываться raw hash

Это нормально. `-save` специально переключает последний сегмент на адресный вывод.

### Можно ли использовать несколько GPU?

Да. Например:

```bash
-device 2,3
-device 0-3
```

## Структура Репозитория

- `src/app/` — entry point, CLI, config
- `src/recovery/` — recovery pipeline и host runtime
- `src/crypto/` — mnemonic, TON, filters, hashes
- `src/cuda/` — CUDA recovery workers и device control
- `include/` — заголовки проекта
- `support/` — общие host utilities
- `third_party/` — bundled crypto и PBKDF2 код
- `assets/wordlists/` — исходные BIP39 wordlists
- `examples/` — готовые примерные входы
- `docs/media/` — визуалы README и social preview assets

## Responsible Use

Проект предназначен только для легитимных сценариев восстановления mnemonic-фраз.

Используйте его только там, где у вас есть законное право восстанавливать соответствующий seed, backup или wallet. См. [`RESPONSIBLE_USE.md`](./RESPONSIBLE_USE.md) и [`SECURITY.md`](./SECURITY.md).
