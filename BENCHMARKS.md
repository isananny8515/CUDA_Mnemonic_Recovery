<p align="center">
  <a href="#english"><strong>English</strong></a> |
  <a href="#russian"><strong>Русский</strong></a>
</p>

<a id="english"></a>

# BENCHMARKS

This file keeps the benchmark methodology and measured results separate from the landing README.

## Environment

- Hardware: `4x NVIDIA GeForce RTX 4090`
- NVIDIA driver: `591.74`
- Local benchmark build: Windows Release, `sm_89`
- Local CUDA toolchain at measurement time: `13.1`
- Release bundles are packaged separately with CUDA `12.8`
- Power limit during measurement: all four GPUs capped to `50% TDP` with MSI Afterburner
- Measurement rule: end-to-end wall-clock until the first real `[!] Found:` line
- Repeated runs in this document: `1` observed run per configuration

## Primary Fixture

- Mnemonic: `adapt access alert human kiwi rough pottery level soon funny burst divorce`
- Derivations: [`examples/derivations/default.txt`](./examples/derivations/default.txt)
- Target family: `-c c`
- Exact hash target: `1a4603d1ff9121515d02a6fee37c20829ca522b0`
- Benchmark fixture: [`examples/bench/templates-1x-3missing.txt`](./examples/bench/templates-1x-3missing.txt)

Command pattern:

```bash
CUDA_Mnemonic_Recovery -device <LIST> -recovery -i examples/bench/templates-1x-3missing.txt -d examples/derivations/default.txt -c c -hash 1a4603d1ff9121515d02a6fee37c20829ca522b0
```

## Measured Results

| GPUs | Devices | Workload | Wall-clock to first hit | Last live speed before hit |
| --- | --- | --- | --- | --- |
| `1` | `2` | `1 template`, `3 missing words`, exact hash | `550.07 s` | `12.53 M candidates/s` |
| `2` | `0,2` | same | `211.58 s` | `26.87 M candidates/s` |
| `4` | `0,1,2,3` | same | `41.59 s` | `54.15 M candidates/s` |

Derived wall-clock speedup from the same fixture:

- `2 GPU`: about `2.60x`
- `4 GPU`: about `13.23x`

## Stress Case

- Stress fixture: [`examples/bench/templates-1x-4missing.txt`](./examples/bench/templates-1x-4missing.txt)

Command pattern:

```bash
CUDA_Mnemonic_Recovery -device <LIST> -recovery -i examples/bench/templates-1x-4missing.txt -d examples/derivations/default.txt -c c -hash 1a4603d1ff9121515d02a6fee37c20829ca522b0
```

Measured result:

| Scenario | Result |
| --- | --- |
| `1 GPU`, device `2`, `10 minute` limit | no hit within `600.37 s` |
| `4 GPU`, devices `0,1,2,3` | first hit in `15.75 s`, last live speed `56.42 M candidates/s` |

## Notes And Limits

- These numbers describe one real local machine, not a universal guarantee.
- The current table uses one observed run per configuration; future revisions can widen the sample count.
- The primary metric here is **time to first real hit**, not full search exhaustion.
- Because the cards were power-limited to `50% TDP`, absolute throughput at `100% TDP` will be higher.

---

<a id="russian"></a>

# BENCHMARKS

В этом файле benchmark-методика и measured results вынесены отдельно от основного README.

## Окружение

- Железо: `4x NVIDIA GeForce RTX 4090`
- Версия NVIDIA driver: `591.74`
- Локальная benchmark-сборка: Windows Release, `sm_89`
- Локальный CUDA toolchain на момент замеров: `13.1`
- Release bundle’ы пакуются отдельно на CUDA `12.8`
- Ограничение питания во время замеров: все четыре карты были ограничены до `50% TDP` через MSI Afterburner
- Правило измерения: полный wall-clock до первой реальной строки `[!] Found:`
- Число прогонов в этом документе: `1` наблюдаемый запуск на конфигурацию

## Основной Fixture

- Мнемоника: `adapt access alert human kiwi rough pottery level soon funny burst divorce`
- Derivations: [`examples/derivations/default.txt`](./examples/derivations/default.txt)
- Target family: `-c c`
- Exact hash target: `1a4603d1ff9121515d02a6fee37c20829ca522b0`
- Benchmark fixture: [`examples/bench/templates-1x-3missing.txt`](./examples/bench/templates-1x-3missing.txt)

Шаблон команды:

```bash
CUDA_Mnemonic_Recovery -device <LIST> -recovery -i examples/bench/templates-1x-3missing.txt -d examples/derivations/default.txt -c c -hash 1a4603d1ff9121515d02a6fee37c20829ca522b0
```

## Измеренные Результаты

| GPU | Устройства | Нагрузка | Wall-clock до первого hit | Последняя live speed line перед hit |
| --- | --- | --- | --- | --- |
| `1` | `2` | `1 шаблон`, `3 пропущенных слова`, exact hash | `550.07 s` | `12.53 M candidates/s` |
| `2` | `0,2` | то же самое | `211.58 s` | `26.87 M candidates/s` |
| `4` | `0,1,2,3` | то же самое | `41.59 s` | `54.15 M candidates/s` |

Производное ускорение по wall-clock на этом же fixture:

- `2 GPU`: около `2.60x`
- `4 GPU`: около `13.23x`

## Stress-Кейс

- Stress fixture: [`examples/bench/templates-1x-4missing.txt`](./examples/bench/templates-1x-4missing.txt)

Шаблон команды:

```bash
CUDA_Mnemonic_Recovery -device <LIST> -recovery -i examples/bench/templates-1x-4missing.txt -d examples/derivations/default.txt -c c -hash 1a4603d1ff9121515d02a6fee37c20829ca522b0
```

Измеренный результат:

| Сценарий | Результат |
| --- | --- |
| `1 GPU`, устройство `2`, лимит `10 минут` | hit не найден за `600.37 s` |
| `4 GPU`, устройства `0,1,2,3` | первый hit через `15.75 s`, последняя live speed line `56.42 M candidates/s` |

## Примечания И Ограничения

- Эти цифры относятся к одной реальной локальной машине, а не являются универсальной гарантией.
- Текущая таблица использует один наблюдаемый запуск на конфигурацию; в следующих ревизиях выборку можно расширить.
- Основная метрика здесь — **время до первого реального hit**, а не полное исчерпание пространства поиска.
- Поскольку карты были ограничены до `50% TDP`, абсолютная скорость при `100% TDP` будет выше.
