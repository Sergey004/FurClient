import 'dart:io';

import 'package:fa_kit/fa_kit.dart' as fa;
import 'package:flutter_test/flutter_test.dart';
import 'package:furclient/models/submission.dart';
import 'package:furclient/utils/image_quality.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const full =
      'https://d.furaffinity.net/art/user/1660265303/1660265303.user_image.jpg';
  const preview = 'https://t.furaffinity.net/48519387@600-1660265303.jpg';

  tearDown(() {
    FAImageQuality.current.value = 'high';
  });

  test('quality selects original, 600px preview, or 300px preview', () {
    expect(
      FAImageQuality.resolveUrl(
        fullUrl: full,
        previewUrl: preview,
        quality: 'high',
      ),
      full,
    );
    expect(
      FAImageQuality.resolveUrl(
        fullUrl: full,
        previewUrl: preview,
        quality: 'medium',
      ),
      preview,
    );
    expect(
      FAImageQuality.resolveUrl(
        fullUrl: full,
        previewUrl: preview,
        quality: 'low',
      ),
      'https://t.furaffinity.net/48519387@300-1660265303.jpg',
    );
  });

  test('missing or non-thumbnail preview falls back to the original', () {
    expect(
      FAImageQuality.resolveUrl(fullUrl: full, quality: 'low'),
      full,
    );
    expect(
      FAImageQuality.resolveUrl(
        fullUrl: full,
        previewUrl: full,
        quality: 'medium',
      ),
      full,
    );
  });

  test('quality persists and unknown values normalize to high', () async {
    SharedPreferences.setMockInitialValues({'image_quality': 'low'});
    await FAImageQuality.load();
    expect(FAImageQuality.current.value, 'low');

    await FAImageQuality.setQuality('medium');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('image_quality'), 'medium');
    expect(FAImageQuality.current.value, 'medium');

    await FAImageQuality.setQuality('unexpected');
    expect(FAImageQuality.current.value, 'high');
    expect(prefs.getString('image_quality'), 'high');
  });

  test('submission model keeps both full and preview URLs from real HTML', () {
    final html = File(
      'packages/fa_kit/test/fixtures/'
      'www.furaffinity.net-view-48519387-comments.html',
    ).readAsStringSync();
    final page = fa.FASubmissionPage.parse(
      html,
      Uri.parse('https://www.furaffinity.net/view/48519387/'),
    );
    final submission = Submission.fromFASubmissionPage(page, '48519387');

    expect(submission.imageUrl, contains('d.furaffinity.net'));
    expect(submission.previewImageUrl, contains('@600-'));
    expect(submission.thumbnailUrl, submission.previewImageUrl);

    final restored = Submission.fromJson(submission.toJson());
    expect(restored.imageUrl, submission.imageUrl);
    expect(restored.previewImageUrl, submission.previewImageUrl);
  });
}
