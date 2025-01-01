import 'dart:isolate';

import 'package:beshence_vault/beshence_vault.dart';
import 'package:uuid/uuid.dart';

import '../boxes/history_box_v1.dart';
import '../boxes/notes_box_v1.dart';
import '../boxes/servers_box_v1.dart';
import '../misc.dart';

class ServerIsolate extends IsolateHandler {
  @override
  void main(ReceivePort mainReceivePort, SendPort isolateSendPort) {
    mainReceivePort.listen((message) {
      List<String> args = message.split(".");
      var command = args.removeAt(0);
      switch(command) {
        case "pong":
          isolateSendPort.send("pull");
          break;
        case "pulled":
          if(args[0] == "new") {
            print("PULLED NEW. SENDING PUSH ONE");
            notesChangeNotifier.updateNotes();
          } else {
            print("DIDN'T PULL ANYTHING. SENDING PUSH ONE");
          }
          isolateSendPort.send("pushOne");
          break;
        case "pushedOne":
          if(args[0] == "new") {
            notesChangeNotifier.updateNotes();
            print("PUSHED ONE. PUSH AGAIN NOW");
            isolateSendPort.send("pushOne");
          } else {
            print("DIDN'T PUSH ANYTHING. SENDING PULL");
            Future.delayed(Duration(seconds: 3), () => isolateSendPort.send("pull"));
          }
      }
    });

    isolateSendPort.send("ping");
  }

