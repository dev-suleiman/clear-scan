import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      p.join(dbPath, 'clearscan.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image_path TEXT NOT NULL,
            quality_class TEXT NOT NULL,
            confidence REAL NOT NULL,
            defects TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  static Future<int> insertSession({
    required String imagePath,
    required String qualityClass,
    required double confidence,
    required List<String> defects,
  }) async {
    final db = await database;
    return db.insert('sessions', {
      'image_path': imagePath,
      'quality_class': qualityClass,
      'confidence': confidence,
      'defects': defects.join(','),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<List<Map<String, dynamic>>> getSessions(
      {int limit = 50}) async {
    final db = await database;
    return db.query('sessions',
        orderBy: 'timestamp DESC', limit: limit);
  }

  static Future<void> deleteSession(int id) async {
    final db = await database;
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('sessions');
  }
}
