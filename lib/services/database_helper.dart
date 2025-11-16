import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/student.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  // Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'attendance.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // Create tables
  Future<void> _onCreate(Database db, int version) async {
    // Students table
    await db.execute('''
      CREATE TABLE students (
        uid TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        studentClass TEXT NOT NULL,
        imagePath TEXT NOT NULL,
        otherDetails TEXT
      )
    ''');

    // Attendance table
    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (uid) REFERENCES students (uid) ON DELETE CASCADE
      )
    ''');

    // Create index for faster queries
    await db.execute('''
      CREATE INDEX idx_attendance_date ON attendance(date)
    ''');

    await db.execute('''
      CREATE INDEX idx_attendance_uid ON attendance(uid)
    ''');
  }

  // Add a new student
  Future<void> addStudent(Student student) async {
    final db = await database;
    await db.insert(
      'students',
      student.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get student by UID
  Future<Student?> getStudentByUid(String uid) async {
    final db = await database;
    final results = await db.query(
      'students',
      where: 'uid = ?',
      whereArgs: [uid],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return Student.fromMap(results.first);
  }

  // Get all students
  Future<List<Student>> getAllStudents() async {
    final db = await database;
    final results = await db.query(
      'students',
      orderBy: 'name ASC',
    );

    return results.map((map) => Student.fromMap(map)).toList();
  }

  // Update student
  Future<void> updateStudent(Student student) async {
    final db = await database;
    await db.update(
      'students',
      student.toMap(),
      where: 'uid = ?',
      whereArgs: [student.uid],
    );
  }

  // Delete student
  Future<void> deleteStudent(String uid) async {
    final db = await database;
    await db.delete(
      'students',
      where: 'uid = ?',
      whereArgs: [uid],
    );
  }

  // Log attendance
  Future<void> logAttendance(String uid) async {
    final db = await database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = today.toIso8601String().split('T')[0];

    // Check if already marked today
    final existing = await db.query(
      'attendance',
      where: 'uid = ? AND date = ?',
      whereArgs: [uid, todayStr],
      limit: 1,
    );

    // Only add if not already marked today
    if (existing.isEmpty) {
      await db.insert('attendance', {
        'uid': uid,
        'timestamp': now.toIso8601String(),
        'date': todayStr,
      });
    }
  }

  // Get dashboard stats
  Future<Map<String, int>> getDashboardStats() async {
    final db = await database;
    final today = DateTime.now();
    final todayStr = DateTime(today.year, today.month, today.day)
        .toIso8601String()
        .split('T')[0];

    // Get total students
    final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM students');
    final total = Sqflite.firstIntValue(totalResult) ?? 0;

    // Get present today
    final presentResult = await db.rawQuery('''
      SELECT COUNT(DISTINCT uid) as count 
      FROM attendance 
      WHERE date = ?
    ''', [todayStr]);
    final present = Sqflite.firstIntValue(presentResult) ?? 0;

    // Calculate absent
    final absent = total - present;

    return {
      'total': total,
      'present': present,
      'absent': absent,
    };
  }

  // Get attendance for a specific date
  Future<List<Student>> getAttendanceByDate(DateTime date) async {
    final db = await database;
    final dateStr = DateTime(date.year, date.month, date.day)
        .toIso8601String()
        .split('T')[0];

    final results = await db.rawQuery('''
      SELECT s.* 
      FROM students s
      INNER JOIN attendance a ON s.uid = a.uid
      WHERE a.date = ?
      ORDER BY s.name ASC
    ''', [dateStr]);

    return results.map((map) => Student.fromMap(map)).toList();
  }

  // Get attendance history for a student
  Future<List<Map<String, dynamic>>> getStudentAttendanceHistory(
      String uid, {
        int days = 30,
      }) async {
    final db = await database;
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));

    final results = await db.query(
      'attendance',
      where: 'uid = ? AND date >= ?',
      whereArgs: [
        uid,
        startDate.toIso8601String().split('T')[0],
      ],
      orderBy: 'date DESC',
    );

    return results;
  }

  // Get attendance percentage for a student
  Future<double> getStudentAttendancePercentage(
      String uid, {
        int days = 30,
      }) async {
    final history = await getStudentAttendanceHistory(uid, days: days);
    if (days == 0) return 0.0;
    return (history.length / days) * 100;
  }

  // Clear all attendance records
  Future<void> clearAllAttendance() async {
    final db = await database;
    await db.delete('attendance');
  }

  // Clear today's attendance
  Future<void> clearTodayAttendance() async {
    final db = await database;
    final today = DateTime.now();
    final todayStr = DateTime(today.year, today.month, today.day)
        .toIso8601String()
        .split('T')[0];

    await db.delete(
      'attendance',
      where: 'date = ?',
      whereArgs: [todayStr],
    );
  }

  // Get total attendance count
  Future<int> getTotalAttendanceCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM attendance');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // Reset database (for testing purposes)
  Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'attendance.db');
    await deleteDatabase(path);
    _database = null;
    await database; // Reinitialize
  }
}