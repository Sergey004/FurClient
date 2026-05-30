# Как правильно читать cookies из WebView2 на Windows (Flutter)

## Контекст

Приложение использует `flutter_inappwebview` с кастомным `WebViewEnvironment`
(профиль `webview2_data` в AppSupportDirectory). Cloudflare ставит `cf_clearance`
как `HttpOnly` cookie — `document.cookie` его не видит.

---

## Проблема которую ты пытаешься решить

```
CookieManager.instance().getCookies(url: ...) → возвращает 0 или мусорные cookies
```

**Причина:** без `webViewEnvironment` CookieManager читает системный WebView2
профиль, а не наш `webview2_data`. Там лежат случайные cookies от Edge/системы.

---

## Решение — одна строчка

```dart
// ❌ НЕПРАВИЛЬНО — читает системный профиль
final cookies = await CookieManager.instance().getCookies(
  url: WebUri('https://www.furaffinity.net'),
);

// ✅ ПРАВИЛЬНО — читает наш webview2_data профиль
final cookies = await CookieManager.instance(
  webViewEnvironment: webViewEnvironment, // глобальная переменная из main.dart
).getCookies(
  url: WebUri('https://www.furaffinity.net'),
);
```

Это задокументировано в flutter_inappwebview:
> "If you are using a custom WebViewEnvironment, set the webViewEnvironment
> parameter when calling CookieManager.instance()"

---

## Где хранится webViewEnvironment

```dart
// lib/main.dart — глобальная переменная
WebViewEnvironment? webViewEnvironment;

// Создаётся при запуске приложения:
if (Platform.isWindows) {
  final dir = await getApplicationSupportDirectory();
  webViewEnvironment = await WebViewEnvironment.create(
    settings: WebViewEnvironmentSettings(
      userDataFolder: '${dir.path}\\webview2_data',
      additionalBrowserArguments: '--disable-gpu --use-gl=swiftshader',
    ),
  );
}
```

---

## Как импортировать

```dart
import '../main.dart' show webViewEnvironment;
// или
import 'package:furclient/main.dart' show webViewEnvironment;
```

---

## Платформо-адаптивная обёртка (уже создана)

Файл: `lib/utils/cookie_manager.dart` — класс `FAICookieManager`

```dart
// Использовать везде вместо CookieManager.instance() напрямую:
final cookies = await FAICookieManager.getCookies(
  'https://www.furaffinity.net',
);
// Возвращает List<Cookie> включая HttpOnly (cf_clearance, a, b)
// На Windows — читает из webview2_data профиля
// На Android/iOS — стандартный CookieManager
```

---

## Что возвращается при правильном вызове

```
=== CookieManager cookies: 3
=== Cookie: a   | domain=.furaffinity.net | httpOnly=true  | value=8e225d87-...
=== Cookie: b   | domain=.furaffinity.net | httpOnly=true  | value=aca47ead-...
=== Cookie: sz  | domain=www.furaffinity.net | httpOnly=false | value=1249x597
```

Cookie `a` и `b` — это FA сессия. `cf_clearance` появляется после Cloudflare
challenge и тоже `HttpOnly` — без `webViewEnvironment` его не будет.

---

## Для CDN изображений (картинки не грузятся)

Архитектура: `lib/utils/fa_image_proxy.dart` — локальный HTTP прокси на `127.0.0.1:47652`

```
extended_image → FAImageProxy.proxyUrl(url)
  ├── Windows + *.furaffinity.net
  │     → http://127.0.0.1:47652/fa-proxy?url=...
  │           → FAICookieManager.getCookies() ← webview2_data
  │           → Dio запрос с cookies (включая cf_clearance) → CDN
  └── Android/iOS / другие домены → оригинальный URL без изменений
```

Прокси стартует в `main.dart` после создания `webViewEnvironment`:
```dart
await FAImageProxy().start();
```

`FAImageProxy` — синглтон, `factory FAImageProxy() => _instance`.

---

## Почему document.cookie не работает

```dart
// ❌ НЕ ДАЁТ HttpOnly cookies (cf_clearance, a, b)
final raw = await controller.evaluateJavascript(
  source: 'document.cookie',
) as String?;
// Вернёт только: "sz=1249x597" — только non-HttpOnly
```

JS не имеет доступа к `HttpOnly` cookies по спецификации браузера.
Единственный способ получить их — через `CookieManager.instance(webViewEnvironment: ...)`.

---

## Итого — три правила

1. **Всегда передавай `webViewEnvironment`** при создании `CookieManager.instance()`
   на Windows. Иначе читаешь чужой профиль.

2. **Используй `FAICookieManager`** из `lib/utils/cookie_manager.dart` —
   он уже делает всё правильно для каждой платформы.

3. **Не используй `document.cookie`** для получения сессионных cookies FA —
   `cf_clearance`, `a`, `b` все `HttpOnly` и через JS недоступны.
