import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';

enum FilterType { daily, weekly, monthly }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController taskController = TextEditingController();

  FilterType selectedFilter = FilterType.weekly;

  CollectionReference get taskRef => FirebaseFirestore.instance
      .collection('users')
      .doc(user!.uid)
      .collection('tasks');

  // ---------------- LOGOUT ----------------
  void logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  // ---------------- ADD TASK ----------------
  void addTask() async {
    if (taskController.text.isEmpty) return;

    await taskRef.add({
      'title': taskController.text.trim(),
      'done': false,
      'type': selectedFilter.name,
      'createdAt': Timestamp.now(),
    });

    taskController.clear();
    Navigator.pop(context);
  }

  // ---------------- EDIT TASK ----------------
  void editTask(String id, String oldTitle) {
    final editController = TextEditingController(text: oldTitle);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Task"),
        content: TextField(controller: editController),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              taskRef.doc(id).update({'title': editController.text.trim()});
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // ---------------- AUTO EXPIRE ----------------
  bool isVisible(DocumentSnapshot doc) {
    if (!doc.data().toString().contains('type')) return false;

    final String type = doc['type'];
    final DateTime date = doc['createdAt'].toDate();
    final now = DateTime.now();

    if (type == 'daily') {
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }

    if (type == 'weekly') {
      return date.isAfter(now.subtract(const Duration(days: 7)));
    }

    if (type == 'monthly') {
      return date.year == now.year &&
          date.month == now.month;
    }

    return false;
  }

  // ---------------- TASK SCENE ----------------
  Widget taskScene(FilterType filter) {
    return StreamBuilder<QuerySnapshot>(
      stream: taskRef.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasks = snapshot.data!.docs
            .where((doc) =>
                doc.data().toString().contains('type') &&
                doc['type'] == filter.name &&
                isVisible(doc))
            .toList();

        if (tasks.isEmpty) {
          return const Center(
            child: Text("No tasks found", style: TextStyle(color: Colors.grey)),
          );
        }

        int doneCount = tasks.where((t) => t['done'] == true).length;
        int progress = ((doneCount / tasks.length) * 100).toInt();

        return Column(
          children: [
            // -------- TASK LIST --------
            Expanded(
              child: ListView(
                children: tasks.map((doc) {
                  return ListTile(
                    leading: Checkbox(
                      value: doc['done'],
                      onChanged: (v) =>
                          taskRef.doc(doc.id).update({'done': v}),
                    ),
                    title: Text(
                      doc['title'],
                      style: TextStyle(
                        decoration:
                            doc['done'] ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () =>
                              editTask(doc.id, doc['title']),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => taskRef.doc(doc.id).delete(),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            // -------- PROGRESS --------
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey.shade300,
                child: Text(
                  "$progress%",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A9AA4),
        title: Text("🍉 ${selectedFilter.name.toUpperCase()} Tasks"),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: logout),
        ],
      ),

      body: Column(
        children: [
          // -------- FILTER BUTTONS --------
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                filterButton("Daily", FilterType.daily),
                filterButton("Weekly", FilterType.weekly),
                filterButton("Monthly", FilterType.monthly),
              ],
            ),
          ),

          // -------- SCENE SWITCH --------
          Expanded(
            child: IndexedStack(
              index: selectedFilter.index,
              children: [
                taskScene(FilterType.daily),
                taskScene(FilterType.weekly),
                taskScene(FilterType.monthly),
              ],
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0A9AA4),
        child: const Icon(Icons.add),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Add Task"),
              content: TextField(
                controller: taskController,
                decoration:
                    const InputDecoration(hintText: "Task name"),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: addTask,
                  child: const Text("Add"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------- FILTER BUTTON ----------------
  Widget filterButton(String text, FilterType type) {
    final bool active = selectedFilter == type;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor:
            active ? const Color(0xFF0A9AA4) : Colors.grey.shade300,
        foregroundColor: active ? Colors.white : Colors.black,
      ),
      onPressed: () {
        setState(() {
          selectedFilter = type;
        });
      },
      child: Text(text),
    );
  }
}
