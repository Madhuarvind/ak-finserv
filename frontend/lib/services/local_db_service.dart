import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class LocalDbService {
  static Database? _database;

  Future<Database> get database async {
    if (kIsWeb) throw UnsupportedError('Local database is not supported on web.');
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), 'vasool_drive_local.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createDb(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Simplest migration: drop and recreate for the name-based schema change
          await db.execute('DROP TABLE IF EXISTS auth_local');
          await _createDb(db);
        }
      },
    );
  }

  Future<void> _createDb(Database db) async {
    await db.execute('''
      CREATE TABLE auth_local (
        name TEXT PRIMARY KEY,
        pin_hash TEXT,
        access_token TEXT,
        role TEXT,
        is_active INTEGER DEFAULT 1,
        is_locked INTEGER DEFAULT 0,
        last_sync TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  // Hash PIN locally before storing or comparing (SHA-256 for local simplicity)
  String _hashPin(String pin) {
    var bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  Future<void> saveUserLocally({
    required String name,
    required String pin,
    String? token,
    String? role,
    bool? isActive,
    bool? isLocked,
  }) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert(
      'auth_local',
      {
        'name': name,
        'pin_hash': _hashPin(pin),
        'access_token': token,
        'role': role,
        'is_active': (isActive ?? true) ? 1 : 0,
        'is_locked': (isLocked ?? false) ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> verifyPinOffline(String name, String pin) async {
    if (kIsWeb) return 'web_offline_unavailable'; 
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'auth_local',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (maps.isEmpty) return 'user_not_found';
    
    final user = maps.first;
    if (user['is_active'] == 0) return 'user_inactive';
    if (user['is_locked'] == 1) return 'account_locked';

    String storedHash = user['pin_hash'];
    if (storedHash == _hashPin(pin)) {
      return null; // Success
    }
    return 'invalid_pin';
  }

  Future<Map<String, dynamic>?> getLastUser() async {
    if (kIsWeb) return null;
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'auth_local',
      limit: 1,
      orderBy: 'name DESC', 
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getLocalUser(String name) async {
    if (kIsWeb) return null;
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'auth_local',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }
}
