import 'dart:convert';
import 'dart:isolate';

import 'package:fa_kit/fa_kit.dart' as fa;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../utils/notifications.dart';
import 'fa_client.dart';
import 'fa_urls.dart';

/// Цикл: 3 GET (лента → инбокс → /msg/others/) → diff по 6 int-watermark'ам
/// (строго >) → фильтр по тумблерам → постинг старых-раньше. Watermarks
/// двигаются из ПОЛНЫХ списков даже для выключенных категорий (помечаем
/// прочитанным). Первый запуск только засеивает watermarks — без постинга.
/// CF-челлендж в фоне → отдельный тост «Cloudflare check required» и выход
/// без изменения watermarks (очередь не теряется).
class NotificationPoller {
  final FAClient client;

  NotificationPoller(this.client);

  // Watermark-ключи — зеркала UserDefaultKeys эталона.
  static const _wmKeys = <String, String>{
    'submission': 'latestSubmissionNotificationID',
    'note': 'latestNoteNotificationID',
    'submission_comment': 'latestSubmissionCommentNotificationID',
    'journal_comment': 'latestJournalCommentNotificationID',
    'shout': 'latestShoutNotificationID',
    'journal': 'latestJournalNotificationID',
  };

  // Тумблеры категорий (SharedPreferences, по умолчанию все включены).
  static const _prefKeys = <String, String>{
    'submission': 'notify_submissions',
    'note': 'notify_notes',
    'submission_comment': 'notify_submission_comments',
    'journal_comment': 'notify_journal_comments',
    'shout': 'notify_shouts',
    'journal': 'notify_journals',
  };

  static const _cfToastNotificationId = 999999;

  Future<void> pollAndNotify() async {
    final prefs = await SharedPreferences.getInstance();
    if (client.session?.isLoggedIn != true) {
      // Нет сессии — молча выходим (fail-fast, как в эталоне).
      return;
    }

    try {
      debugPrint('=== Poller: polling submissions, notes, notifications');
      // Три источника — ПАРАЛЛЕЛЬНО: цикл занимает время самого медленного
      // запроса, а не сумму трёх.
      final results = await Future.wait<Object?>([
        client.getWatchSubmissions(),
        _fetchNotes(),
        _fetchOthers(),
      ]);
      final feed = results[0] as ({List<Submission> submissions, int? nextSid});
      final notes = results[1] as List<fa.FANotePreview>;
      final others = results[2] as fa.FANotificationPreviews;

      // Первый запуск: сеем watermarks и выходим, ничего не постим.
      final firstRun = !_hasAnyWatermark(prefs);
      if (firstRun) {
        await _seedWatermarks(prefs, feed, notes, others);
        debugPrint('=== Poller: first run, watermarks seeded');
        return;
      }

      // 2. Diff по категориям.
      final records = <Map<String, String>>[];
      for (final entry in _wmKeys.entries) {
        final category = entry.key;
        final enabled = prefs.getBool(_prefKeys[category]!) ?? true;
        final watermark = prefs.getInt(entry.value) ?? 0;

        switch (category) {
          case 'submission':
            final fresh = feed.submissions
                .where((s) => (int.tryParse(s.id) ?? 0) > watermark);
            if (enabled) {
              for (final s in fresh) {
                records.add(_record(
                    'submission-${s.id}',
                    'submission',
                    s.displayName.isNotEmpty ? s.displayName : s.author,
                    s.title,
                    'https://www.furaffinity.net/view/${s.id}/'));
              }
            }
            break;
          case 'note':
            final fresh = notes.where((n) => n.id > watermark && n.unread);
            if (enabled) {
              for (final n in fresh) {
                records.add(_record(
                    'note-${n.id}',
                    'note',
                    n.displayAuthor.isNotEmpty ? n.displayAuthor : n.author,
                    '✉️ ${n.title}',
                    n.noteUrl.toString()));
              }
            }
            break;
          default:
            final List<fa.FANotificationPreview> list = switch (category) {
              'submission_comment' => others.submissionComments,
              'journal_comment' => others.journalComments,
              'shout' => others.shouts,
              _ => others.journals,
            };
            final fresh = list.where((n) => n.id > watermark);
            if (enabled) {
              for (final n in fresh) {
                records.add(_record(
                    '$category-${n.id}',
                    category,
                    n.displayAuthor.isNotEmpty ? n.displayAuthor : n.author,
                    _emojiFor(category) + n.title,
                    n.url.toString()));
              }
            }
            break;
        }
      }

      // 3. Постинг старые-раньше (новые в конце, как в эталоне).
      for (final r in records) {
        await showNotification(
          type: r['type']!,
          title: r['title']!,
          body: r['body']!,
          notificationId: r['dedupKey']!.hashCode & 0x7fffffff,
          payload: r['url'],
        );
      }

      // 4. Watermarks двигаем из полных списков (включая выключенные).
      await _saveWatermarks(prefs, feed, notes, others);
      debugPrint('=== Poller: posted ${records.length} notifications');
    } on CloudflareError {
      // CF-заслон в фоне: тост и выход, watermarks не трогаем.
      debugPrint('=== Poller: CF challenge in background, posting CF toast');
      await showNotification(
        type: 'system',
        title: 'Cloudflare check required',
        body:
            'FurAffinity needs human verification. Open the app to resume notifications.',
        notificationId: _cfToastNotificationId,
      );
    } catch (e) {
      debugPrint('=== Poller: error: $e');
    }
  }

