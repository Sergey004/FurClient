import 'package:html/parser.dart' as parser;
import 'fa_urls.dart';

/// CSRF-bound form for posting a shout to a user's profile.
class FAShoutForm {
  final Uri action;
  final String key;
  final String username;

  const FAShoutForm({
    required this.action,
    required this.key,
    required this.username,
  });

  Map<String, String> fields(String message) => {
        'action': 'shout',
        'key': key,
        'name': username,
        'shout': message,
        'submit': 'Submit',
      };

  static FAShoutForm? parse(String html, Uri profileUrl) {
    final form = parser
        .parse(html)
        .querySelector('form.shout-post-form[method="post"]');
    if (form == null) return null;
    final actionField = form.querySelector('input[name="action"]');
    final keyField = form.querySelector('input[name="key"]');
    final nameField = form.querySelector('input[name="name"]');
    final shoutField = form.querySelector('textarea[name="shout"]');
    if (actionField?.attributes['value'] != 'shout' || shoutField == null) {
      return null;
    }

    final key = keyField?.attributes['value']?.trim() ?? '';
    if (key.isEmpty) return null;
    final username = nameField?.attributes['value']?.trim() ??
        RegExp(r'/user/([^/]+)').firstMatch(profileUrl.path)?.group(1) ??
        '';
    final actionValue = form.attributes['action']?.trim() ?? '';
    final action = actionValue.isEmpty
        ? profileUrl
        : Uri.parse(actionValue.startsWith('http')
            ? actionValue
            : '${FAURLs.baseUrl}${actionValue.startsWith('/') ? actionValue : '/$actionValue'}');
    return FAShoutForm(action: action, key: key, username: username);
  }
}
