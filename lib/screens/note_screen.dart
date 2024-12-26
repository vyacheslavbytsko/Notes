import 'dart:math';
import 'package:notes/main.dart';

import 'package:flutter/material.dart';
import 'package:notes/misc.dart';

import '../boxes/notes_box.dart';

class NoteScreen extends StatefulWidget {
  final Note note;
  const NoteScreen({super.key, required this.note});

  @override
  State<StatefulWidget> createState() => _NoteScreenState();
}


class _NoteScreenState extends State<NoteScreen> {
  final titleController = TextEditingController();
  final textController = TextEditingController();

  @override
  void dispose() {
    widget.note.title = titleController.text;
    widget.note.text = textController.text;
    widget.note.modifiedAt = DateTime.timestamp();
    notesBox.updateLocalNote(widget.note);
    notesChangeNotifier.updateNotes();
    titleController.dispose();
    textController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    titleController.text = widget.note.title;
    textController.text = widget.note.text;

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text("Beshence Notes"),
      ),
      body: Column(
        children: [
          TextField(
            controller: titleController,
            maxLines: 1,
            decoration: InputDecoration(
              hintText: "Title"
            ),
          ),
          TextField(
            controller: textController,
            autofocus: true,
          )
        ],
      ),
    );
  }
}