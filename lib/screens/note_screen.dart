import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:notes/boxes/events_box_v1.dart';
import 'package:notes/main.dart';

import 'package:flutter/material.dart';
import 'package:notes/misc.dart';

import '../boxes/notes_box_v1.dart';

class NoteScreen extends StatefulWidget {
  final NoteV1 note;
  const NoteScreen({super.key, required this.note});

  @override
  State<StatefulWidget> createState() => _NoteScreenState();
}


class _NoteScreenState extends State<NoteScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController textController = TextEditingController();
  final FocusNode textFocusNode = FocusNode();

  DateTime titleLastModified = DateTime.timestamp();
  DateTime textLastModified = DateTime.timestamp();

  void saveNote() {
    String? title = titleController.text;
    String? text = textController.text;
    bool updateTitle = false;
    bool updateText = false;

    if(widget.note.title != title) {
      if(!(widget.note.title == null && title == "")) {
        updateTitle = true;
        widget.note.title = title;
      }
    }
    if(widget.note.text != text) {
      if(!(widget.note.text == null && text == "")) {
        updateText = true;
        widget.note.text = text;
      }
    }
    if(updateTitle || updateText) {
      var timestamp = DateTime.timestamp();
      widget.note.modifiedAt = timestamp;

      UpdateNoteEvent event = UpdateNoteEvent(
          noteId: widget.note.id,
          noteTitle: updateTitle ? title : null,
          noteText: updateText ? text : null,
          noteUpdatedAt: timestamp,
          applied: true);

      notesBox.updateNote(widget.note);
      eventsBox.addEvent(event);
      print("!!!");
      print(event.data);
      notesChangeNotifier.updateNotes();
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    textController.dispose();
    textFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    titleController.text = widget.note.title ?? "";
    textController.text = widget.note.text ?? "";

    titleController.addListener(() async {
      DateTime thisTitleLastModified = DateTime.timestamp();
      titleLastModified = thisTitleLastModified;
      await Future.delayed(Duration(seconds: 3), () {
        if(titleLastModified == thisTitleLastModified) {
          saveNote();
        }
      });
    });

    textController.addListener(() async {
      DateTime thisTextLastModified = DateTime.timestamp();
      textLastModified = thisTextLastModified;
      await Future.delayed(Duration(seconds: 3), () {
        if(textLastModified == thisTextLastModified) {
          saveNote();
        }
      });
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          if(result != "delete") {
            saveNote();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                switch(value) {
                  case "Delete":
                    DeleteNoteEvent event = DeleteNoteEvent(
                        noteId: widget.note.id,
                        noteDeletedAt: DateTime.timestamp(),
                        applied: true);
                    notesBox.updateNote(widget.note..deleted = true);
                    eventsBox.addEvent(event);
                    notesChangeNotifier.updateNotes();
                    context.pop("delete");
                    break;
                }
              },
              itemBuilder: (BuildContext context) {
                return {'Delete'}.map((String choice) {
                  return PopupMenuItem<String>(
                    value: choice,
                    child: Text(choice),
                  );
                }).toList();
              },
            ),
          ],
        ),
        body: SafeArea(
          top: false, bottom: false, left: true, right: true,
          child: CustomScrollView(
            slivers: [
              SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            TextField(
                              style: TextStyle(fontSize: 24),
                              scrollPhysics: NeverScrollableScrollPhysics(),
                              controller: titleController,
                              maxLines: null,
                              decoration: InputDecoration(
                                hintText: "Title",
                                border: InputBorder.none,
                              ),
                            ),
                            TextField(
                              focusNode: textFocusNode,
                              scrollPhysics: NeverScrollableScrollPhysics(),
                              maxLines: null,
                              controller: textController,
                              //style: TextStyle(height: 1.25),
                              decoration: InputDecoration(
                                hintText: "Start writing...",
                                border: InputBorder.none,
                              ),
                            )
                          ],
                        ),
                      )
                    ]
                  )
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: GestureDetector(
                  onTap: () {
                    textFocusNode.requestFocus();
                    textController.selection = TextSelection.fromPosition(TextPosition(offset: textController.text.length));
                    SystemChannels.textInput.invokeMethod("TextInput.show");
                  },
                ),
              )
            ]
          ),
        )
      ),
    );
  }
}

