import 'package:html/dom.dart' as dom;

/// Parses a FurAffinity date string from the `title` attribute of
/// `span.popup_date` elements.
///
/// FA uses two formats:
///   "October 10, 2022 01:45:09 PM"  (with seconds — submissions, comments)
///   "Jan 17, 2025 10:11 PM"         (without seconds — notifications)
///
/// Notification shouts have an "on " prefix:
///   "on Dec 23, 2024 05:56 PM"
///
/// Returns `null` for empty, null, or unparseable input.
DateTime? parseFADatetime(String? raw) {
  if (raw == null) return null;
  var input = raw.trim();
  if (input.isEmpty) return null;

  // Strip the "on " prefix that appears on notification shouts.
  if (input.startsWith('on ')) {
    input = input.substring(3).trim();
  }

  final match = _faDateRegex.firstMatch(input);
  if (match == null) return null;

  final monthName = match.group(1)!;
  final month = _monthLookup[monthName.toLowerCase()];
  if (month == null) return null;

  final day = int.tryParse(match.group(2)!);
  final year = int.tryParse(match.group(3)!);
  final hour = int.tryParse(match.group(4)!);
  final minute = int.tryParse(match.group(5)!);
  final second = int.tryParse(match.group(6) ?? '0') ?? 0;
  final ampm = match.group(7)!.toUpperCase();

  if (day == null || year == null || hour == null || minute == null) {
    return null;
  }

  // Convert to 24-hour format.
  var h24 = hour;
  if (ampm == 'PM' && h24 != 12) {
    h24 += 12;
  } else if (ampm == 'AM' && h24 == 12) {
    h24 = 0;
  }

  return DateTime(year, month, day, h24, minute, second);
}

/// Regex matching FA date format with optional seconds.
/// Group 1: month abbreviation (Jan, Feb, ...)
/// Group 2: day
/// Group 3: year
/// Group 4: hour (1-12)
/// Group 5: minute
/// Group 6: seconds (optional)
/// Group 7: AM/PM
final RegExp _faDateRegex = RegExp(
  r'^(\w+)\s+(\d+),\s+(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)$',
  caseSensitive: false,
);

/// Lookup table for month abbreviations.
const Map<String, int> _monthLookup = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

/// Result of parsing a FA date node.
class FADateResult {
  final DateTime? datetime;
  final String naturalDatetime;

  const FADateResult({this.datetime, required this.naturalDatetime});
}

/// Parses both the machine-readable datetime and the human-readable
/// natural datetime from a `span.popup_date` element.
///
/// The `title` attribute contains the exact datetime (e.g.
/// "October 10, 2022 01:45:09 PM") while the element text contains the
/// relative form (e.g. "3 years ago").
FADateResult parseFADateNode(dom.Element? node) {
  if (node == null)
    return const FADateResult(datetime: null, naturalDatetime: '');
  final datetime = parseFADatetime(node.attributes['title']);
  final naturalDatetime = node.text.trim();
  return FADateResult(datetime: datetime, naturalDatetime: naturalDatetime);
}
