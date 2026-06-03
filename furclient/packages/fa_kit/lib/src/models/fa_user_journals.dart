import '../pages/fa_user_journals_page.dart';

/// A user's journals list page.
class FAUserJournals {
  final String displayAuthor;
  final List<FAUserJournalEntry> journals;

  FAUserJournals({
    required this.displayAuthor,
    required this.journals,
  });

  /// Create from a parsed user journals page.
  factory FAUserJournals.fromPage(FAUserJournalsPage page) {
    return FAUserJournals(
      displayAuthor: page.displayAuthor,
      journals: page.journals,
    );
  }
}
