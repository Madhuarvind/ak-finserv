import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalDbService {
  static Database? _database;

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('Local database is not supported on web.');
    }
    if (_database != null) {
      return _database!;
    }
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), 'vasool_drive_local.db');
    return await openDatabase(
      path,
      version: 6,
      onCreate: (db, version) async {
        await _createDb(db);
        await _createCustomerTables(db);
        await _createLoanTables(db);
        await _createCollectionTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('DROP TABLE IF EXISTS auth_local');
          await _createDb(db);
        }
        if (oldVersion < 3) {
          await _createCustomerTables(db);
        }
        if (oldVersion < 4) {
          await _createLoanTables(db);
        }
        if (oldVersion < 5) {
          // Add missing columns to loans table
          await db.execute('ALTER TABLE loans ADD COLUMN processing_fee REAL DEFAULT 0.0');
          await db.execute('ALTER TABLE loans ADD COLUMN pending_amount REAL');
          await db.execute('ALTER TABLE loans ADD COLUMN is_locked INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE loans ADD COLUMN created_by INTEGER');
          await db.execute('ALTER TABLE loans ADD COLUMN approved_by INTEGER');
          await db.execute('ALTER TABLE loans ADD COLUMN assigned_worker_id INTEGER');
          await db.execute('ALTER TABLE loans ADD COLUMN guarantor_name TEXT');
          await db.execute('ALTER TABLE loans ADD COLUMN guarantor_mobile TEXT');
          await db.execute('ALTER TABLE loans ADD COLUMN guarantor_relation TEXT');
          await db.execute('ALTER TABLE loans ADD COLUMN start_date TEXT');
        }
        if (oldVersion < 6) {
          await _createCollectionTable(db);
        }
      },
    );
  }

  Future<void> _createDb(Database db) async {
    // Schema is designed to be compatible with Backend PostgreSQL
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

  Future<void> _createCustomerTables(Database db) async {
    await db.execute('''
      CREATE TABLE customers (
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        customer_id TEXT,
        name TEXT NOT NULL,
        mobile_number TEXT NOT NULL,
        address TEXT,
        area TEXT,
        assigned_worker_id INTEGER,
        status TEXT DEFAULT 'active',
        is_synced INTEGER DEFAULT 0, 
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<void> _createLoanTables(Database db) async {
    await db.execute('''
      CREATE TABLE loans (
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        loan_id TEXT,
        customer_id INTEGER,
        principal_amount REAL,
        interest_rate REAL,
        interest_type TEXT,
        tenure INTEGER,
        tenure_unit TEXT,
        processing_fee REAL DEFAULT 0.0,
        pending_amount REAL,
        status TEXT,
        is_locked INTEGER DEFAULT 0,
        created_by INTEGER,
        approved_by INTEGER,
        assigned_worker_id INTEGER,
        guarantor_name TEXT,
        guarantor_mobile TEXT,
        guarantor_relation TEXT,
        start_date TEXT,
        is_synced INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    
    await db.execute('''
      CREATE TABLE emi_schedule (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id INTEGER,
        emi_no INTEGER,
        due_date TEXT,
        amount REAL,
        status TEXT
      )
    ''');
  }

  Future<void> _createCollectionTable(Database db) async {
    await db.execute('''
      CREATE TABLE collections (
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id INTEGER,
        customer_id INTEGER,
        amount REAL,
        payment_mode TEXT,
        latitude REAL,
        longitude REAL,
        created_at TEXT,
        is_synced INTEGER DEFAULT 0,
        sync_error TEXT
      )
    ''');
  }

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
    if (maps.isNotEmpty) return maps.first;
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

    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  // --- Customer Methods ---

  Future<int> addCustomerLocally(Map<String, dynamic> customerData) async {
    if (kIsWeb) return 0;
    final db = await database;
    debugPrint('=== LOCAL DB: Adding customer ===');
    
    final id = await db.insert('customers', {
      'name': customerData['name'],
      'mobile_number': customerData['mobile_number'],
      'address': customerData['address'],
      'area': customerData['area'],
      'id_proof_number': customerData['id_proof_number'],
      'profile_image': customerData['profile_image'],
      'latitude': customerData['latitude'],
      'longitude': customerData['longitude'],
      'status': customerData['status'] ?? 'created',
      'created_at': customerData['created_at'] ?? DateTime.now().toIso8601String(),
      'is_synced': 0,
      'server_id': null,
      'customer_id': null,
    });
    
    debugPrint('Customer saved with local ID: $id');
    return id;
  }

  Future<List<Map<String, dynamic>>> getPendingCustomers() async {
    if (kIsWeb) return [];
    final db = await database;
    final results = await db.query(
      'customers',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    
    final List<Map<String, dynamic>> pendingList = [];
    for (var row in results) {
      final Map<String, dynamic> customer = Map.from(row);
      customer['local_id'] = row['local_id'].toString();
      pendingList.add(customer);
    }
    
    return pendingList;
  }

  Future<void> updateCustomerSyncStatus(int localId, int serverId, String customerId) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update(
      'customers',
      {
        'server_id': serverId,
        'customer_id': customerId,
        'is_synced': 1
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }
  
  Future<List<Map<String, dynamic>>> getAllLocalCustomers() async {
    if (kIsWeb) return [];
    final db = await database;
    return await db.query('customers', orderBy: 'created_at DESC');
  }

  // --- Loan Methods ---
  
  Future<int> saveLoanDraft(Map<String, dynamic> loanData) async {
    if (kIsWeb) return 0;
    final db = await database;
    return await db.insert('loans', {
      ...loanData,
      'status': 'created',
      'is_synced': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingLoans() async {
    if (kIsWeb) return [];
    final db = await database;
    return await db.query('loans', where: 'is_synced = ?', whereArgs: [0]);
  }

  // --- Collection Methods ---

  Future<int> addCollectionLocally(Map<String, dynamic> data) async {
    if (kIsWeb) return 0;
    final db = await database;
    debugPrint('=== LOCAL DB: Adding Collection ===');
    
    final id = await db.insert('collections', {
      'loan_id': data['loan_id'],
      'customer_id': data['customer_id'], // Optional if not always known
      'amount': data['amount'],
      'payment_mode': data['payment_mode'],
      'latitude': data['latitude'],
      'longitude': data['longitude'],
      'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
      'is_synced': 0
    });
    
    return id;
  }

  Future<List<Map<String, dynamic>>> getPendingCollections() async {
    if (kIsWeb) return [];
    final db = await database;
    return await db.query('collections', where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<void> markCollectionSynced(int localId) async {
     if (kIsWeb) return;
     final db = await database;
     await db.update('collections', {'is_synced': 1}, where: 'local_id = ?', whereArgs: [localId]);
  }

  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString('device_id', deviceId);
    }
    return deviceId;
  }
}
