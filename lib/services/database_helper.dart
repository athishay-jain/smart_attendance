import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/student.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'attendance.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

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

    // Attendance table - NOW WITH UNIQUE CONSTRAINT
    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (uid) REFERENCES students (uid) ON DELETE CASCADE,
        UNIQUE(uid, date) 
      )
    ''');

    await db.execute('CREATE INDEX idx_attendance_date ON attendance(date)');
    await db.execute('CREATE INDEX idx_attendance_uid ON attendance(uid)');
  }

  // ... (Student methods remain the same) ...
  Future<void> addStudent(Student student) async {
    final db = await database;
    await db.insert('students', student.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Student?> getStudentByUid(String uid) async {
    final db = await database;
    final results = await db.query('students',
        where: 'uid = ?', whereArgs: [uid], limit: 1);
    if (results.isEmpty) return null;
    return Student.fromMap(results.first);
  }

  Future<List<Student>> getAllStudents() async {
    final db = await database;
    final results = await db.query('students', orderBy: 'name ASC');
    return results.map((map) => Student.fromMap(map)).toList();
  }

  Future<void> updateStudent(Student student) async {
    final db = await database;
    await db.update('students', student.toMap(),
        where: 'uid = ?', whereArgs: [student.uid]);
  }

  Future<void> deleteStudent(String uid) async {
    final db = await database;
    await db.delete('students', where: 'uid = ?', whereArgs: [uid]);
  }

  // ==============================================================
  // 🛠️ LOG FIX: Use ConflictAlgorithm.ignore to prevent duplicates
  // ==============================================================
  Future<void> logAttendance(String uid) async {
    final db = await database;
    final now = DateTime.now();
    final todayStr = now.toIso8601String().split('T')[0]; // YYYY-MM-DD

    try {
      // This will fail silently if (uid + date) already exists
      await db.insert(
        'attendance',
        {
          'uid': uid,
          'timestamp': now.toIso8601String(),
          'date': todayStr,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (e) {
      print("Duplicate attendance prevented: $e");
    }
  }

  // ... (Stats methods remain the same) ...
  Future<Map<String, int>> getDashboardStats() async {
    final db = await database;
    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    final totalResult =
    await db.rawQuery('SELECT COUNT(*) as count FROM students');
    final total = Sqflite.firstIntValue(totalResult) ?? 0;

    final presentResult = await db.rawQuery('''
      SELECT COUNT(DISTINCT uid) as count 
      FROM attendance 
      WHERE date = ?
    ''', [todayStr]);
    final present = Sqflite.firstIntValue(presentResult) ?? 0;

    return {'total': total, 'present': present, 'absent': total - present};
  }

  // ... (Other helper methods) ...
  Future<List<Student>> getAttendanceByDate(DateTime date) async {
    final db = await database;
    final dateStr =
    DateTime(date.year, date.month, date.day).toIso8601String().split('T')[0];
    final results = await db.rawQuery('''
      SELECT s.* FROM students s
      INNER JOIN attendance a ON s.uid = a.uid
      WHERE a.date = ?
      ORDER BY s.name ASC
    ''', [dateStr]);
    return results.map((map) => Student.fromMap(map)).toList();
  }

  Future<List<Map<String, dynamic>>> getStudentAttendanceHistory(String uid,
      {int days = 30}) async {
    final db = await database;
    final startDate = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String()
        .split('T')[0];
    return await db.query('attendance',
        where: 'uid = ? AND date >= ?',
        whereArgs: [uid, startDate],
        orderBy: 'date DESC');
  }

  Future<double> getStudentAttendancePercentage(String uid,
      {int days = 30}) async {
    final history = await getStudentAttendanceHistory(uid, days: days);
    if (days == 0) return 0.0;
    return (history.length / days) * 100;
  }

  Future<void> clearAllAttendance() async {
    final db = await database;
    await db.delete('attendance');
  }

  Future<void> clearTodayAttendance() async {
    final db = await database;
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    await db.delete('attendance', where: 'date = ?', whereArgs: [todayStr]);
  }

  // ==============================================================
  // SYNC FUNCTION (From previous fix)
  // ==============================================================
  Future<void> syncLogs(List<Map<String, dynamic>> logs) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('attendance');
      print('🗑️ Old attendance cleared from App Database');

      for (var log in logs) {
        if (log['uid'] == null) continue;

        String timestampStr;
        String dateStr;

        if (log['timestamp'] is int) {
          final now = DateTime.now();
          timestampStr = now.toIso8601String();
          dateStr = timestampStr.split('T')[0];
        } else {
          timestampStr = log['timestamp'].toString();
          try {
            dateStr = timestampStr.split('T')[0];
          } catch (e) {
            dateStr = DateTime.now().toIso8601String().split('T')[0];
          }
        }

        await txn.insert(
          'attendance',
          {
            'uid': log['uid'],
            'timestamp': timestampStr,
            'date': dateStr,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore, // Safety here too
        );
      }
    });
    print('✅ App Database synced with ${logs.length} records from ESP32');
  }
}