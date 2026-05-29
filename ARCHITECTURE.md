# 🏗️ Архитектура данных Flutter (аналог iOS версии)

## Обзор

Новая архитектура следует **многоуровневому паттерну**, аналогично iOS версии FurAffinityApp. Это обеспечивает:

- ✅ **Разделение ответственности** - каждый слой отвечает за свою задачу
- ✅ **Тестируемость** - можно легко подменять HTTP источник на мок
- ✅ **Расширяемость** - легко добавить кэширование, логирование и т.д.
- ✅ **Переиспользуемость** - компоненты работают независимо

## Слои архитектуры

```
┌─────────────────────────────────────┐
│   Flutter UI (Widgets/Screens)      │  MyApp, GalleryScreen, etc.
├─────────────────────────────────────┤
│   Business Logic (State Management) │  Provider, Riverpod, GetX
├─────────────────────────────────────┤
│   FASession (Интерфейс)             │  Протокол для работы с сессией
├─────────────────────────────────────┤
│   OnlineSession (Реализация)        │  HTTP запросы + HTML парсинг
├─────────────────────────────────────┤
│   HttpDataSource (Интерфейс)        │  Протокол для HTTP запросов
├─────────────────────────────────────┤
│   DioHttpDataSource (Реализация)    │  Dio + обработка ошибок
├─────────────────────────────────────┤
│   Dio + Cookie Manager              │  Сетевой слой
└─────────────────────────────────────┘
```

## Компоненты

### 1. HttpDataSource 📡
**Файл:** `lib/services/http_data_source.dart`

Абстрактный интерфейс для HTTP запросов. Позволяет:
- Отделить логику от реализации
- Подменять реальный HTTP на мок для тестирования
- Централизовать обработку ошибок

```dart
abstract interface class HttpDataSource {
  Future<String> httpData({
    required Uri url,
    required HttpMethod method,
    List<MapEntry<String, String>> parameters = const [],
    List<Cookie>? cookies,
  });
}
```

### 2. FASession 🔐
**Файл:** `lib/services/fa_session.dart`

Протокол для работы с сессией пользователя. Определяет операции:
- `getSubmissionPreviews()` - получить превью submission'ов
- `getSubmission()` - получить полное информацию
- `getUserGallery()` - получить галерею пользователя
- `getComments()` - получить комментарии

### 3. OnlineSession 🌐
**Файл:** `lib/services/online_session.dart`

Реализация `FASession` для онлайн источника:
- Выполняет HTTP запросы через `HttpDataSource`
- Парсит HTML ответы
- Кэширует повторяющиеся запросы (в памяти)
- Возвращает типизированные объекты

### 4. DynamicThumbnail 📸
**Файл:** `lib/services/dynamic_thumbnail.dart`

Умная система для выбора оптимального размера thumbnail'а:
- Доступные размеры: 200, 300, 320, 400, 600px
- Автоматически выбирает ближайший подходящий
- Аналогично iOS `DynamicThumbnail`

## Примеры использования

### Пример 1: Получить submission'ы пользователя

```dart
// В main.dart или инициализации приложения
final session = OnlineSession(
  username: 'my_username',
  displayUsername: 'My Display Name',
  dataSource: DioHttpDataSource(dio),
  cookies: cookieList,
);

// В экране
final previews = await session.getSubmissionPreviews();
for (final preview in previews) {
  print('${preview.title} by ${preview.author}');
  
  // Используем DynamicThumbnail для оптимального размера
  final thumbUrl = DynamicThumbnail(preview.thumbnailUrl)
      .getOptimalUrl(300); // Запросим размер ~300px
}
```

### Пример 2: Получить полное submission

```dart
final full = await session.getSubmission(submissionUrl);

// Используем полное разрешение для отображения
final fullResUrl = DynamicThumbnail(full.thumbnailUrl)
    .getFullResolutionUrl();

// Вычисляем высоту по соотношению сторон
final aspectRatio = full.widthOnHeightRatio as double;
final height = containerWidth / aspectRatio;
```

### Пример 3: С Provider для управления состоянием

