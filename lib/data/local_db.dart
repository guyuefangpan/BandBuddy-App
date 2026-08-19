import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../core/models/band_resource.dart';

/// 本地数据库：收藏 + 下载历史
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'bandbuddy.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE favorites(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            source TEXT NOT NULL,
            sourceId TEXT NOT NULL,
            title TEXT NOT NULL,
            category TEXT,
            deviceModel TEXT,
            author TEXT,
            version TEXT,
            coverUrl TEXT,
            detailUrl TEXT,
            downloadUrl TEXT,
            rating INTEGER DEFAULT 0,
            downloads INTEGER DEFAULT 0,
            views INTEGER DEFAULT 0,
            updatedAt TEXT,
            description TEXT,
            createdAt INTEGER,
            UNIQUE(source, sourceId)
          )
        ''');
        await d.execute('''
          CREATE TABLE download_history(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            source TEXT NOT NULL,
            sourceId TEXT NOT NULL,
            title TEXT,
            url TEXT,
            fileName TEXT,
            filePath TEXT,
            size INTEGER DEFAULT 0,
            downloadedAt INTEGER
          )
        ''');
      },
    );
    return _db!;
  }

  // ================= 下载历史 =================
  Future<void> addDownload(
      BandResource r, String url, String fileName, String filePath, int size) async {
    final d = await db;
    await d.insert('download_history', {
      'source': r.source,
      'sourceId': r.sourceId,
      'title': r.title,
      'url': url,
      'fileName': fileName,
      'filePath': filePath,
      'size': size,
      'downloadedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getDownloadHistory() async {
    final d = await db;
    return d.query('download_history', orderBy: 'downloadedAt DESC');
  }

  Future<void> clearDownloadHistory() async {
    final d = await db;
    await d.delete('download_history');
  }
}
