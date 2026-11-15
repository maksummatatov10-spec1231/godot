# Проверено в среде агента — 15 ноября 2026

## Итог

**Реальные скриншоты получены и просмотрены. C++-альтернатива Rust собрана,
подключена к Godot и проверена вызовами из GDScript.**

| Проверка | Фактический результат |
|---|---|
| Godot `--version` | `4.7.2.stable.official.ed1daf0bf` |
| SHA-256 ZIP против официального GitHub release digest | Совпал |
| Импорт проекта | Успех |
| C++ release build, GCC/G++ 12.2, SCons 4.10.1 | Успех; `libgame_cpp.so` |
| godot-cpp | `10.0.0-stable`, commit `507ed9d840c01a3c5b2a39af8bb4000bfac30bf5`, API 4.7 |
| Вызов GDScript → C++ | `NATIVE_OK CppProbe`, обычное сложение и положительная/отрицательная границы int32 |
| Headless smoke с C++ и Input action | `INPUT_OK`, `SMOKE_OK`, exit 0 |
| Визуальный запуск через portable backend | `NATIVE_OK`, `CAPTURE_OK`, `SMOKE_OK`, exit 0 |
| Второй визуальный запуск после движения | Также exit 0; игрок x=480 → x=535 |
| Проверка PNG | Два непустых PNG 960×540, зелёный объект в ожидаемых координатах |
| Проверка различий | `VISUAL_STATE_OK`, изменился прямоугольник `(455, 275, 560, 325)` |
| Ручной просмотр агентом | PNG действительно открыты через image-reading tool, осмотрены текст/сетка/объект |
| Отказ visual с обязательным отсутствующим Rust | Ожидаемый exit 1, не ложный PASS |
| Cleanup после этого отказа | Xvfb остановлен, временная ссылка xkbcomp удалена |
| Unit-тесты инструментов | **23 прошли** |
| GDScript lint / format | Успех |
| Python compileall, YAML/TOML parsing, git diff check | Успех |

Сохранённые кадры: [до движения](evidence/lab-cpp.png),
[после движения](evidence/lab-cpp-moved.png).
Это именно кадры Godot, не синтетические картинки unit-тестов.
Сценарий ввода проверяет `Input.action_press` и игровой `_physics_process`,
а не физические клавиши ОС.

## Важная найденная проблема первого импорта

При первом обнаружении новой C++ GDExtension на пустом `.godot` наблюдался
**SIGABRT (exit -6)** в конце импорта без явного сообщения об ошибке. Это не было
принято за успех. После следующего импорта запуск проходил, но автоматическое
игнорирование/повторение любого сбоя было бы плохой проверкой.

Вместо этого `tools/project_setup.py` заранее формирует штатный сгенерированный
`.godot/extension_list.cfg` по реально включённым `.gdextension`, до старта редактора.
Расширение загружается при запуске, не при позднем обнаружении импортёром.
Три свежих импорта с таким списком завершились exit 0; обычные повторные smoke и
visual также проходят. Runner не подавляет ненулевые коды и не повторяет ошибки молча.
Корневая причина abort в upstream не установлена; workaround ограничен этим проектом.
Список обновляется также после C++-сборки, остаётся импорт-кэшем и не хранится в Git.

## Реальный графический backend

В успешном логе:

```text
OpenGL ES 3.1.0 (ANGLE 2.1.24077 git hash: 367e9e74a865)
Compatibility / SwiftShader Device (Subzero)
NATIVE_OK CppProbe (normal + int32 boundaries)
CAPTURE_OK .../artifacts/lab.png
SMOKE_OK
```

На Linux нет физического дисплея и GPU runtime; APT-репозиторий недоступен.
Заработал отдельный диагностический **Xvfb + ANGLE/SwiftShader + EGL pbuffer** путь.
Он действительно рендерит viewport игры, но не проверяет оконный compositor,
монитор или скорость видеокарты. В логах остаются ожидаемые сообщения об отсутствии
RANDR/XINERAMA/D-Bus. Ошибок Godot `ERROR:` / `SCRIPT ERROR:` в успешном прогоне нет.

**Стек содержит архивные сторонние X11-библиотеки и не предназначен для production
или недоверенного контента.** Все ревизии/хеши закреплены; библиотеки изолированы в
`.tools/`, TCP X11 отключён. Детали и оговорённая временная системная ссылка:
[GRAPHICS.md](GRAPHICS.md). Стандартный современный Xvfb/Mesa путь оставлен для CI
и обычного хоста, но в этой песочнице он не был доступен.

## Воспроизведение

```sh
.venv/bin/python tools/build_cpp.py
.venv/bin/python tools/check.py smoke --require-cpp --test-input
.venv/bin/python tools/bootstrap_graphics.py
.venv/bin/python tools/check.py visual --portable-graphics --require-cpp
.venv/bin/python tools/check.py visual --portable-graphics --require-cpp --test-input
.venv/bin/python tools/verify_lab_images.py
```

Сборка и bootstrap с загрузкой закреплённых зависимостей тоже выполнены, а не
оставлены только как текст инструкции. После команд не остаётся фонового Xvfb.
Логи текущих прогонов в `artifacts/`; они перезаписываются и не являются Git-артефактами.

## Источник движка

Получен через Google Drive connector из файла `1KLqDuUak9tt2u5tGsr_ZETMKYCJ9epOB`:
`Godot_v4.7.2-stable_linux.x86_64.zip`, **77 860 424 байта**.

```text
SHA-256: cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4
```

Сверен с `digest` официального asset в
[GitHub API](https://api.github.com/repos/godotengine/godot/releases/tags/4.7.2-stable).
Сам executable, ZIP и SDK не добавлялись в Git. При переносе checkout без `.tools/`
их нужно подготовить заново.

## Что по-прежнему не утверждается

- Rust/Cargo не установлены; Rust-пример сохранён необязательным, не собран,
  Cargo.lock не сгенерирован. Для проверенного C++ пути Rust не нужен.
- Нет benchmark-сравнения C++ и Rust. Проверка суммы — тест интеграции и типов,
  не доказательство одинаковой производительности или безопасности памяти.
- GitHub Actions workflow подготовлен/обновлён, но здесь не запускался.
- Не проверены Windows/macOS, export templates/экспорт, мобильные платформы,
  Web, XR/HDR/Forward+, реальный GPU, аудио, сеть и аппаратный ввод.
- Не проведено исчерпывающее тестирование всего движка или будущей игры;
  её ассеты и требования ещё не получены.

## Дополнение: ассеты, плагины и Forward+ (2026-11-15)

Текущий профиль изменён на Forward+; прежние PNG остаются свидетельством
Compatibility, а не нового renderer. Архивы уже получены и проанализированы;
старое замечание выше о неполученных ассетах историческое.

- 36 Python tests, project smoke, editor import/reopen — PASS.
- Terrain3D native registration/instantiation, parse плагинов и 7 SPIR-V artifacts — PASS.
- Устранены exit leaks Sunshine/A2G; остались editor-only EXR brush warnings Terrain3D.
- Реальный Vulkan frame попытались получить: `VK_KHR_xlib_surface` отсутствует.
  Forward+ визуально не подтверждён, FPS не измерен. Headless-успех не выдаётся за GPU-тест.
- [Подробности и команды](plugins/README.md), [логи и машинный отчёт](evidence/plugins/validation.json).
- Архивы/Blender вне репозитория, [результаты аудита](ASSET_INTAKE.md).
