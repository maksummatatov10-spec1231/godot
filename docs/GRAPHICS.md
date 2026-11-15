# Реальные скриншоты в среде агента

## Результат

На 15 ноября 2026 воспроизводимо получены **настоящие кадры viewport Godot 4.7.2**,
а не HTML-макеты и не изображения, нарисованные Python вместо игры:

- [До движения](evidence/lab-cpp.png).
- [После input-action проверки](evidence/lab-cpp-moved.png).

Оба PNG 960×540 открыты и визуально осмотрены агентом. Видны заголовок, читаемый
статус C++ GDExtension, сетка и зелёный игрок. Игрок перемещён с x=480 на x=535.
Автоматически подтверждены цвет объекта и область изменений `(455, 275, 560, 325)`.
Тест использует `Input.action_press`, затем тот же `_physics_process`, затем release;
он не притворяется тестом физической клавиатуры/мыши через ОС.

## Нормальный путь (предпочтителен вне этой песочницы)

Установить актуальные Xvfb, xauth и Mesa из доверенного системного репозитория:

```sh
sudo apt-get update
sudo apt-get install xvfb xauth libgl1-mesa-dri libglx-mesa0
LIBGL_ALWAYS_SOFTWARE=1 .venv/bin/python tools/check.py visual --require-cpp
```

В текущей среде APT-репозиторий недоступен по сети, а пакетного кэша нет.
Поэтому этот стандартный путь здесь не объявляется протестированным.

## Рабочий диагностический fallback

```sh
.venv/bin/python -m pip install -r requirements-dev.txt
.venv/bin/python tools/bootstrap_graphics.py
.venv/bin/python tools/check.py visual --portable-graphics --require-cpp
.venv/bin/python tools/check.py visual --portable-graphics --require-cpp --test-input
.venv/bin/python tools/verify_lab_images.py
```

Требуются Linux x86_64, gcc, gh и стандартная `libz.so.1`. Движок и C++-расширение
уже должны быть подготовлены; для C++: `.venv/bin/python tools/build_cpp.py`.

Схема:

1. Локальный Xvfb обеспечивает Godot объект X11 display/window без физического экрана.
2. ANGLE предоставляет OpenGL ES 3.1 поверх программного Vulkan SwiftShader.
3. У взятой serverless-сборки ANGLE нет настоящей X11 window surface. Поэтому
   `tools/graphics/egl_pbuffer.c` адаптирует запросы X11 EGL к реальной EGL pbuffer
   поверхности 960×540: выбирает pbuffer config, создаёт pbuffer, предоставляет
   визуальный ID локального X-сервера. Соответствующие EGL platform entry points
   и extension strings отражают **адаптированный**, а не аппаратный X11 backend.
4. Сам Godot выполняет шейдеры и рисует сцену. После `RenderingServer.frame_post_draw`
   GDScript читает texture корневого viewport и сохраняет PNG.
5. Python проверяет файл. Затем агент использует инструмент чтения изображения,
   чтобы **действительно увидеть пиксели**, а `present_file` — показать результат пользователю.

Это намеренно **offscreen render test**, не desktop-screenshot окна X11, и не
тест swapchain/compositor. Ничего из этого не маскируется как обычный Mesa-драйвер.
Адаптер не влияет на код игры или её экспорт: он подключается через окружение
только при явном флаге `--portable-graphics`.

## Источники, изоляция и безопасность

Все URL/ревизии и SHA-256 находятся в `tools/graphics/sources.json`:

- Xvfb — старый Chromium tools snapshot из GitHub mirror.
- Некоторые X11 и совместимые библиотеки — архивные Debian sysroot и Porteus
  snapshots, сохранённые в сторонних GitHub-репозиториях.
- libfontenc собирается из исходников, опубликованных Sailfish OS; zlib — только
  заголовки upstream, линковка с имеющейся системной libz.
- EGL headers — Khronos EGL Registry.
- ANGLE/SwiftShader — пакет `@sparticuz/chromium@131.0.1` из npm, проверенный по
  npm integrity при первоначальном получении и по закреплённому SHA-256 в bootstrap.

**Это не полностью современный, независимо аудированный graphics stack.**
Хеши защищают от изменения закреплённых файлов, но сами по себе не доказывают
безопасность сторонних бинарных snapshot. Используем их только для собственной
доверенной тестовой сцены в одноразовой песочнице. Не использовать этот fallback
как production runtime, не подключать к нему внешние X11-клиенты, неизвестные
плагины, недоверенные шрифты или контент. На полноценном хосте заменить его актуальными
дистрибутивными Xvfb/Mesa.

Библиотеки устанавливаются **только в `.tools/graphics/portable/`**, не в `/usr/lib`.
Нужен один оговорённый временный системный путь: у старого Xvfb зашит
`/usr/bin/xkbcomp`. Если этого файла нет, context manager создаёт точный symlink
на локальный compiler через `sudo -n`, а в `finally` удаляет **только созданную им
ссылку**, проверяя её target. Существующий системный файл не заменяется.
В этой песочнице это проверено; без разрешения на такую ссылку нужен системный xkbcomp.

X-сервер живёт только во время проверки, не слушает TCP (`-nolisten tcp`),
использует локальный UNIX socket и останавливается в `finally`, включая ошибку теста.
Локальный `-ac` допустим только в этой изолированной среде, не на общем хосте.
`LD_LIBRARY_PATH` и ANGLE-переменные передаются дочерним процессам, не меняя глобальную
настройку системы. Импорт и headless smoke не требуют графического fallback.

Архивы, библиотеки, компиляторы и кэши игнорируются Git. В Git оставлены лишь
небольшие исходники инструментов, manifest и два PNG как запрошенное доказательство.
Лицензии сторонних исходников сохраняются в скачанных source directories.

## Ограничения визуальной проверки

- Только фиксированные 960×540 и Compatibility/GLES в текущем адаптере.
- Нет проверки HDR, реального GPU, Vulkan renderer Godot/Forward+, fullscreen,
  multi-window, resize, display scale, compositing, аудио или целевой платформы.
- В логах есть ожидаемые сообщения об отсутствии XINERAMA/RANDR и D-Bus.
  Это реальные ограничения старого виртуального окружения, не скрытые ошибки.
  В успешных прогонах нет `ERROR:` / `SCRIPT ERROR:`; exit code 0 и маркеры
  `NATIVE_OK`, `CAPTURE_OK`, `SMOKE_OK` присутствуют.
- Screenshot quality не доказывает отсутствие ошибок игровой логики. Для настоящей
  игры добавляем сценарии, состояние, дополнительные кадры и тесты на целевом железе.
- `verify_lab_images.py` — проверка **именно стенда**, не универсальный оценщик картинки.
