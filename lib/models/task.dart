class Task {
  int? id;
  String title;
  String description;
  String priority; // 'Low', 'Medium', 'High'
  bool isDone;
  DateTime createdAt;
  DateTime? completedAt;
  DateTime? reminderTime;

  Task({
    this.id,
    required this.title,
    required this.description,
    this.priority = 'Medium',
    this.isDone = false,
    DateTime? createdAt,
    this.completedAt,
    this.reminderTime,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert Task to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'priority': priority,
      'isDone': isDone ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'reminderTime': reminderTime?.toIso8601String(),
    };
  }

  // Create Task from Map
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String,
      priority: map['priority'] as String,
      isDone: (map['isDone'] == 1 || map['isDone'] == true),
      createdAt: DateTime.parse(map['createdAt'] as String),
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
      reminderTime: map['reminderTime'] != null
          ? DateTime.parse(map['reminderTime'] as String)
          : null,
    );
  }

  // Create a copy of the task with updated fields
  Task copyWith({
    int? id,
    String? title,
    String? description,
    String? priority,
    bool? isDone,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? reminderTime,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }
}