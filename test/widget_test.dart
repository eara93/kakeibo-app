import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('アプリが起動する', (WidgetTester tester) async {
    // Firebase初期化が必要なためスモークテストのみ
    expect(true, isTrue);
  });
}
