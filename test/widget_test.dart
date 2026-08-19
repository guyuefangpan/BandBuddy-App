// 基础冒烟测试：验证应用主框架能正常构建
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bandbuddy_app/main.dart';

void main() {
  setUp(() {
    // 测试环境 mock 本地存储；数据库不可用由 Provider 容错处理
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App builds and shows main shell', (WidgetTester tester) async {
    await tester.pumpWidget(const BandBuddyApp());
    await tester.pump(const Duration(milliseconds: 500));
    // 主框架存在：底部导航有 3 个 Tab（收藏已移除）
    expect(find.text('发现'), findsOneWidget);
    expect(find.text('搜索'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}
