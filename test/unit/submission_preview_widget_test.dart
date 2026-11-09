import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furclient/models/fa_comment.dart';
import 'package:furclient/models/submission.dart';
import 'package:furclient/models/submission_preview.dart';
import 'package:furclient/screens/submission_detail_screen.dart';
import 'package:furclient/services/fa_client.dart';

/// FAClient с вечно висящим ответом — экран остаётся в состоянии загрузки,
/// где и рисуется превью из уведомления.
class _HangingClient extends FAClient {
  final _completer = Completer<({Submission? submission, List<FAComment> comments})>();

  @override
  Future<({Submission? submission, List<FAComment> comments})>
      getSubmissionWithComments(String id) => _completer.future;
}

void main() {
  testWidgets('detail screen shows the notification preview while loading',
      (tester) async {
    const preview = SubmissionPreview(
      id: '66491081',
      title: 'what u lookin at',
      author: 'carlarzall',
      displayName: 'carlarzall',
      thumbnailUrl: 'https://t.furaffinity.net/66491081@300-1.jpg',
      url: 'https://www.furaffinity.net/view/66491081/',
      rating: 'general',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SubmissionDetailScreen(
          client: _HangingClient(),
          submissionId: '66491081',
          preview: preview,
        ),
      ),
    );
    await tester.pump();

    // Превью показывается ДО загрузки страницы.
    expect(find.text('what u lookin at'), findsOneWidget);
    expect(find.text('by carlarzall'), findsOneWidget);
  });

  testWidgets('without preview the loading state is just a spinner',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SubmissionDetailScreen(
          client: _HangingClient(),
          submissionId: '66491081',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('what u lookin at'), findsNothing);
  });
}
