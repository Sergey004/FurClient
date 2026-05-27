# FA Nexus — План адаптивного UI (Fluent WinUI 3 + Material You)

## Цель

Одна кодовая база, два визуальных языка:
- **Windows** → `fluent_ui` (FluentApp, NavigationView, Pane, FluentIcons)
- **Android / iOS / macOS** → Material 3 + Dynamic Color (MaterialApp, NavigationBar, NavigationRail)

---

## Архитектурный принцип

```
main.dart
  └── Platform.isWindows
        ├── FluentApp  ──→ AdaptiveShell (Fluent)  ──→ экраны
        └── MaterialApp ─→ AdaptiveShell (Material) ──→ те же экраны
```

Экраны (`gallery_screen.dart` и т.д.) — **не знают о платформе**.
Платформо-специфика инкапсулирована в:
- `AdaptiveShell` — корневой навигационный виджет
- `AdaptiveScaffold` — враппер страницы
- `AdaptiveButton`, `AdaptiveTextField` и т.д. — базовые контролы

---

## Фазы

---

### Фаза 0 — Подготовка зависимостей
**Файл:** `pubspec.yaml`

- [ ] Убрать `webview_flutter` — не используется, конфликтует с `flutter_inappwebview`
- [ ] Оставить `fluent_ui: ^4.9.1` — нужен для Windows
- [ ] Убедиться что есть: `dynamic_color`, `system_theme`, `flutter_inappwebview`
- [ ] Запустить `flutter pub get`

---

### Фаза 1 — Платформенные хелперы
**Новый файл:** `lib/utils/platform_utils.dart`

```dart
import 'dart:io' show Platform;

bool get isWindows => Platform.isWindows;
bool get isAndroid => Platform.isAndroid;
bool get isIOS => Platform.isIOS;
bool get isMacOS => Platform.isMacOS;
bool get isDesktop => isWindows || isMacOS || Platform.isLinux;
bool get isMobile => isAndroid || isIOS;
```

---

### Фаза 2 — Темы
**Файл:** `lib/theme/app_theme.dart` — расширить, не переписывать

Добавить:
```dart
// Новый метод — Fluent тема для Windows
static FluentThemeData get fluentDarkTheme { ... }
static FluentThemeData fluentFromSystemAccent(Color accent) { ... }
```

`FluentThemeData` использует те же цвета из `AppColors` — менять палитру не надо.

---

### Фаза 3 — main.dart
**Файл:** `lib/main.dart` — главное изменение

```dart
// Сейчас: всегда MaterialApp
// После: ветка по платформе

if (isWindows) {
  return FluentApp(         // fluent_ui
    theme: FluentThemeData,
    home: _buildHome(),
  );
} else {
  return DynamicColorBuilder(
    builder: (light, dark) => MaterialApp(
      theme: AppTheme.buildFromDynamicColor(dark),
      home: _buildHome(),
    ),
  );
}
```

`_buildHome()` остаётся без изменений — возвращает `LoginScreen` или `AdaptiveShell`.

---

### Фаза 4 — Навигация (самое важное)
**Файл:** `lib/navigation/app_navigator.dart` → переименовать/разбить

Создать два варианта:

**`lib/navigation/fluent_shell.dart`** (Windows):
```
FluentApp
  └── NavigationView
        ├── pane: NavigationPane
        │     ├── PaneItem(icon, title) × 5
        │     └── PaneItemSeparator
        └── content: экраны[_currentIndex]
```

**`lib/navigation/material_shell.dart`** (Android/iOS/macOS):
```
Scaffold
  ├── body: экраны[_currentIndex]
  ├── desktop (>=840px) → NavigationRail (боковой)
  └── mobile          → NavigationBar (нижний)
```

**`lib/navigation/adaptive_shell.dart`** — точка входа:
```dart
class AdaptiveShell extends StatelessWidget {
  Widget build(context) {
    if (isWindows) return FluentShell(...);
    return MaterialShell(...);
  }
}
```

---

### Фаза 5 — Адаптивные компоненты
**Новая папка:** `lib/widgets/adaptive/`

Приоритет — только то что используется в экранах:

| Компонент | Windows (Fluent) | Остальные (Material) |
|-----------|-----------------|----------------------|
| `AdaptiveScaffold` | `ScaffoldPage` | `Scaffold` |
| `AdaptiveButton` | `FilledButton` (fluent) | `ElevatedButton` |
| `AdaptiveTextField` | `TextBox` | `TextField` |
| `AdaptiveProgressRing` | `ProgressRing` | `CircularProgressIndicator` |
| `AdaptiveCard` | `Card` (fluent) | `Card` (material) |
| `AdaptiveListTile` | `ListTile` (fluent) | `ListTile` (material) |

