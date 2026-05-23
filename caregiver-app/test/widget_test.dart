import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('CareVoice app boots', (tester) async {
    await tester.pumpWidget(const CareVoiceApp());
    await tester.pump();
    // The dashboard renders the brand wordmark even while the seniors list
    // is still loading from the API, so this is a stable smoke check.
    expect(find.text('CareVoice'), findsWidgets);
  });
}
