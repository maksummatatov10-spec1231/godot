# Техническая памятка — проверено 15 ноября 2026

## Источники и стратегия версий

Основой служат официальные, версионированные документы, а не случайный пример из поиска:

1. [Godot 4.7: новые возможности](https://godotengine.org/releases/4.7/).
2. [Полная миграция 4.6 → 4.7](https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html).
3. [Godot 4.7.1, 14 июля](https://godotengine.org/article/maintenance-release-godot-4-7-1/).
4. [Godot 4.7.2, 18 августа](https://godotengine.org/article/maintenance-release-godot-4-7-2/).
5. [Последний stable в GitHub API](https://api.github.com/repos/godotengine/godot/releases/latest).
6. [godot-rust: установка](https://godot-rust.github.io/book/intro/setup.html),
   [первое расширение](https://godot-rust.github.io/book/intro/hello-world.html),
   [совместимость](https://godot-rust.github.io/book/toolchain/compatibility.html).
7. [gdext 0.5.5: полный changelog](https://github.com/godot-rust/gdext/blob/v0.5.5/Changelog.md),
   [MSRV / Rust edition](https://github.com/godot-rust/gdext/blob/v0.5.5/Cargo.toml),
   [доступные API features](https://github.com/godot-rust/gdext/blob/v0.5.5/godot/Cargo.toml).
8. [Godot CLI](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html),
   [Viewport.get_texture](https://docs.godotengine.org/en/4.7/classes/class_viewport.html#class-viewport-method-get-texture),
   [RenderingServer.frame_post_draw](https://docs.godotengine.org/en/4.7/classes/class_renderingserver.html#class-renderingserver-signal-frame-post-draw).

На дату проверки официальный API отдаёт **4.7.2-stable**, а gdext — **v0.5.5**.
4.8 beta не используем как production-базу. Это снимок состояния, не обещание,
что будущих обновлений не будет. Перед обновлением повторяем запросы latest,
читаем release notes, миграцию, changelog и known issues именно затронутых подсистем.
Не переключаем проект на beta автоматически.

## Что важно для кода в 4.7

Из официального руководства миграции (полная таблица — источник №2):

| Область | Изменение / правило |
|---|---|
| GDScript | Override метода с типизированным возвратом наследует этот тип; нужен явный возврат подходящего значения. `return null` применим только там, где он допустим по типу. |
| Packed arrays | Изменение элемента больше не вызывает setter всего свойства. Уведомления/инвалидацию делаем явно. |
| Ввод | Mouse/keyboard device ID больше не `0`; проверяем тип события либо `DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD`. |
| UI | `RichTextLabel.UPDATE_WIDTH_IN_PERCENT` заменён на `UPDATE_WIDTH_UNIT`; параметры изображений используют единицы. Проверяем вызовы по API 4.7. |
| Рисование | Линии CanvasItem не получают прежнюю добавочную толщину antialias feather. Проверяем визуально, задаём толщину явно. |
| AnimationTree | BlendSpace1D/2D: вместо boolean `sync` — `SyncMode`. Проверяем переходы. |
| Jolt 3D | Изменился знак `WorldBoundaryShape3D.plane.d`; масса/жёсткость SoftBody и пересечения Area3D/SoftBody требуют перепроверки. Не переносим старые численные настройки вслепую. |
| Звук | `AudioStreamPlayer.area_mask` по умолчанию теперь 0. Для Area bus override задаём маску явно; `AudioEffectSpectrumAnalyzer.tap_back_pos` удалено. |
| Нативная физика | У `_body_set_shape_as_one_way_collision` новый обязательный `direction`; старые реализации расширений надо адаптировать. |
| Editor / XR | Изменились сигнатуры `_commit(amend)` и `_on_register_metadata(interaction_profile_metadata)`; плагины проверяем отдельно. |
| Платформы | Минимальная macOS — 11. Для новых проектов stretch defaults изменены; в стенде они заданы явно. |

В 4.7 также добавлены Control offset transforms для анимации внутри контейнеров,
inline shader previews, AreaLight3D, HDR output, Scene Paint/Asset Store и Android GABE.
Наличие функции в релизе не означает, что она доступна на каждом renderer/устройстве.
Стенд использует Compatibility ради доступности программного рендера, а не для
проверки HDR/Forward+/XR. Выбор renderer для игры примем после определения её задач.

### Исправления maintenance-релизов, влияющие на проверки

- **4.7.1:** исправлены добавление navigation agents после pause/resume,
  TLS double-destruction, чтение shader variants, тени ортографической камеры,
  освещение при non-uniform scale, предыдущие transform и Android soft-keyboard.
- **4.7.2:** исправлены регистрации родителей классов GDExtension, работа
  main thread, репликация после удаления MultiplayerSpawner node, high-polling mouse
  на Windows, отпускание Shift, источник энтропии mbedTLS и некоторые ошибки теней.
- В `RandomPCG::rand_weighted` запрещены отрицательные веса: входные веса валидируем.
- Объявлено отсутствие известных несовместимостей между maintenance-релизами,
  но это не заменяет тестирование игры и резервную копию.

Это обзор изменений, значимых для будущего кода, **не утверждение, что каждый фикс
всего движка протестирован**. Полные списки доступны из источников №3–4.
Предложения в godot-proposals не считаем уже выпущенными возможностями:
например, обсуждение переработки GDScript само по себе не отменяет `preload()`.

## C++: рабочая нативная альтернатива Rust

По просьбе пользователя основным проверенным нативным путём теперь стал **C++**.
Компилятор GCC/G++ 12.2 уже был установлен; скачаны официальные bindings
**godot-cpp 10.0.0-stable**, commit `507ed9d840c01a3c5b2a39af8bb4000bfac30bf5`,
с явным `api_version=4.7`. godot-cpp 10 имеет собственную нумерацию, поэтому
нельзя просто искать ветку `4.7`: используем версионирование из
[официального README](https://github.com/godotengine/godot-cpp/blob/10.0.0-stable/README.md).
[Официальное введение в C++](https://docs.godotengine.org/en/4.7/tutorials/scripting/cpp/gdextension_cpp_example.html).

`tools/build_cpp.py` проверяет SHA-256 исходного архива, собирает release-библиотеку
и только после успешной сборки включает расширение внутри `res://native_cpp/`.
Проверены загрузка и вызовы `CppProbe.add` из GDScript, включая границы int32.
Профиль bindings пока включает только RefCounted и OS: при добавлении новых engine
классов нужно расширять `cpp/build_profile.json`.

C++ и Rust способны давать сопоставимую нативную производительность, но точного
равенства для произвольных алгоритмов не обещаем. Benchmark Rust здесь не проводился.
C++ не даёт Rust borrow checker: обязательны RAII, проверка lifetime, отсутствие UB,
профилирование, позднее sanitizers и нагрузочные тесты реальных алгоритмов.
Сейчас C++-сборка проверена только для Linux x86_64, экспорт на другие ОС не настроен.

## Rust: необязательный сохранённый пример

- Сцены/UI/быстрая итерация — GDScript; Rust — изолированные алгоритмы,
  симуляция или измеренные узкие места. Не переносим всё в Rust ради самого Rust.
- `cdylib` + crate `godot = =0.5.5`, feature `api-4-7`, entry symbol
  `gdext_rust_init`, compatibility_minimum `4.7`. Нужен обычный Godot Standard;
  .NET нужен для C#, а не для Rust.
- Rust bindings — отдельный community-проект, не встроенный язык Godot.
  У gdext возможны breaking changes между minor-версиями: старые примеры 0.4
  не считаем совместимыми с 0.5. В 0.5 изменились non-null object APIs,
  typed dictionaries и базовая API-версия; в 0.5.4 добавлен `api-4-7`.
- 0.5.3 убрал обычную необходимость LLVM/bindgen; для стандартного `api-4-7`
  не ставим LLVM без причины. Custom API/двойная точность — отдельная конфигурация.
- 0.5.5 добавляет async virtual functions, улучшает refcounts/cache singletons,
  исправляет async shutdown/освобождение объектов и panics. Не копируем устаревшие
  обходные решения и не включаем экспериментальные features без необходимости.
- Не держим `bind()/bind_mut()` guard через обратный вызов в Godot, который
  может повторно обратиться к тому же объекту: риск reentrant borrow panic.
- SceneTree и вызовы engine API — на главном потоке. В фон выносим только
  независимые данные/алгоритмы, результат передаём обратно явно.
- Не предполагаем, что `Gd<Node>` делает вручную освобождаемый Node бессмертным;
  учитываем `queue_free`, deferred calls и завершение асинхронных задач.
- `unsafe` ограничиваем обязательной декларацией ExtensionLibrary;
  не используем ручные engine pointers/FFI без необходимости.
- Для каждой целевой ОС/архитектуры нужна своя библиотека и экспортная проверка.
  Web/WASM в gdext отмечен experimental; работоспособность desktop-библиотеки
  **не означает**, что браузерная сборка заработает. Мобильные SDK, подписи,
  WASM, консоли и кросс-компиляция пока не настроены.

## Скриншоты в среде без экрана

1. `--headless` годится для импорта/логики, но не для проверки отрисованной игры.
2. На обычном хосте: Xvfb (виртуальный X11) + Mesa software OpenGL +
   `gl_compatibility`. В этой ограниченной среде реально заработал отдельный
   Xvfb + ANGLE/SwiftShader pbuffer-путь: [устройство и ограничения](GRAPHICS.md).
   Ни в одном визуальном запуске не передаём `--headless`.
3. После `await RenderingServer.frame_post_draw` берём
   `get_viewport().get_texture().get_image()` и сохраняем PNG.
4. Тест ограничен 120 секундами; ошибки Godot в stderr/stdout считаем провалом
   даже при exit code 0. Требуем маркеры завершения и новый, не старый PNG.
5. Проверяем размер/формат/непустоту, затем открываем PNG инструментом просмотра.
   Синтетический PNG из unit-теста не выдаём за кадр игры.
6. После появления реальной игры добавляем воспроизводимые сценарии ввода,
   фиксированный seed, checkpoint состояния, несколько разрешений и UI scale,
   screenshot baseline с допуском. Не полагаемся на один кадр стартового экрана.

Xvfb/llvmpipe не проверяет реальную скорость GPU, HDR-монитор, аппаратные особенности,
контроллеры, touch, качество аудио и поведение Windows/macOS. Эти проверки — на целевых
устройствах. Тайм-ауты не дают сбойному тесту бесконечно висеть.

## Когда придут ассеты / задача игры

- Инвентаризация: форматы, размеры, лицензии, прозрачность, pivot, tilesets,
  FPS/направления спрайтов, масштаб моделей, UV, кости/анимации, аудиопетли.
- Импорт в отдельной сцене: не перезаписываем оригиналы; смотрим filters,
  mipmaps, compression, sRGB/normal maps, collision masks и draw order.
- Затем vertical slice: реальный игровой цикл, а не только красивая сцена.
- На каждый шаг: import → код/типизация → unit/smoke → реальный запуск →
  сценарий ввода → скриншоты и просмотр → profiler → экспорт на целевую платформу.
- Матрица по мере появления функционала: коллизии/физика, pause/resume,
  сохранения, анимации, звук, UI/локализация, native lifetimes, повторная загрузка,
  long-run/memory, networking только если он нужен игре.
