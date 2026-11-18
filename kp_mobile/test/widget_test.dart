import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kp_mobile/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});

  testWidgets('KP Mobile app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const KpMobileApp());
    await tester.pumpAndSettle();

    expect(find.text('Katarungang Pambarangay'), findsOneWidget);
    expect(find.text('Resident Portal'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}
