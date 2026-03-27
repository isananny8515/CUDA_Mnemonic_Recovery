# Release Checklist

## English

- Start from a clean clone or a clean working tree.
- Verify `git status` is empty before packaging.
- Build the intended Windows/Linux profiles.
- Run the local validation suite:
  - `scripts/validate_release.ps1`
  - `scripts/validate_release.sh`
- Confirm README, BENCHMARKS, VALIDATION, and SVG visuals are in sync with the current output format.
- Confirm bundle metadata does not leak low-level implementation details.
- Recompute archive hashes.
- Review release notes before uploading assets.

## Русский

- Начинайте с чистого clone или чистого рабочего дерева.
- Перед упаковкой убедитесь, что `git status` пустой.
- Соберите нужные Windows/Linux профили.
- Прогоните локальный validation suite:
  - `scripts/validate_release.ps1`
  - `scripts/validate_release.sh`
- Убедитесь, что README, BENCHMARKS, VALIDATION и SVG-визуалы синхронизированы с текущим форматом вывода.
- Убедитесь, что bundle metadata не раскрывает низкоуровневые детали реализации.
- Пересчитайте хэши архивов.
- Проверьте release notes перед загрузкой assets.
