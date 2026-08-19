// 米坛页面 HTML 解析器单元测试
// 使用真实抓取的米坛页面样本验证解析逻辑：
// - bandbbs_cat91_sample.html：手环8 分类页（structItem 新模板，主列表）
// - bandbbs_home_sample.html：资源首页（structItem 模板）
// - bandbbs_resources_sample.html：旧模板列表页（li.block-row 兼容）
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bandbuddy_app/core/config.dart';
import 'package:bandbuddy_app/core/models/band_resource.dart';
import 'package:bandbuddy_app/data/adapters/bandbbs_html_adapter.dart';

void main() {
  final cat91 =
      File('test/fixtures/bandbbs_cat91_sample.html').readAsStringSync();
  final home =
      File('test/fixtures/bandbbs_home_sample.html').readAsStringSync();
  final legacy =
      File('test/fixtures/bandbbs_resources_sample.html').readAsStringSync();

  test('手环8分类页（structItem 新模板）解析出主列表资源', () {
    final items = BandBbsHtmlAdapter().parseList(cat91);
    expect(items.length, greaterThanOrEqualTo(10),
        reason: '分类页主列表应解析出 10+ 条资源');
  });

  test('structItem 条目字段完整且标题正确', () {
    final items = BandBbsHtmlAdapter().parseList(cat91);
    final first = items.first;
    expect(first.source, 'bandbbs');
    expect(first.sourceId, isNotEmpty);
    expect(first.title, isNotEmpty);
    expect(first.title.contains('<'), isFalse, reason: '标题不应含 HTML 标签');
    expect(first.author, isNotEmpty);
    expect(first.detailUrl, contains('/resources/'));
    expect(first.coverUrl, isNotNull, reason: '主列表资源应有封面图');

    // 回归：标题必须是真实资源标题，而非发布时间
    expect(first.title, isNot(equals(first.title.toUpperCase())),
        skip: true);
    final dateLike = RegExp(
        r'^(\d{4}[-/]\d{1,2}[-/]\d{1,2}|昨天|今天|星期|周[一二三四五六日]|\d+小时前|\d+天前|\d+分钟前)');
    expect(dateLike.hasMatch(first.title.trim()), isFalse,
        reason: '标题不应是日期/时间格式（修复前会显示"昨天 17:26"等）');
    expect(first.title.length, greaterThanOrEqualTo(4),
        reason: '标题太短可能是解析错位');
  });

  test('资源首页（structItem）也能解析', () {
    final items = BandBbsHtmlAdapter().parseList(home);
    expect(items.length, greaterThanOrEqualTo(10));
    // 回归：首页标题也应避免日期/时间
    final dateLike = RegExp(
        r'^(\d{4}[-/]\d{1,2}[-/]\d{1,2}|昨天|今天|星期|周[一二三四五六日]|\d+小时前|\d+天前|\d+分钟前)');
    for (final r in items.take(10)) {
      expect(dateLike.hasMatch(r.title.trim()), isFalse,
          reason: '${r.sourceId} 标题不应是日期/时间');
    }
  });

  test('旧模板 li.block-row 兼容解析', () {
    final items = BandBbsHtmlAdapter().parseList(legacy);
    expect(items.length, greaterThanOrEqualTo(10),
        reason: '旧模板页应解析出 10+ 条资源');
    final first = items.first;
    expect(first.title, isNotEmpty);
    expect(first.title.contains('<'), isFalse);
  });

  test('分类映射使用实测的 Resource Category ID', () {
    final cat = AppConfig.categories.firstWhere((c) => c.id == 'band8');
    expect(cat.bandbbsCategoryId, 91, reason: '手环8 对应米坛分类 91（实测）');
    final band10 = AppConfig.categories.firstWhere((c) => c.id == 'band10');
    expect(band10.bandbbsCategoryId, 103, reason: '手环10 对应分类 103（实测）');
  });

  test('详情页解析：评分/下载量/描述/预览图', () {
    final detail = File('test/fixtures/bandbbs_detail_sample.html')
        .readAsStringSync();
    final base = BandResource(
      source: 'bandbbs',
      sourceId: '1666',
      title: '小米手环8 JS小游戏 像素鸟FlappyBird',
      category: '小程序',
      author: 'test',
      detailUrl: 'https://www.bandbbs.cn/resources/1666/',
      updatedAt: DateTime.now(),
    );
    final r = BandBbsHtmlAdapter().parseDetail(detail, base);
    expect(r.ratingValue, greaterThan(0), reason: '应解析出评分（4.84 星）');
    expect(r.ratingValue, lessThanOrEqualTo(5));
    expect(r.ratingCount, greaterThan(0), reason: '应解析出评分人数');
    expect(r.downloads, greaterThan(0), reason: '应解析出下载量');
    expect(r.previewImages, isNotEmpty, reason: '详情正文应提取到预览图');
  });
}