  Map<String, String> _record(
      String dedupKey, String type, String title, String body, String url) {
    return {
      'dedupKey': dedupKey,
      'type': type,
      'title': title,
      'body': body,
      'url': url,
    };
  }

  String _emojiFor(String category) => switch (category) {
        'submission_comment' => '💬 ',
        'journal_comment' => '💬 ',
        'shout' => '📣 ',
        'journal' => '📝 ',
        _ => '',
      };

  bool _hasAnyWatermark(SharedPreferences prefs) =>
      _wmKeys.values.any((k) => prefs.getInt(k) != null);

  Future<void> _seedWatermarks(
      SharedPreferences prefs,
      ({List<Submission> submissions, int? nextSid}) feed,
      List<fa.FANotePreview> notes,
      fa.FANotificationPreviews others) async {
    int maxOf(Iterable<int> ids) =>
        ids.isEmpty ? 0 : ids.reduce((a, b) => a > b ? a : b);
    await prefs.setInt(_wmKeys['submission']!,
        maxOf(feed.submissions.map((s) => int.tryParse(s.id) ?? 0)));
    await prefs.setInt(_wmKeys['note']!, maxOf(notes.map((n) => n.id)));
    await prefs.setInt(_wmKeys['submission_comment']!,
        maxOf(others.submissionComments.map((n) => n.id)));
    await prefs.setInt(_wmKeys['journal_comment']!,
        maxOf(others.journalComments.map((n) => n.id)));
    await prefs.setInt(
        _wmKeys['shout']!, maxOf(others.shouts.map((n) => n.id)));
    await prefs.setInt(
        _wmKeys['journal']!, maxOf(others.journals.map((n) => n.id)));
  }

  Future<void> _saveWatermarks(
      SharedPreferences prefs,
      ({List<Submission> submissions, int? nextSid}) feed,
      List<fa.FANotePreview> notes,
      fa.FANotificationPreviews others) async {
    int maxOf(Iterable<int> ids, int current) {
      final m = ids.isEmpty ? current : ids.reduce((a, b) => a > b ? a : b);
      return m > current ? m : current;
    }

    final wm = _wmKeys;
    await prefs.setInt(
        wm['submission']!,
        maxOf(feed.submissions.map((s) => int.tryParse(s.id) ?? 0),
            prefs.getInt(wm['submission']!) ?? 0));
    await prefs.setInt(wm['note']!,
        maxOf(notes.map((n) => n.id), prefs.getInt(wm['note']!) ?? 0));
    await prefs.setInt(
        wm['submission_comment']!,
        maxOf(others.submissionComments.map((n) => n.id),
            prefs.getInt(wm['submission_comment']!) ?? 0));
    await prefs.setInt(
        wm['journal_comment']!,
        maxOf(others.journalComments.map((n) => n.id),
            prefs.getInt(wm['journal_comment']!) ?? 0));
    await prefs.setInt(wm['shout']!,
        maxOf(others.shouts.map((n) => n.id), prefs.getInt(wm['shout']!) ?? 0));
    await prefs.setInt(
        wm['journal']!,
        maxOf(others.journals.map((n) => n.id),
            prefs.getInt(wm['journal']!) ?? 0));
  }

  Future<List<fa.FANotePreview>> _fetchNotes() async {
    final url = FAUrls.notesInbox;
    final html = await client.getHtml(url);
    // Парсинг — в фоновом изоляте (страницы по 100+ КБ).
    return Isolate.run(() {
      final page = fa.FANotesPage.parse(html, Uri.parse(url));
      return page.noteHeaders
          .whereType<fa.FANoteHeader>()
          .map(fa.FANotePreview.fromHeader)
          .toList();
    });
  }

  Future<fa.FANotificationPreviews> _fetchOthers() async {
    final html = await client.getHtml(FAUrls.notifications);
    return Isolate.run(() {
      final page =
          fa.FANotificationsPage.parse(html, Uri.parse(FAUrls.notifications));
      return fa.FANotificationPreviews.fromPage(page);
    });
  }
}

/// Переводит JSON-очередь в строку (зарезервировано на будущее: порядок
/// постинга и доотправка прерванных запусков).
String encodeQueue(List<Map<String, String>> records) => jsonEncode(records);
