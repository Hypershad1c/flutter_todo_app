import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../database/database_helper.dart';
import '../widgets/task_card.dart';
import 'history_page.dart';
import 'login_page.dart';
import '../main.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Task> _tasks = [];
  bool _isLoading = true;
  String _username = '';

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadTasks();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? 'User';
    });
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final tasks = await DatabaseHelper.instance.getActiveTasks();
    setState(() {
      _tasks = tasks;
      _isLoading = false;
    });
  }

  Future<void> _showAddTaskDialog({Task? taskToEdit}) async {
    final titleController = TextEditingController(text: taskToEdit?.title ?? '');
    final descController = TextEditingController(text: taskToEdit?.description ?? '');
    String priority = taskToEdit?.priority ?? 'Medium';
    DateTime? reminderTime = taskToEdit?.reminderTime;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(taskToEdit == null ? 'Add New Task' : 'Edit Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: priority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Low', 'Medium', 'High'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Row(
                        children: [
                          Icon(
                            Icons.flag,
                            color: value == 'High'
                                ? Colors.red
                                : value == 'Medium'
                                    ? Colors.orange
                                    : Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(value),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      priority = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(
                    reminderTime == null
                        ? 'No reminder set'
                        : 'Reminder: ${DateFormat('MMM dd, yyyy - HH:mm').format(reminderTime!)}',
                  ),
                  leading: const Icon(Icons.alarm),
                  trailing: reminderTime != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setDialogState(() {
                              reminderTime = null;
                            });
                          },
                        )
                      : null,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: reminderTime ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      if (context.mounted) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                            reminderTime ?? DateTime.now(),
                          ),
                        );
                        if (time != null) {
                          setDialogState(() {
                            reminderTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (titleController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Title is required')),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: Text(taskToEdit == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      if (taskToEdit == null) {
        final newTask = Task(
          title: titleController.text,
          description: descController.text,
          priority: priority,
          reminderTime: reminderTime,
        );
        final id = await DatabaseHelper.instance.insertTask(newTask);
        
        if (reminderTime != null) {
          await _scheduleNotification(id, newTask);
        }
      } else {
        final updatedTask = taskToEdit.copyWith(
          title: titleController.text,
          description: descController.text,
          priority: priority,
          reminderTime: reminderTime,
        );
        await DatabaseHelper.instance.updateTask(updatedTask);
        
        if (reminderTime != null) {
          await _scheduleNotification(updatedTask.id!, updatedTask);
        }
      }
      _loadTasks();
    }
  }

  Future<void> _scheduleNotification(int id, Task task) async {
    if (task.reminderTime == null) return;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      'Task Reminder: ${task.title}',
      task.description,
      tz.TZDateTime.from(task.reminderTime!, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Task Reminders',
          channelDescription: 'Notifications for task reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _toggleTaskComplete(Task task) async {
    final updatedTask = task.copyWith(
      isDone: !task.isDone,
      completedAt: !task.isDone ? DateTime.now() : null,
    );
    await DatabaseHelper.instance.updateTask(updatedTask);
    
    if (updatedTask.isDone) {
      await flutterLocalNotificationsPlugin.cancel(task.id!);
    }
    
    _loadTasks();
  }

  Future<void> _deleteTask(Task task) async {
    await DatabaseHelper.instance.deleteTask(task.id!);
    await flutterLocalNotificationsPlugin.cancel(task.id!);
    _loadTasks();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My Tasks'),
            Text(
              'Hello, $_username!',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HistoryPage(),
                ),
              ).then((_) => _loadTasks());
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.task_alt,
                        size: 100,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No tasks yet!',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the + button to add a new task',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTasks,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      return TaskCard(
                        task: task,
                        onToggleComplete: () => _toggleTaskComplete(task),
                        onEdit: () => _showAddTaskDialog(taskToEdit: task),
                        onDelete: () => _deleteTask(task),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTaskDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }
}