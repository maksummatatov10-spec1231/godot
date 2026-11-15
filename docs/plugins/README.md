# Forward+ и три плагина

Обновлено 2026-11-15. Исходники установлены в `godot/addons/`, все три
плагина включены в `project.godot`. Стенд ещё не является готовой игрой.

## Рендерер и производительность

Выбран **Forward+** (`forward_plus`) — desktop-профиль с RenderingDevice,
нужный для полного набора современных 3D-возможностей и облаков-композитора.
Vulkan используется на Linux; конкретный поддерживаемый API на Windows/macOS
выбирается под устройство (D3D12/Vulkan/Metal), а не навязывается всем платформам.

Это **не универсально самый быстрый рендерер**. Mobile обычно выгоднее для
простых сцен/мобильных GPU, Compatibility — для слабых и старых устройств, но
Compatibility не предоставляет compute/compositor-путь SunshineClouds2.
Целевая конфигурация здесь — desktop с поддержкой RenderingDevice. Web и старые
видеокарты не входят в профиль «все эффекты работают».

- Автоматический fallback в OpenGL отключён: нельзя молча потерять облака.
- MSAA и TAA изначально выключены, используется более дешёвый FXAA.
- Масштаб 3D = 1.0: не размываем всю сцену до измерений.
- `res://resources/clouds_balanced.tres`: четверть ширины/высоты (1/16 пикселей
  облачного прохода), 64 view-шага, 8 lighting-шагов. Это стартовый бюджет,
  **не замер FPS и не гарантия качества**. На целевой GPU сравнить с half-resolution.
- Нет включённых наугад SSAO/SSIL/SSR/SDFGI или тяжёлых теней во всей игре.
  Их стоимость оценивается на настоящих игровых сценах.

## Что установлено

| Плагин | Назначение и версия | Статус |
|---|---|---|
| Terrain3D | Нативный clipmap-ландшафт, 1.1.0, минимум Godot 4.5 | GDExtension загружается, классы зарегистрированы, экземпляр создаётся; editor plugin включён |
| SunshineClouds2 | Объёмные procedural clouds через CompositorEffect; архив `2-6`, plugin.cfg сообщает 2.7 | GDScript-вариант установлен; официальный фикс Godot 4.7 и потоковых массивов включён; 7 шейдеров скомпилированы |
| Assets2Godot | Менеджер ассетов, 0.8.2 `nobin` | Редакторский интерфейс включён, исправлены утечки; сетевые провайдеры/демон явно отключены в sandbox |

### Terrain3D

Установлены исходники редакторских инструментов, кисти, шейдеры и платформенные
бинарники Linux/Windows/Android/iOS/Web. macOS framework в текущем Git checkout
отсутствуют — установка на macOS не заявлена готовой. Фактически проверен
Linux x86_64; наличие DLL/dylib/wasm не означает тест на этих платформах.
Демо и игровые текстуры из внешнего архива не импортированы в игру.

Чтобы создать игровой terrain: добавить `Terrain3D`, назначить отдельную
папку Data Directory, сохранить ресурсы Material/Assets и добавить region.
На native Terrain3D не следует навешивать обычный GDScript как замену его
встроенному классу. При обновлении addon заменять целиком, не накладывать версии.
Compatibility поддерживается Terrain3D, но этого недостаточно для облаков.

### SunshineClouds2

Исходная сборка использовала private camera UBO, изменившийся в Godot 4.7.
Применено официальное upstream-состояние на commit
`a73a80b08fb37b255f8f10d49debd71e5541bd70`, включая исправления camera layout и
передачи массивов света на render thread. Точные blob/hash — в manifest.

Дополнительно устранено создание `EditorPlugin.new()` без освобождения в
`FindSceneNode`: используется singleton EditorInterface. Сохранены специальные
`.import`-настройки 3D noise-текстур и include `SunshineCloudsDisplay.rast` — без
них копирование addon не является корректной установкой. У внешних scene/resource
UID убраны ссылки на cache автора; явные `res://` пути сохранены.

Установлен GDScript-вариант для Godot Standard, без требования .NET. C#-дубли,
IDE-мусор и старые demo-ресурсы с отсутствующими файлами корневого проекта не
скопированы. Это не удаление исходных файлов из внешней библиотеки.

Для сцены нужны WorldEnvironment с Environment и Compositor, cloud resource,
SunshineCloudsDriverGD и tracked DirectionalLight3D. Подготовлен реальный GPU-стенд
`res://scenes/rendering_validation.tscn` с Terrain3D и balanced clouds. Он не является
главной сценой игры. Clouds-only реально отрендерен через Vulkan Forward+
на software Lavapipe и просмотрен; Terrain3D с bounded minimum материалом
также отрендерен отдельно и вместе с облаками без краша. На аппаратной
GPU ещё не проверен. Подробные снимки и ограничения: [GRAPHICS.md](../GRAPHICS.md).

### Assets2Godot: честное ограничение `nobin`

Это редакторский инструмент, не runtime-рендерер. Исходники под GPLv2, лицензия
не распространяется автоматически на импортируемые данные: у ассетов свои условия.
Поставленный архив **не содержит `bk_client`**. BlendKit и локальный индекс
Sources требуют helper; провайдеры Poly Haven/ambientCG имеют GDScript API,
но их внешние хосты недоступны из этого sandbox.

