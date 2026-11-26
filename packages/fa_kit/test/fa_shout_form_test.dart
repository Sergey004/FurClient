import 'dart:io';
import 'package:fa_kit/fa_kit.dart';
import 'package:test/test.dart';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

void main() {
  test('parses the real shout form and builds its POST fields', () {
    final html = fixture('www.furaffinity.net-user-currentuser-shout-form.html');
    final form = FAShoutForm.parse(
      html,
      Uri.parse('https://www.furaffinity.net/user/currentuser/'),
    );

    expect(form, isNotNull);
    expect(form!.action.toString(),
        'https://www.furaffinity.net/user/currentuser/');
    expect(form.key, 'testkey');
    expect(form.username, 'currentuser');
    expect(form.fields('Hello'), {
      'action': 'shout',
      'key': 'testkey',
      'name': 'currentuser',
      'shout': 'Hello',
      'submit': 'Submit',
    });
  });

  test('returns null when the profile has no shout form', () {
    final html = fixture('www.furaffinity.net-msg-others-empty.html');
    expect(
      FAShoutForm.parse(
        html,
        Uri.parse('https://www.furaffinity.net/user/currentuser/'),
      ),
      isNull,
    );
  });
}
