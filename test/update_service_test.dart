import 'package:flutter_test/flutter_test.dart';
import 'package:bandbuddy_app/core/services/update_service.dart';

void main() {
  group('UpdateService.isNewer', () {
    test('新版本大于当前版本', () {
      expect(UpdateService.isNewer('v1.2.0', '1.1.3'), isTrue);
      expect(UpdateService.isNewer('1.10.0', '1.9.9'), isTrue);
      expect(UpdateService.isNewer('2.0.0', '1.9.9'), isTrue);
      expect(UpdateService.isNewer('v1.1.4', 'v1.1.3'), isTrue);
    });

    test('相同或更旧版本返回 false', () {
      expect(UpdateService.isNewer('v1.1.3', '1.1.3'), isFalse);
      expect(UpdateService.isNewer('1.1.2', '1.1.3'), isFalse);
      expect(UpdateService.isNewer('', '1.1.3'), isFalse);
      expect(UpdateService.isNewer('1.1.3', '1.1.3'), isFalse);
    });

    test('支持预发布/构建号后缀忽略', () {
      expect(UpdateService.isNewer('v1.1.4-beta', '1.1.3'), isTrue);
      expect(UpdateService.isNewer('v1.1.4+build5', '1.1.3'), isTrue);
    });
  });
}