`assets2godot/offline_mode=true` исключает бессмысленные фоновые запросы,
скачивание/автозапуск helper. Работают включение интерфейса и локальные
Project/Open scene поверхности; **поиск удалённых каталогов, скачивание и
сканирование внешних Sources не заявлены работающими**.

На машине с полноценной сетью: установить соответствующий helper через штатный
механизм плагина (проверяя pinned manifest), отключить offline_mode и включить
Client/нужных провайдеров в Editor Settings. Не хранить токены в `project.godot`.
Самовольно скачивать и запускать неизвестный executable здесь не стали.

Исправлено: повторное включение клиента из settings_changed обходило offline flag;
ambientCG запрашивал категории даже при скрытой вкладке; отсутствующий font
`main_bold` в Godot 4.7; неприкреплённые status-узлы; цикл Array → lambda → Array
и неотключённый node_added hook. Теперь полный editor smoke завершается без
ERROR и без сообщений об утечках. Ограниченные BlendKit logo-файлы заменены
собственными нейтральными CC0-символами; права на марки не присваиваются.

## Реальные проверки — что доказано

- Godot 4.7.2: `tools/check.py smoke` — PASS.
- Editor import/reopen: все три плагина включаются; ERROR/SCRIPT ERROR и exit leaks отсутствуют.
- `res://tests/plugin_smoke.gd` — PASS: native Terrain3D, parse GDScript, семь
  непустых SPIR-V артефактов (compute, pre/post, MSAA, display, mask), без compile errors.
- GDScript lint/format собственного кода — PASS. Vendor-код не переформатируется массово.
- Python-тесты — результат в `docs/evidence/plugins/validation.json`.
- **Forward+ кадры получены и открыты:** lab, отдельное небо, облака с небом и
  контрольным объектом, X11 окно редактора. См. [evidence](../evidence/forward-plus/).
  Это software Vulkan, не аппаратные performance-измерения.
- Terrain3D-only и Terrain3D+clouds с bounded minimum материалом прошли полный
  прогон 43732396266. PNG земли/объекта/тени/облаков реально открыты. Прежний
  signal 11 обойдён bounded shader + ограничением mesh LODs; это не гарантия
  работоспособности всех функций исходного полного vendor shader.
- Исправлены Sunshine resource-init на main thread, shader include версии 4.7,
  неопределённая математика fog; clouds fixture освобождает RD до shutdown.
  Чёрный фон облаков устранён и проверен по реально открытым PNG.
- Terrain3D выдаёт предупреждения о чтении editor-кистей EXR через Image API;
  это не ошибка компиляции и не доказательство проблемы игровых текстур.
- Экспорт, runtime облаков/MSAA, Windows/macOS и целевая GPU требуют отдельных прогонов.

### Команды на машине с рабочей графикой

```sh
python tools/check.py smoke
# После импорта:
godot --headless --path godot --script res://tests/plugin_smoke.gd
# Реальный Forward+ кадр базового стенда (по умолчанию больше не форсирует GL):
python tools/check.py visual
# Интеграционный 3D-кадр: команда намеренно откажет в headless/без RD.
godot --path godot res://scenes/rendering_validation.tscn -- \
  --capture=/absolute/path/rendering-validation.png
```

В sandbox старый GL diagnostic остаётся только явным:
`python tools/check.py visual --renderer gl_compatibility --portable-graphics`.
Этот результат нельзя называть проверкой Forward+ или облаков.

## Происхождение, безопасность и лицензии

- Terrain3D — MIT, `addons/terrain_3d/LICENSE.txt`; сторонние демо-текстуры не импортированы.
- SunshineClouds2 — MIT, copyright David House, upstream LICENSE сохранён.
- Assets2Godot — GPLv2, полный поставленный addon source/license сохранён;
  локальные изменения документированы в `ARENA_CHANGES.md` и patch.
- Поиск процессов/HTTP/FileAccess/удалений показал ожидаемые для редакторских
  инструментов функции: texture packing, импорт/copy/конвертация, HTTP и helper launch.
  Это обзор кода, **не формальный security audit** и не гарантия безопасности бинарников.
- Hash-ведомость установленных файлов: [installation-manifest.json](installation-manifest.json).
- Повторяемая установка: `tools/install_godot_plugins.py`, official upstream commit
  закреплён; local source diff — `tools/plugin-integration.patch`. Существующие addons
  не перезаписываются автоматически.

## Первичные источники

Просмотрены 2026-11-15:

- [Godot: выбор renderer, ограничения и fallback](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html).
- [Terrain3D: установка](https://terrain3d.readthedocs.io/en/stable/docs/installation.html),
  [платформы и renderer support](https://terrain3d.readthedocs.io/en/stable/docs/platforms.html).
- [SunshineClouds2: README и исходники](https://github.com/Bonkahe/SunshineClouds2),
  [Godot 4.7 fix](https://github.com/Bonkahe/SunshineClouds2/commit/d2315addb50cae33dfce70165cf257dff6a132a1).
- [Assets2Godot: официальная документация](https://github.com/ikonnow/Assets2Godot),
  [релиз 0.8.2](https://github.com/ikonnow/Assets2Godot/releases/tag/v0.8.2).
