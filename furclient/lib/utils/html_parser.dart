import 'package:html/dom.dart' as html_dom;

import '../models/models.dart';
import '../services/fa_session.dart';
import '../services/fa_urls.dart';

/// Парсит превью submission'а из HTML элемента figure
SubmissionPreview? parseSubmissionPreview(dynamic figElement) {
  if (figElement is! html_dom.Element) return null;

  try {
    // Получаем ID из атрибута id="sid-123456"
    final id = figElement.id;
    if (!id.startsWith('sid-')) return null;
    final submissionId = id.replaceFirst('sid-', '');

    // Получаемссылку на submission'е
    final linkElement = figElement.querySelector('a[href*="/view/"]');
    if (linkElement == null) return null;
    final href = linkElement.attributes['href'] ?? '';
    final submissionUrl = href.startsWith('http')
        ? href
        : '${FAUrls.baseUrl}$href';

    // Получаем изображение
    final imgElement = figElement.querySelector('img');
    if (imgElement == null) return null;

    final srcSet = imgElement.attributes['srcset'] ?? '';
    String thumbnailUrl = imgElement.attributes['src'] ?? '';

    // Парсим srcset для получения всех доступных размеров
    if (srcSet.isNotEmpty) {
      // srcset: "url@200 200w, url@300 300w, ..." → берем последний (максимальный)
      final parts = srcSet.split(',');
      if (parts.isNotEmpty) {
        thumbnailUrl = parts.last.split(' ').first.trim();
      }
    }

    // Получаем соотношение сторон из data атрибута
    double widthOnHeightRatio = 1.0;
    final ratioStr = figElement.attributes['data-width-to-height'] ?? '';
    if (ratioStr.isNotEmpty) {
      widthOnHeightRatio = double.tryParse(ratioStr) ?? 1.0;
    }

    // Получаем название и автора
    final titleElement = figElement.querySelector('.submission-title');
    final title = titleElement?.text.trim() ?? '';

    final authorElement = figElement.querySelector('.submission-author');
    final author = authorElement?.text.trim() ?? '';

    // Проверяем NSFW флаг
    final isNsfw = figElement.classes.contains('r-18');

    return SubmissionPreview(
      id: submissionId,
      title: title,
      author: author,
      displayAuthor: author,
      thumbnailUrl: thumbnailUrl,
      widthOnHeightRatio: widthOnHeightRatio,
      submissionUrl: submissionUrl,
      isNsfw: isNsfw,
    );
  } catch (e) {
    print('Error parsing submission preview: $e');
    return null;
  }
}

/// Парсит полную информацию о submission'е со страницы
Submission parseSubmissionFull(html_dom.Document document, String url) {
  try {
    // Это упрощенная версия. В полной реализации использовать FAPages-подобный парсер
    final idMatch = RegExp(r'/view/(\d+)').firstMatch(url);
    final id = idMatch?.group(1) ?? '';

    final titleElement = document.querySelector('h2[id="submission-title"]');
    final title = titleElement?.text.trim() ?? 'Unknown';

    final authorElement =
        document.querySelector('a[href*="/user/"][href*="/"]');
    final author = authorElement?.text.trim() ?? 'Unknown';

    // Парсим изображение
    final imgElement = document.querySelector('img[id*="submission_image"]');
    final imageUrl = imgElement?.attributes['src'] ?? '';

    // Парсим описание
    final descElement = document.querySelector('#submission-description');
    final description = descElement?.text.trim() ?? '';

    // Парсим теги
    final tags = <String>[];
    document.querySelectorAll('a[href*="/search/"]').forEach((tag) {
      tags.add(tag.text.trim());
    });

    return Submission(
      id: id,
      title: title,
      author: author,
      category: 'Digital',
      imageUrl: imageUrl,
      views: 0,
      faves: 0,
      commentsCount: 0,
      description: description,
      tags: tags,
      date: '',
      isNsfw: false,
      url: url,
    );
  } catch (e) {
    throw Exception('Failed to parse submission full: $e');
  }
}

/// Парсит комментарии со страницы
List<Comment> parseComments(html_dom.Document document) {
  final comments = <Comment>[];

  try {
    document.querySelectorAll('.comment').forEach((commentElement) {
      try {
        final idStr = commentElement.attributes['id'] ?? '';
        final id = int.tryParse(idStr.replaceFirst('cid-', '')) ?? 0;

        final authorElement = commentElement.querySelector('.comment-author');
        final author = authorElement?.text.trim() ?? 'Unknown';

        final contentElement = commentElement.querySelector('.comment-content');
        final content = contentElement?.text.trim() ?? '';

        final dateElement = commentElement.querySelector('.comment-date');
        final _dateStr = dateElement?.text.trim() ?? '';

        final comment = Comment(
          id: id,
          author: author,
          displayAuthor: author,
          content: content,
          date: DateTime.now(),
          authorAvatarUrl: FAUrls.avatar(author),
        );

        comments.add(comment);
      } catch (e) {
        debugPrint('Error parsing individual comment: $e');
      }
    };
  } catch (e) {
    debugPrint('Error parsing comments: $e');
  }

  return comments;
}

/// Расширение для удобного парсинга особых атрибутов
extension HtmlElementExtension on html_dom.Element {
  /// Безопасное получение текста с отступом
  String getTextSafe() => text.trim();

  /// Получает атрибут или возвращает default
  String getAttrSafe(String name, {String defaultValue = ''}) =>
      attributes[name]?.trim() ?? defaultValue;

  /// Проверяет наличие класса
  bool hasClass(String className) => classes.contains(className);
}
