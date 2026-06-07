import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as html_dom;

import '../models/models.dart';
import '../services/fa_session.dart';
import '../services/fa_urls.dart';

/// Парсит превью submission'а из HTML элемента figure[id^="sid-"]
/// Селекторы по iOS FASubmissionsPage.swift
SubmissionPreview? parseSubmissionPreview(dynamic figElement) {
  if (figElement is! html_dom.Element) return null;

  try {
    final id = figElement.id;
    if (!id.startsWith('sid-')) return null;
    final submissionId = id.replaceFirst('sid-', '');

    final linkElement = figElement.querySelector('a[href*="/view/"]');
    if (linkElement == null) return null;
    final href = linkElement.attributes['href'] ?? '';
    final submissionUrl =
        href.startsWith('http') ? href : '${FAUrls.baseUrl}$href';

    // iOS: figure b u a img
    final imgElement = figElement.querySelector('b u a img') ??
        figElement.querySelector('img');
    if (imgElement == null) return null;

    String thumbnailUrl = imgElement.attributes['src'] ?? '';
    final srcSet = imgElement.attributes['srcset'] ?? '';
    if (srcSet.isNotEmpty) {
      final parts = srcSet.split(',');
      if (parts.isNotEmpty) {
        thumbnailUrl = parts.last.split(' ').first.trim();
      }
    }
    if (thumbnailUrl.startsWith('//')) thumbnailUrl = 'https:$thumbnailUrl';

    double widthOnHeightRatio = 1.0;
    final ratioStr = figElement.attributes['data-width-to-height'] ?? '';
    if (ratioStr.isNotEmpty) {
      widthOnHeightRatio = double.tryParse(ratioStr) ?? 1.0;
    }

    // iOS: figcaption p a — первый = title, второй = author
    final captionLinks = figElement.querySelectorAll('figcaption p a');
    final title = captionLinks.isNotEmpty
        ? captionLinks[0].text.trim()
        : figElement.attributes['title'] ?? 'Untitled';

    String author = 'Unknown';
    if (captionLinks.length >= 2) {
      final authorHref = captionLinks[1].attributes['href'] ?? '';
      final m = RegExp(r'/user/([^/]+)/').firstMatch(authorHref);
      author = m?.group(1) ?? captionLinks[1].text.trim();
    }

    final isNsfw = figElement.classes.contains('r-adult') ||
        figElement.classes.contains('r-mature') ||
        figElement.querySelector('[data-rating="adult"]') != null ||
        figElement.querySelector('[data-rating="mature"]') != null;

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
    debugPrint('Error parsing submission preview: $e');
    return null;
  }
}

/// Парсит полную страницу submission'а.
/// Возвращает Submission (не SubmissionFull) — совместимо с FASession контрактом.
Submission parseSubmissionFull(html_dom.Document document, String url) {
  try {
    final idMatch = RegExp(r'/view/(\d+)').firstMatch(url);
    final id = idMatch?.group(1) ?? '';

    // iOS: div.submission-title h2
    final titleEl = document.querySelector('div.submission-title h2');
    final title = titleEl?.text.trim() ?? 'Untitled';

    // iOS: span.c-usernameBlockSimple a
    final authorEl = document.querySelector('span.c-usernameBlockSimple a');
    String author = 'Unknown';
    if (authorEl != null) {
      final href = authorEl.attributes['href'] ?? '';
      final m = RegExp(r'/user/([^/]+)/').firstMatch(href);
      author = m?.group(1) ?? authorEl.text.trim();
    }

    // iOS: div.submission-area img#submissionImg
    final imgEl =
        document.querySelector('div.submission-area img#submissionImg');
    var imageUrl = imgEl?.attributes['data-fullview-src'] ??
        imgEl?.attributes['data-preview-src'] ??
        imgEl?.attributes['src'] ??
        '';
    if (imageUrl.startsWith('//')) imageUrl = 'https:$imageUrl';

    // iOS: div.submission-description-text
    final descEl = document.querySelector('div.submission-description-text');
    final description = descEl?.text.trim() ?? '';

    // iOS: div[title="Views"] div, div[title="Favorites"] div
    int views = 0, faves = 0, comments = 0;
    views = int.tryParse(
            document.querySelector('div[title="Views"] div')?.text.trim() ??
                '') ??
        0;
    faves = int.tryParse(
            document.querySelector('div[title="Favorites"] div')?.text.trim() ??
                '') ??
        0;
    comments = int.tryParse(
            document.querySelector('div[title="Comments"] div')?.text.trim() ??
                '') ??
        0;

    // Теги
    final tags = document
        .querySelectorAll('div.submission-tags div span.tags')
        .map((e) {
          final tagBlock = e.querySelector('[data-tag-name]');
          return tagBlock?.attributes['data-tag-name'] ?? e.text.trim();
        })
        .where((t) => t.isNotEmpty)
        .toList();

    // Rating
    final ratingEl = document.querySelector('[class*="c-contentRating"]');
    final ratingText = ratingEl?.text.trim() ?? '';
    final isNsfw = ratingText == 'Adult' || ratingText == 'Mature';

    // Date
    final dateEl = document.querySelector('span.popup_date');
    final date = dateEl?.attributes['title'] ?? dateEl?.text.trim() ?? '';

    return Submission(
      id: id,
      title: title,
      author: author,
      category: 'Digital',
      imageUrl: imageUrl,
      views: views,
      faves: faves,
      commentsCount: comments,
      description: description,
      tags: tags,
      date: date,
      isNsfw: isNsfw,
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
    for (final commentEl in document.querySelectorAll('.comment')) {
      try {
        final idStr = commentEl.attributes['id'] ?? '';
        final id = int.tryParse(idStr.replaceFirst('cid-', '')) ?? 0;

        final authorEl = commentEl.querySelector('.comment-author a') ??
            commentEl.querySelector('.comment-author');
        final author = authorEl?.text.trim() ?? 'Unknown';

        final contentEl = commentEl.querySelector('.comment-content');
        final content = contentEl?.text.trim() ?? '';

        comments.add(Comment(
          id: id,
          author: author,
          displayAuthor: author,
          content: content,
          date: DateTime.now(),
          authorAvatarUrl: FAUrls.avatar(author),
        ));
      } catch (e) {
        debugPrint('Error parsing comment: $e');
      }
    }
  } catch (e) {
    debugPrint('Error parsing comments: $e');
  }
  return comments;
}

extension HtmlElementExtension on html_dom.Element {
  String getTextSafe() => text.trim();
  String getAttrSafe(String name, {String defaultValue = ''}) =>
      attributes[name]?.trim() ?? defaultValue;
  bool hasClass(String className) => classes.contains(className);
}