  @override
  Future<void> isolate(ReceivePort isolateReceivePort, SendPort mainSendPort) async {
    ServersBoxV1 serversBox = await ServersBoxV1.create();
    NotesBoxV1 notesBox = await NotesBoxV1.create();
    HistoryBoxV1 historyBox = await HistoryBoxV1.create();

    isolateReceivePort.listen((message) async {
      List<String> args = message.split(".");
      var command = args.removeAt(0);
      switch(command) {
        case "ping":
          mainSendPort.send("pong");
          break;
        case "pull":
          try {
            ServerV1? localInfoAboutServer = serversBox.getServer();
            if (localInfoAboutServer == null) return;
            String? localLastEventId = localInfoAboutServer.lastEventId;

            BeshenceVault vault = BeshenceVault(
                address: localInfoAboutServer.address,
                token: localInfoAboutServer.token);
            final BeshenceChain chain = vault.getChain("notes");
            final String? serverLastEventId = await chain.lastEventId;

            bool newEvents = false;
            // 1. first of all we gather new events from the server if there are any
            while(localLastEventId != serverLastEventId && serverLastEventId != null) {
              // 1.1. we get the next event's id of already locally processed event
              String? eventIdToFetch = localLastEventId != null
                  ? (await chain.getEvent(localLastEventId))["next"]
                  : (await chain.firstEventId)!;

              // 1.2. we process this event and create history entry out of it
              if (eventIdToFetch == null) break;
              newEvents = true;
              dynamic event = await chain.getEvent(eventIdToFetch);
              HistoryEntryV1 historyEntry = HistoryEntryV1(
                  noteId: event["data"]["note_id"],
                  type: event["type"],
                  noteTitle: event["data"]["title"],
                  noteText: event["data"]["text"],
                  noteCreatedAt: event["data"]["created_at"] != null ? DateTime.fromMillisecondsSinceEpoch(event["data"]["created_at"]) : null,
                  noteModifiedAt: DateTime.fromMillisecondsSinceEpoch(event["data"]["modified_at"]),
                  chainEventId: eventIdToFetch,
                  applied: false
              );

              // 1.3. then we add to our history
              historyBox.addEntry(historyEntry);

              localLastEventId = eventIdToFetch;
              localInfoAboutServer.lastEventId = localLastEventId;
              serversBox.setServer(localInfoAboutServer);
            }

            assert(serverLastEventId == localLastEventId);

            // 2. we apply changes to the notes box
            for(HistoryEntryV1 entry in historyBox.getAllNotAppliedEntries()) {
              if(entry.type == "create_note") {
                // check if note is already created
                if(notesBox.getNote(entry.noteId) != null) {
                  historyBox.setEntryAppliedToTrue(entry);
                  continue;
                }
                // else create new note
                NoteV1 newNote = NoteV1(
                    id: entry.noteId,
                    createdAt: entry.noteCreatedAt!,
                    modifiedAt: entry.noteModifiedAt,
                    title: entry.noteTitle,
                    text: entry.noteText
                );
                notesBox.addNote(newNote);
                historyBox.setEntryAppliedToTrue(entry);
              } else if(entry.type == "update_note") {
                // check if note is gone
                if(notesBox.getNote(entry.noteId) == null) {
                  historyBox.setEntryAppliedToTrue(entry);
                  continue;
                }
                NoteV1 note = notesBox.getNote(entry.noteId)!;
                // check if note update event is newer than note modifiedAt
                if(note.modifiedAt.isAfter(entry.noteModifiedAt)) {
                  List<HistoryEntryV1> updates = historyBox.getUpdatesFromTimestamp(note.id, entry.noteModifiedAt);
                  for(HistoryEntryV1 update in updates) {
                    // queue of updates
                    if(update.noteTitle != null) note.title = update.noteTitle;
                    if(update.noteText != null) note.text = update.noteText;
                    note.modifiedAt = update.noteModifiedAt;
                  }
                  notesBox.updateNote(note);
                  historyBox.setEntryAppliedToTrue(entry);
                  continue;
                }
                // else update note
                if(entry.noteTitle != null) note.title = entry.noteTitle;
                if(entry.noteText != null) note.text = entry.noteText;
                note.modifiedAt = entry.noteModifiedAt;
                notesBox.updateNote(note);
                historyBox.setEntryAppliedToTrue(entry);
              } else if(entry.type == "delete_note") {
                // check if note is gone already
                if(notesBox.getNote(entry.noteId) == null) {
                  historyBox.setEntryAppliedToTrue(entry);
                  continue;
                }
                // else delete it
                notesBox.deleteNote(notesBox.getNote(entry.noteId)!);
                historyBox.setEntryAppliedToTrue(entry);
              }
            }

            mainSendPort.send("pulled.${newEvents ? "new" : "noNew"}");
          } on BeshenceVaultException catch(e) {
            print("error while pulling:");
            print(e.httpCode);
            print(e.name);
            print(e.description);
            mainSendPort.send("pulled.error");
          }
          break;
        case "pushOne":
          try {
            HistoryEntryV1? entryToUpload = historyBox.getFirstNotUploadedEntry();
            if(entryToUpload == null) {
              mainSendPort.send("pushedOne.noNew");
              return;
            }

            ServerV1? localInfoAboutServer = serversBox.getServer();
            if (localInfoAboutServer == null) return;

            BeshenceVault vault = BeshenceVault(
                address: localInfoAboutServer.address,
                token: localInfoAboutServer.token);
            final BeshenceChain chain = vault.getChain("notes");

            if(entryToUpload.type == "create_note") {
              String eventId = await chain.postEvent({
                "request_id": Uuid().v4(),
                "type": "create_note",
                "v": "v1",
                "data": {
                  "note_id": entryToUpload.noteId,
                  "created_at": entryToUpload.noteCreatedAt!.millisecondsSinceEpoch,
                  "modified_at": entryToUpload.noteModifiedAt.millisecondsSinceEpoch,
                  "title": entryToUpload.noteTitle,
                  "text": entryToUpload.noteText
                },
                if (localInfoAboutServer.lastEventId != null) "prev": localInfoAboutServer.lastEventId
              });
              serversBox.setServer(localInfoAboutServer..lastEventId = eventId);
              historyBox.setEntryEventId(entryToUpload, eventId);
              mainSendPort.send("pushedOne.new");
            } else if(entryToUpload.type == "update_note") {
              String eventId = await chain.postEvent({
                "request_id": Uuid().v4(),
                "type": "update_note",
                "v": "v1",
                "data": {
                  "note_id": entryToUpload.noteId,
                  "modified_at": entryToUpload.noteModifiedAt.millisecondsSinceEpoch,
                  if(entryToUpload.noteTitle != null) "title": entryToUpload.noteTitle,
                  if(entryToUpload.noteText != null) "text": entryToUpload.noteText,
                },
                if (localInfoAboutServer.lastEventId != null) "prev": localInfoAboutServer.lastEventId
              });
              serversBox.setServer(localInfoAboutServer..lastEventId = eventId);
              historyBox.setEntryEventId(entryToUpload, eventId);
              mainSendPort.send("pushedOne.new");
            } else if(entryToUpload.type == "delete_note") {
              String eventId = await chain.postEvent({
                "request_id": Uuid().v4(),
                "type": "delete_note",
                "v": "v1",
                "data": {
                  "note_id": entryToUpload.noteId,
                  "modified_at": entryToUpload.noteModifiedAt.millisecondsSinceEpoch
                },
                if (localInfoAboutServer.lastEventId != null) "prev": localInfoAboutServer.lastEventId
              });
              serversBox.setServer(localInfoAboutServer..lastEventId = eventId);
              historyBox.setEntryEventId(entryToUpload, eventId);
              mainSendPort.send("pushedOne.new");
            }
          } on BeshenceVaultException catch(e) {
            print("error while pushing:");
            print(e.httpCode);
            print(e.name);
            print(e.description);
            mainSendPort.send("pushedOne.error");
          }
          break;
      }
    });
  }
}