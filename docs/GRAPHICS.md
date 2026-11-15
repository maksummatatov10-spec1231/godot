# Реальные скриншоты в среде агента

## Новый результат: Forward+ и окно редактора (2026-11-15)

Захват и просмотр **проверены на практике**, не только найдены в документации.
В GitHub Actions Ubuntu 24.04 используется Xvfb + системный Mesa Lavapipe:
Godot сообщает Vulkan 1.4.318, Forward+, llvmpipe LLVM 20.1.2. Это CPU Vulkan,
**не тест FPS/быстродействия видеокарты**. Локальный SwiftShader по-прежнему
не предоставляет нужную X11 surface; это ограничение обошли удалённым runner.

Открыты и визуально просмотрены:

- [Реальный Forward+ кадр стенда](evidence/forward-plus/lab.png).
- [Небо, солнце и контрольный 3D-объект без плагина облаков](evidence/forward-plus/sky-only.png).
- [Те же объекты с SunshineClouds2](evidence/forward-plus/clouds-only.png).
- [Terrain3D отдельно](evidence/forward-plus/terrain-only.png) и
  [Terrain3D вместе с облаками](evidence/forward-plus/terrain-clouds.png).
- [Окно Godot с включёнными плагинами](evidence/forward-plus/editor.png).

Снимок окна редактора — именно X11 framebuffer через `PIL.ImageGrab`, не
изображение game viewport. Видны Scene/FileSystem/Inspector и Terrain3D dock.
Поскольку `lab.gd` строит сцену только при запуске, в редакторе виден её корневой
узел, а не игровой lab. Есть ступенчатые артефакты сетки viewport на software
renderer; этот снимок не принимается за доказательство идеальной 3D-картинки.
Прежний кадр с диалогом reimport был отвергнут; версия include синхронизирована
с Godot 4.7, и новый editor log не содержит прежнего краша.

В облачном шейдере найдено неопределённое поведение: `smoothstep` с одинаковыми
границами, потенциальное деление на ноль в интеграции атмосферы. Добавлены
определённый `step`, защита знаменателя и отключение атмосферного прохода при
нулевой плотности. **После изменения небо перестало быть чёрным**, центральный
объект сохраняется. Облака пока пересвечены/мягкие при четверти разрешения;
это функциональный диагностический кадр, не финальный художественный результат.
Закрытие cloud fixture теперь освобождает RD до завершения RenderingServer;
в текущем clouds-only log нет прежних RID leak warnings.

**Terrain3D:** прежние default/lightweight/minimum шейдеры воспроизводили signal 11.
В примерах найдены незащищённые uniform-array индексы и чтение array textures
с layer=-1 для отсутствующих регионов. Созданы MIT derivatives в
`godot/shaders/` с проверкой границ; fixture ограничен тремя mesh LODs.
С bounded minimum вариантом **первый полный прогон стал зелёным**:
[43732396266](https://github.com/maksummatatov10-spec1231/godot/actions/runs/43732396266),
source `16211a8d0886c1beba03d5f014558f9d336c9607`.
Реально открыты кадры земли с тенью контрольного объекта, отдельно и вместе
с облаками. Это настоящий Terrain3D clipmap, не подставная плоскость MeshInstance.
Проверки bounds и mesh LODs менялись вместе, поэтому единственная причина
старого краша **не доказана отдельным bisect**; старый backtrace оставлен для
исторической диагностики, а не как ошибка последнего успешного кадра.

Лёгкий профиль не доказывает работу всех опций полного vendor shader или всех
сетевых функций Assets2Godot. Последние статусы и точный source commit находятся
в [result.json](evidence/forward-plus/result.json). `passed` отдельного capture
означает техническую проверку процесса/PNG/log, не автоматическую художественную
приёмку. Дополнительный image regression сравнивает небо/облака: сохраняется
центральный объект, нет чёрного фона, есть видимый вклад облаков.

### Воспроизведение и просмотр

В `.github/workflows/validate.yml` запуск `workflow_dispatch` на рабочей ветке
создаёт screenshots/logs и публикует их в **ту же ветку**, даже при падении.
Весь workflow остаётся красным, если хотя бы одна обязательная проверка не прошла.

```sh
sudo apt-get update
sudo apt-get install -y xvfb xauth mesa-vulkan-drivers libvulkan1 gdb
pip install -r requirements-dev.txt
export GODOT4_BIN=/absolute/path/to/Godot_v4.7.2-stable_linux.x86_64
export VK_ICD_FILENAMES=$(find /usr/share/vulkan/icd.d -name '*lvp*json' -print -quit)
export LIBGL_ALWAYS_SOFTWARE=1 LP_NUM_THREADS=1 LP_NATIVE_VECTOR_WIDTH=128
python tools/capture_rendering.py --output artifacts/forward-plus
# Даже после ненулевого exit диагностические PNG/log остаются в output.
python tools/verify_cloud_images.py --directory artifacts/forward-plus
# Отдельный настоящий снимок редактора:
xvfb-run -a -s '-screen 0 1280x800x24' python tools/capture_editor.py \
  --output artifacts/editor.png
```

Игровой capture ждёт `RenderingServer.frame_post_draw`, затем вызывает
`get_viewport().get_texture().get_image().save_png(...)`. Runner проверяет
фактическую строку Forward+ device, код выхода, ошибки и свежесть/размер PNG.
Editor capture проверяет, что процесс ещё жив, и отвергает fatal/script errors.
После этого агент **открывает PNG инструментом просмотра изображений**; наличие
файла без просмотра не считается визуальной проверкой.

Бинарная сборка Lavapipe 26.3 из `rokuz/lavapipe-binaries` тоже исследована с
проверкой SHA-256, но отвергнута: ей нужны более новые glibc/LLVM22, чем на runner.
Она не была молча объявлена рабочей; `vulkan-runtime.log` сохраняет диагностику.

Источники реализации:
[официальный Viewport API](https://docs.godotengine.org/en/stable/classes/class_viewport.html),
[пример screen capture Godot](https://github.com/godotengine/godot-demo-projects/blob/master/viewport/screen_capture/screen_capture.gd).

---

## Исторические C++/Compatibility проверки


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
