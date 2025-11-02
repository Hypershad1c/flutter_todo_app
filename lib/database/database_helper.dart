import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';
import '../models/task.dart';

/// Database helper that automatically switches between sqflite (mobile) and sembast (web)
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  
  // For mobile (sqflite)
  static Database? _database;
  
  // For web (sembast)
  static DatabaseFactory? _databaseFactory;
  static Database? _sembastDatabase;
  static final StoreRef<int, Map<String, dynamic>> _taskStore =
      intMapStoreFactory.store('tasks');

  DatabaseHelper._init();

  /// Get database instance (handles both mobile and web)
  Future<Database?> get database async {
    if (kIsWeb) {
      if (_sembastDatabase != null) return _sembastDatabase;
      return await _initWebDatabase();
    } else {
      if (_database != null) return _database;
      return await _initMobileDatabase();
    }
  }

  /// Initialize SQLite database for mobile
  Future<Database> _initMobileDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'todo_app.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
    return _database!;
  }

  /// Initialize Sembast database for web
  Future<Database> _initWebDatabase() async {
    _databaseFactory = databaseFactoryWeb;
    _sembastDatabase = await _databaseFactory!.openDatabase('todo_app.db');
    return _sembastDatabase!;
  }

  /// Create database tables (for mobile)
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        priority TEXT NOT NULL,
        isDone INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        completedAt TEXT,
        reminderTime TEXT
      )
    ''');
  }

  /// Insert a new task
  Future<int> insertTask(Task task) async {
    if (kIsWeb) {
      final db = await database;
      final id = await _taskStore.add(db!, task.toMap());
      return id;
    } else {
      final db = await database;
      return await db!.insert('tasks', task.toMap());
    }
  }

  /// Get all tasks
  Future<List<Task>> getAllTasks() async {
    if (kIsWeb) {
      final db = await database;
      final finder = Finder(sortOrders: [SortOrder('createdAt', false)]);
      final recordSnapshots = await _taskStore.find(db!, finder: finder);
      
      return recordSnapshots.map((snapshot) {
        final task = Task.fromMap(snapshot.value);
        task.id = snapshot.key;
        return task;
      }).toList();
    } else {
      final db = await database;
      final result = await db!.query(
        'tasks',
        orderBy: 'createdAt DESC',
      );
      return result.map((map) => Task.fromMap(map)).toList();
    }
  }

  /// Get active (not done) tasks
  Future<List<Task>> getActiveTasks() async {
    if (kIsWeb) {
      final db = await database;
      final finder = Finder(
        filter: Filter.equals('isDone', 0),
        sortOrders: [SortOrder('createdAt', false)],
      );
      final recordSnapshots = await _taskStore.find(db!, finder: finder);
      
      return recordSnapshots.map((snapshot) {
        final task = Task.fromMap(snapshot.value);
        task.id = snapshot.key;
        return task;
      }).toList();
    } else {
      final db = await database;
      final result = await db!.query(
        'tasks',
        where: 'isDone = ?',
        whereArgs: [0],
        orderBy: 'createdAt DESC',
      );
      return result.map((map) => Task.fromMap(map)).toList();
    }
  }

  /// Get completed tasks
  Future<List<Task>> getCompletedTasks() async {
    if (kIsWeb) {
      final db = await database;
      final finder = Finder(
        filter: Filter.equals('isDone', 1),
        sortOrders: [SortOrder('completedAt', false)],
      );
      final recordSnapshots = await _taskStore.find(db!, finder: finder);
      
      return recordSnapshots.map((snapshot) {
        final task = Task.fromMap(snapshot.value);
        task.id = snapshot.key;
        return task;
      }).toList();
    } else {
      final db = await database;
      final result = await db!.query(
        'tasks',
        where: 'isDone = ?',
        whereArgs: [1],
        orderBy: 'completedAt DESC',
      );
      return result.map((map) => Task.fromMap(map)).toList();
    }
  }

  /// Update a task
  Future<int> updateTask(Task task) async {
    if (kIsWeb) {
      final db = await database;
      await _taskStore.record(task.id!).update(db!, task.toMap());
      return task.id!;
    } else {
      final db = await database;
      return await db!.update(
        'tasks',
        task.toMap(),
        where: 'id = ?',
        whereArgs: [task.id],
      );
    }
  }

  /// Delete a task
  Future<int> deleteTask(int id) async {
    if (kIsWeb) {
      final db = await database;
      await _taskStore.record(id).delete(db!);
      return id;
    } else {
      final db = await database;
      return await db!.delete(
        'tasks',
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  /// Clear all completed tasks
  Future<void> clearCompletedTasks() async {
    if (kIsWeb) {
      final db = await database;
      final finder = Finder(filter: Filter.equals('isDone', 1));
      await _taskStore.delete(db!, finder: finder);
    } else {
      final db = await database;
      await db!.delete(
        'tasks',
        where: 'isDone = ?',
        whereArgs: [1],
      );
    }
  }

  /// Close database
  Future<void> close() async {
    if (kIsWeb) {
      await _sembastDatabase?.close();
    } else {
      await _database?.close();
    }
  }
}