Пример реализации:
```dart
// lib/widgets/adaptive/adaptive_button.dart
class AdaptiveButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  Widget build(context) {
    if (isWindows) {
      return fluent.FilledButton(
        onPressed: onPressed,
        child: Text(label),
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
```

---

### Фаза 6 — Экраны
**Папка:** `lib/screens/`

Экраны **минимально трогаем** — только заменяем прямые Material виджеты
на адаптивные там где это видно пользователю:

| Замена | На |
|--------|-----|
| `Scaffold` | `AdaptiveScaffold` |
| `ElevatedButton` | `AdaptiveButton` |
| `CircularProgressIndicator` | `AdaptiveProgressRing` |
| `TextField` | `AdaptiveTextField` |
| `AppBar` | только в `AdaptiveScaffold`, не в экранах напрямую |

`ListView`, `GridView`, `Image`, `Text`, `Icon` — **не трогать**,
они одинаково работают в обоих фреймворках.

---

### Фаза 7 — LoginScreen
**Файл:** `lib/screens/login_screen.dart`

Отдельная задача — там ещё баг с Cloudflare (см. `FIX_AUTH.md`).

- [ ] Фикс `_shouldOverrideUrlLoading` — разрешить все URL на `*.furaffinity.net`
      (включая `cdn-cgi/` для Cloudflare challenge)
- [ ] Заменить кнопку входа на `AdaptiveButton`
- [ ] На Windows — показывать `InAppWebView` внутри `ContentDialog` (fluent_ui)
      вместо inline в Scaffold

---

### Фаза 8 — Парсеры (независимо от UI)
**Файлы:** `lib/models/*.dart`

Парсеры FA HTML — работают на всех платформах одинаково, UI не касаются.
Делать параллельно или после UI, не блокирует запуск.

- [ ] `submission.dart` → `parseSubmissionsPage()`, `parseSubmissionDetails()`
- [ ] `fa_comment.dart` → `parseComments()`
- [ ] `fa_notification.dart` → `parseNotifications()`
- [ ] `fa_user.dart` → `parseUserPage()`

Референсы для DOM структуры FA:
- `../../Fur_Affinity_NOC_decomp/jadx_output/sources/one/furaffnoc/`
- `../../FurAffinityApp/` (iOS, Swift, open source)

---

## Порядок выполнения

```
Фаза 0  → flutter pub get (убрать webview_flutter)
Фаза 1  → platform_utils.dart (5 минут)
Фаза 2  → app_theme.dart (добавить FluentThemeData)
Фаза 3  → main.dart (ветка FluentApp / MaterialApp)
Фаза 4  → fluent_shell.dart + material_shell.dart + adaptive_shell.dart
Фаза 5  → lib/widgets/adaptive/* (AdaptiveScaffold, AdaptiveButton, ...)
Фаза 6  → экраны (минимальные замены)
Фаза 7  → login_screen.dart (фикс Cloudflare + адаптив)
Фаза 8  → парсеры (параллельно или в конце)
```

Тестировать после каждой фазы:
```bash
flutter run -d windows   # проверяем Fluent
flutter run -d android   # проверяем Material You
```

---

## Важно — что НЕ делать

- **Не оборачивать Material виджеты внутрь FluentApp** и наоборот —
  крашится в рантайме (`No FluentTheme widget found`)
- **Не импортировать `fluent_ui` в экраны напрямую** —
  только через адаптивные компоненты
- **Не трогать** `auth_service.dart`, `fa_client.dart`, `fa_urls.dart` —
  они платформонезависимы и работают

---

## Структура после рефакторинга

```
lib/
├── main.dart                        ← Фаза 3
├── models/                          ← Фаза 8
├── services/                        ← не трогать
├── theme/
│   └── app_theme.dart               ← Фаза 2 (добавить Fluent тему)
├── utils/
│   └── platform_utils.dart          ← Фаза 1 (новый)
├── navigation/
│   ├── adaptive_shell.dart          ← Фаза 4 (новый)
│   ├── fluent_shell.dart            ← Фаза 4 (новый)
│   └── material_shell.dart          ← Фаза 4 (из app_navigator.dart)
├── screens/                         ← Фаза 6 (минимальные правки)
└── widgets/
    ├── adaptive/                    ← Фаза 5 (новая папка)
    │   ├── adaptive_scaffold.dart
    │   ├── adaptive_button.dart
    │   ├── adaptive_text_field.dart
    │   ├── adaptive_progress.dart
    │   └── adaptive_card.dart
    └── ...существующие виджеты...
```
