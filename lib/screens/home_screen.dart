import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:notes/main.dart';
import 'package:uuid/uuid.dart';

import '../boxes/local_notes_box_v1.dart';
import '../misc.dart';
import '../widgets/dynamic_grid.dart';
import '../widgets/suggestion.dart';
import '../widgets/wavy_divider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<StatefulWidget> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _openNewNote() {
    LocalNoteV1 note = LocalNoteV1(id: Uuid().v4(), createdAt: DateTime.fromMillisecondsSinceEpoch((DateTime.timestamp().millisecondsSinceEpoch ~/ 1000) * 1000), modifiedAt: DateTime.fromMillisecondsSinceEpoch((DateTime.timestamp().millisecondsSinceEpoch ~/ 1000) * 1000), title: null, text: null);
    localNotesBox.addLocalNote(note);
    notesChangeNotifier.updateNotes();
    context.push('/note/${note.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: () {}, icon: Icon(Icons.search)),
        title: Padding(
          padding: const EdgeInsets.only(left: /*24+12+16*/ 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Beshence Notes"),
              SizedBox(width: 12,),
              Icon(Icons.cloud_off, size: 16, color: Theme.of(context).colorScheme.secondary,)
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            elevation: 10,
            constraints: BoxConstraints(minWidth: 256),
            borderRadius: BorderRadius.all(Radius.circular(100)),
            surfaceTintColor: Theme.of(context).colorScheme.primary,
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem(
                  onTap: () {},
                  child: Row(
                    children: [
                      Icon(Icons.cloud_outlined),
                      SizedBox(width: 8,),
                      Text("785 MB / 15 GB used")
                    ],
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  onTap: () => context.push("/sort"),
                  child: Row(
                    children: [
                      Icon(Icons.sort),
                      SizedBox(width: 8,),
                      Text("Sort by")
                    ],
                  ),
                ),
                PopupMenuItem(
                  onTap: () => context.push("/newlabel"),
                  child: Row(
                    children: [
                      Icon(Icons.new_label),
                      SizedBox(width: 8,),
                      Text("New label")
                    ],
                  ),
                ),
                PopupMenuItem(
                  onTap: () => context.push("/newfolder"),
                  child: Row(
                    children: [
                      Icon(Icons.create_new_folder),
                      SizedBox(width: 8,),
                      Text("New folder")
                    ],
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  onTap: () => context.push("/settings"),
                  child: Row(
                    children: [
                      Icon(Icons.settings),
                      SizedBox(width: 8,),
                      Text("Settings")
                    ],
                  ),
                )
              ];
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
          top: false, bottom: false, left: true, right: true,
        child: CustomScrollView(
          slivers: [
            SliverList(
              delegate: SliverChildListDelegate([
                if(serversBox.getServer() == null && suggestionsBox.getSuggestion("backup").data != "hidden") Column(
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.sticky_note_2, size: 32,),
                                    SizedBox(height: 24,),
                                    RichText(
                                        text: TextSpan(
                                          style: TextStyle(fontSize: 24, height: 1.25, color: Theme.of(context).colorScheme.onPrimaryContainer),
                                            text: "Welcome to\n",
                                            children: [
                                              TextSpan(
                                                  text: "Beshence Notes",
                                                style: TextStyle(fontWeight: FontWeight.bold)
                                              ),
                                              TextSpan(text: "!")
                                            ]
                                        ),
                                        textAlign: TextAlign.center),
                                    //Text("Welcome to\nBeshence Notes!", style: TextStyle(fontSize: 24, height: 1.25,), textAlign: TextAlign.center),
                                    SizedBox(height: 16,),
                                    Text(
                                        "Let's start with these recommendations:",
                                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                                        textAlign: TextAlign.center),
                                    SizedBox(height: 24,),
                                  ],
                                )
                            ),
                            DynamicGridView(
                                maxWidthOnPortrait: 300,
                                maxWidthOnLandscape: 400,
                                sliver: false,
                                height: const DynamicGridViewHeight.fixed(84),
                                spaceBetween: 16,
                                children: [
                                  if(suggestionsBox.getSuggestion("backup").data != "hidden") Suggestion(
                                      icon: Icon(Icons.cloud_outlined, color: Theme.of(context).textTheme.bodySmall?.color),
                                      title: "Turn on notes backup and synchronisation",
                                      button: IconButton.filled(onPressed: () => context.push("/settings"), icon: const Icon(Icons.navigate_next)),
                                      cancelButton: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() {
                                        suggestionsBox.setSuggestion(suggestionsBox.getSuggestion("backup")..data = "hidden");
                                      }))
                                  ),
                                ]
                            ),
                          ],
                        )
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: SizedBox(
                        child: WavyDivider(height: 2, color: Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(100), wavelength: 20,),
                      ),
                    ),
                  ],
                ),
                ListenableBuilder(
                    listenable: notesChangeNotifier,
                    builder: (BuildContext context, Widget? child) {
                      List<LocalNoteV1> notes = localNotesBox.getAllLocalNotesSorted();
                      List<Widget> notesWidgets = [];
                      for(LocalNoteV1 note in notes) {
                        notesWidgets.add(
                            Card(
                              color: ElevationOverlay.applySurfaceTint(
                                  Theme.of(context).colorScheme.surface,
                                  Theme.of(context).colorScheme.surfaceTint,
                                  3),
                              margin: EdgeInsets.zero,
                              child: InkWell(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                onTap: () => context.push("/note/${note.id}"),
                                child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if(note.title != null) Text(note.title!, style: TextStyle(fontSize: 18),),
                                        if(note.text != null && note.title != null) SizedBox.fromSize(size: Size(0, 12)),
                                        if(note.text != null) Text(note.text!, style: TextStyle(fontSize: 14), maxLines: 5, overflow: TextOverflow.fade,)
                                      ],
                                    )
                                ),
                              ),
                            )
                        );
                      }
                      return notes.isNotEmpty ? Padding(padding: EdgeInsets.only(top: 16, left: 16, bottom: 16+96, right: 16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 16, children: notesWidgets,)) : SizedBox.shrink();
                    }
                ),
              ]),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: ListenableBuilder(
                listenable: notesChangeNotifier,
                builder: (BuildContext context, Widget? child) {
                  if(localNotesBox.localNotesLength == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 96),
                      child: Center(child: Text("No notes."),),
                    );
                  }
                  return SizedBox.shrink();
                },
              ),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewNote,
        tooltip: 'New note',
        enableFeedback: true,
        label: Text("New note"),
        icon: const Icon(Icons.edit),

      ),
    );
  }
}