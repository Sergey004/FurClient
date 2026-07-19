import 'package:flutter_test/flutter_test.dart';
import 'package:furclient/models/fa_user.dart';

void main() {
  test('prefers the profile heading over a generic Browse heading', () {
    const html = '''
      <html>
        <body>
          <h2>Browse</h2>
          <div class="profile">
            <h2>SomeArtist</h2>
          </div>
        </body>
      </html>
    ''';

    final user = FAUser.parseUserPage(html, 'someartist');

    expect(user, isNotNull);
    expect(user!.displayName, 'SomeArtist');
  });
}