```dart
final sessionProvider = FutureProvider<FASession>((ref) async {
  final userSession = ref.watch(userSessionProvider);
  
  return OnlineSession(
    username: userSession.username,
    displayUsername: userSession.displayUsername,
    dataSource: ref.watch(httpDataSourceProvider),
  );
});

final submissionsProvider = FutureProvider((ref) async {
  final session = await ref.watch(sessionProvider.future);
  return session.getSubmissionPreviews();
});
```

### Пример 4: Prefetching (предзагрузка)

```dart
// Загружаем thumbnail'ы для видимых элементов
void prefetchThumbnails(List<SubmissionPreview> previews, double screenWidth) {
  for (final preview in previews.take(3)) { // Первые 3 - высокий приоритет
    final url = DynamicThumbnail(preview.thumbnailUrl)
        .getOptimalUrlForWidget(Size(screenWidth, screenWidth));
    
    // Загружаем в кэш изображений (CachedNetworkImage)
    precacheImage(NetworkImage(url), context);
  }
}
```

## Обработка ошибок

### Cloudflare Protection
```dart
try {
  final previews = await session.getSubmissionPreviews();
} on CloudflareException catch (e) {
  print('Cloudflare challenge required: ${e.message}');
  // Запросить у пользователя переввода авторизации
} on FASessionException catch (e) {
  print('Session error: ${e.message}');
}
```

## Кэширование

### Встроенное кэширование в памяти
```dart
// OnlineSession автоматически кэширует повторяющиеся запросы
final previews1 = await session.getSubmissionPreviews(); // HTTP запрос
final previews2 = await session.getSubmissionPreviews(); // Из кэша

// Кэш очищается автоматически при завершении Future
```

### Рекомендуемое кэширование диска
Используйте `cached_network_image` для кэширования изображений:

```dart
// pubspec.yaml
dependencies:
  cached_network_image: ^3.3.0

// В коде
CachedNetworkImage(
  imageUrl: DynamicThumbnail(preview.thumbnailUrl)
      .getOptimalUrlForWidget(size),
  placeholder: (context, url) => Shimmer.fromColors(...),
  errorWidget: (context, url, error) => Icon(Icons.error),
  cacheKey: 'thumb_${preview.id}', // Уникальный ключ кэша
)
```

## Тестирование

### Мок HttpDataSource

```dart
class MockHttpDataSource implements HttpDataSource {
  @override
  Future<String> httpData({
    required Uri url,
    required HttpMethod method,
    List<MapEntry<String, String>> parameters = const [],
    List<Cookie>? cookies,
  }) async {
    // Возвращаем тестовый HTML
    return '''
      <figure id="sid-123">
        <img src="https://...@300-..." />
      </figure>
    ''';
  }
}

// В тесте
test('parseSubmissionPreviews', () async {
  final session = OnlineSession(
    username: 'test',
    displayUsername: 'Test',
    dataSource: MockHttpDataSource(),
  );

  final previews = await session.getSubmissionPreviews();
  expect(previews.length, 1);
  expect(previews.first.id, '123');
});
```

## Миграция существующего кода

### Старый способ (FAClient)
```dart
final client = FAClient();
await client.init();
await client.setSession(userSession);
// ... прямое использование client
```

### Новый способ (OnlineSession)
```dart
final session = OnlineSession(
  username: userSession.username,
  displayUsername: userSession.displayUsername,
  dataSource: DioHttpDataSource(_dio),
  cookies: userSession.cookies,
);

final previews = await session.getSubmissionPreviews();
```

## Расширение в будущем

### Автоффчное обновление  
```dart
// Добавить периодическое обновление
Timer.periodic(Duration(minutes: 15), (_) async {
  final fresh = await session.getSubmissionPreviews();
  // Обновить состояние
});
```

### Offline режим
```dart
// Создать MockSession с локальными данными
class OfflineSession implements FASession { ... }

// Использовать в зависимости от подключения
final session = isConnected ? OnlineSession(...) : OfflineSession(...);
```

### Синхронизация
```dart
// После получения данных, сохранить локально
final previews = await session.getSubmissionPreviews();
await localDb.savePreviews(previews);
```
