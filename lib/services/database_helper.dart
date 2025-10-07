import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/member.dart';
import '../models/fee.dart';
import '../models/attendance.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'gym_management.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        phone TEXT NOT NULL,
        address TEXT NOT NULL,
        joinDate TEXT NOT NULL,
        membershipPlan TEXT NOT NULL,
        isActive INTEGER NOT NULL,
        lastAttendance TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE fees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        memberId INTEGER NOT NULL,
        amount REAL NOT NULL,
        dueDate TEXT NOT NULL,
        paidDate TEXT,
        feeType TEXT NOT NULL,
        status TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (memberId) REFERENCES members (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        memberId INTEGER NOT NULL,
        checkInTime TEXT NOT NULL,
        checkOutTime TEXT,
        notes TEXT,
        FOREIGN KEY (memberId) REFERENCES members (id) ON DELETE CASCADE
      )
    ''');
  }

  // Member CRUD Operations
  Future<int> insertMember(Member member) async {
    final db = await database;
    return await db.insert('members', member.toMap());
  }

  Future<List<Member>> getAllMembers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('members');
    return List.generate(maps.length, (i) => Member.fromMap(maps[i]));
  }

  Future<Member?> getMemberById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'members',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Member.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Member>> getActiveMembers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'members',
      where: 'isActive = ?',
      whereArgs: [1],
    );
    return List.generate(maps.length, (i) => Member.fromMap(maps[i]));
  }

  Future<int> updateMember(Member member) async {
    final db = await database;
    return await db.update(
      'members',
      member.toMap(),
      where: 'id = ?',
      whereArgs: [member.id],
    );
  }

  Future<int> deleteMember(int id) async {
    final db = await database;
    return await db.delete(
      'members',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Member>> searchMembers(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'members',
      where: 'name LIKE ? OR email LIKE ? OR phone LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
    );
    return List.generate(maps.length, (i) => Member.fromMap(maps[i]));
  }

  // Fee CRUD Operations
  Future<int> insertFee(Fee fee) async {
    final db = await database;
    return await db.insert('fees', fee.toMap());
  }

  Future<List<Fee>> getAllFees() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('fees');
    return List.generate(maps.length, (i) => Fee.fromMap(maps[i]));
  }

  Future<List<Fee>> getFeesByMemberId(int memberId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'fees',
      where: 'memberId = ?',
      whereArgs: [memberId],
      orderBy: 'dueDate DESC',
    );
    return List.generate(maps.length, (i) => Fee.fromMap(maps[i]));
  }

  Future<List<Fee>> getPendingFees() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'fees',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'dueDate ASC',
    );
    return List.generate(maps.length, (i) => Fee.fromMap(maps[i]));
  }

  Future<List<Fee>> getOverdueFees() async {
    final db = await database;
    final String currentDate = DateTime.now().toIso8601String();
    final List<Map<String, dynamic>> maps = await db.query(
      'fees',
      where: 'status = ? AND dueDate < ?',
      whereArgs: ['pending', currentDate],
      orderBy: 'dueDate ASC',
    );
    return List.generate(maps.length, (i) => Fee.fromMap(maps[i]));
  }

  Future<int> updateFee(Fee fee) async {
    final db = await database;
    return await db.update(
      'fees',
      fee.toMap(),
      where: 'id = ?',
      whereArgs: [fee.id],
    );
  }

  Future<int> deleteFee(int id) async {
    final db = await database;
    return await db.delete(
      'fees',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markFeeAsPaid(int feeId, DateTime paidDate) async {
    final db = await database;
    return await db.update(
      'fees',
      {'status': 'paid', 'paidDate': paidDate.toIso8601String()},
      where: 'id = ?',
      whereArgs: [feeId],
    );
  }

  // Attendance CRUD Operations
  Future<int> insertAttendance(Attendance attendance) async {
    final db = await database;
    return await db.insert('attendance', attendance.toMap());
  }

  Future<List<Attendance>> getAllAttendance() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      orderBy: 'checkInTime DESC',
    );
    return List.generate(maps.length, (i) => Attendance.fromMap(maps[i]));
  }

  Future<List<Attendance>> getAttendanceByMemberId(int memberId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'memberId = ?',
      whereArgs: [memberId],
      orderBy: 'checkInTime DESC',
    );
    return List.generate(maps.length, (i) => Attendance.fromMap(maps[i]));
  }

  Future<List<Attendance>> getTodayAttendance() async {
    final db = await database;
    final DateTime today = DateTime.now();
    final String startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
    final String endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59).toIso8601String();
    
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'checkInTime >= ? AND checkInTime <= ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'checkInTime DESC',
    );
    return List.generate(maps.length, (i) => Attendance.fromMap(maps[i]));
  }

  Future<Attendance?> getActiveAttendanceForMember(int memberId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'memberId = ? AND checkOutTime IS NULL',
      whereArgs: [memberId],
      orderBy: 'checkInTime DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Attendance.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateAttendance(Attendance attendance) async {
    final db = await database;
    return await db.update(
      'attendance',
      attendance.toMap(),
      where: 'id = ?',
      whereArgs: [attendance.id],
    );
  }

  Future<int> checkOutMember(int attendanceId, DateTime checkOutTime) async {
    final db = await database;
    return await db.update(
      'attendance',
      {'checkOutTime': checkOutTime.toIso8601String()},
      where: 'id = ?',
      whereArgs: [attendanceId],
    );
  }

  Future<int> deleteAttendance(int id) async {
    final db = await database;
    return await db.delete(
      'attendance',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Utility Methods
  Future<int> getTotalMembers() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM members WHERE isActive = 1');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<double> getTotalPendingFees() async {
    final db = await database;
    final result = await db.rawQuery('SELECT SUM(amount) as total FROM fees WHERE status = "pending"');
    return (result.first['total'] as double?) ?? 0.0;
  }

  Future<int> getTodayAttendanceCount() async {
    final List<Attendance> todayAttendance = await getTodayAttendance();
    return todayAttendance.length;
  }

  Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
  }
}
