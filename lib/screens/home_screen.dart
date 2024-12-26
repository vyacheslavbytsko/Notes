import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:notes/main.dart';
import 'package:uuid/uuid.dart';

import '../boxes/notes_box.dart';
import '../misc.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<StatefulWidget> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _openNewNote() {
    Note note = Note(id: Uuid().v4(), modifiedAt: DateTime.timestamp(), title: '', text: '');
    notesBox.addLocalNote(note);
    notesChangeNotifier.updateNotes();
    context.go('/note/${note.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text("Beshence Notes"),
      ),
      body: ListenableBuilder(
          listenable: notesChangeNotifier,
          builder: (BuildContext context, Widget? child) {
            List<Note> notes = notesBox.getAllLocalNotes();
            List<Widget> notesWidgets = [];
            for(Note note in notes) {
              notesWidgets.add(MaterialButton(child: Text(note.id), onPressed: () => context.go("/note/${note.id}")));
            }
            return Column(children: notesWidgets);
          }
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewNote,
        tooltip: 'New note',
        child: const Icon(Icons.add),
      ),
    );
  }
}