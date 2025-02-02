import 'dart:isolate';

import 'package:beshence_vault/beshence_vault.dart';
import 'package:notes/boxes/events_box_v1.dart';
import 'package:uuid/uuid.dart';

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
          isolateSendPort.send("pullOne");
          break;
        case "pulledOne":
          if(args[0] == "new") {
            notesChangeNotifier.updateNotes();
            print("PULLED NEW. PULLING AGAIN NOW");
            isolateSendPort.send("pullOne");
          } else {
            print("DIDN'T PULL ANYTHING. SENDING PUSH ONE");
            isolateSendPort.send("pushOne");
          }
          break;
        case "pushedOne":
          if(args[0] == "new") {
            notesChangeNotifier.updateNotes();
            print("PUSHED ONE. PUSH AGAIN NOW");
            isolateSendPort.send("pushOne");
          } else {
            print("DIDN'T PUSH ANYTHING. SENDING PULL ONE");
            Future.delayed(Duration(seconds: 3), () => isolateSendPort.send("pullOne"));
          }
      }
    });

    isolateSendPort.send("ping");
  }

  @override
  Future<void> isolate(ReceivePort isolateReceivePort, SendPort mainSendPort) async {
    ServersBoxV1 serversBox = await ServersBoxV1.create();
    NotesBoxV1 notesBox = await NotesBoxV1.create();
    EventsBoxV1 eventsBox = await EventsBoxV1.create();

    isolateReceivePort.listen((message) async {
      List<String> args = message.split(".");
      var command = args.removeAt(0);
      switch(command) {
        case "ping":
          mainSendPort.send("pong");
          break;
        case "pullOne":
          try {
            ServerV1? localInfoAboutServer = serversBox.getServer();
            if (localInfoAboutServer == null) return;
            String? localLastEventId = localInfoAboutServer.lastEventId;

            BeshenceVault vault = BeshenceVault(
                address: localInfoAboutServer.address,
                token: localInfoAboutServer.token);
            final BeshenceChain chain = vault.getChain("notes");
            final String? serverLastEventId = await chain.lastEventId;

            // 1. first we find out if there's a need to get new event
            if(!(localLastEventId != serverLastEventId && serverLastEventId != null)) {
              mainSendPort.send("pulledOne.noNew");
              return;
            }

            // 1.1. we get the next event's id of already locally processed event
            String eventIdToFetch = localLastEventId != null
                ? (await chain.getEvent(localLastEventId))["next"]
                : (await chain.firstEventId)!;

            // 1.2. we get this event as JSON and convert to the Event class
            dynamic jsonEvent = await chain.getEvent(eventIdToFetch);

            late EventV1 event;
            switch(jsonEvent["type"]) {
              case "create_note":
                event = CreateNoteEvent.fromJson(jsonEvent: jsonEvent);
                break;
              case "update_note":
                event = UpdateNoteEvent.fromJson(jsonEvent: jsonEvent);
                break;
              case "delete_note":
                event = DeleteNoteEvent.fromJson(jsonEvent: jsonEvent);
                break;
              default:
                throw Exception();
            }
            event.id = eventIdToFetch;

            // 1.3. then we add event to our local chain
            eventsBox.addEvent(event);

            // 1.4. and we update info
            localLastEventId = eventIdToFetch;
            localInfoAboutServer.lastEventId = localLastEventId;
            serversBox.setServer(localInfoAboutServer);

            // 2. we apply this history entry to our notes
            if(event is CreateNoteEvent) {
              if(notesBox.getNote(event.noteId) == null) {
                // create new note
                NoteV1 newNote = NoteV1(
                    id: event.noteId,
                    createdAt: event.noteCreatedAt,
                    modifiedAt: event.noteCreatedAt,
                    title: null,
                    text: null
                );
                notesBox.addNote(newNote);
              }
            } else if(event is UpdateNoteEvent) {
              NoteV1? note = notesBox.getNote(event.noteId);
              if(note != null) {
                // check if local note update event is newer than note's modifiedAt
                if(note.modifiedAt.isAfter(event.noteUpdatedAt)) {
                  List<EventV1> noteEvents = eventsBox.getEventsOfNote(note.id);

                  for (EventV1 noteEvent in noteEvents) {
                    // recreate event from the start
                    if(noteEvent.type == "create_note") {
                      noteEvent = noteEvent as CreateNoteEvent;
                      note.createdAt = noteEvent.noteCreatedAt;
                      note.modifiedAt = noteEvent.noteCreatedAt;
                    } else if(noteEvent.type == "update_note") {
                      noteEvent = noteEvent as UpdateNoteEvent;
                      if (noteEvent.noteTitle != null) note.title = noteEvent.noteTitle;
                      if (noteEvent.noteText != null) note.text = noteEvent.noteText;
                      note.modifiedAt = noteEvent.noteUpdatedAt;
                    } else if(noteEvent.type == "delete_note") {
                      noteEvent = noteEvent as DeleteNoteEvent;
                      note.modifiedAt = noteEvent.noteDeletedAt;
                      note.deleted = true;
                    }
                  }
                } else {
                  if(event.noteTitle != null) note.title = event.noteTitle;
                  if(event.noteText != null) note.text = event.noteText;
                  note.modifiedAt = event.noteUpdatedAt;
                }
                notesBox.updateNote(note);
              }
            } else if(event is DeleteNoteEvent) {
              NoteV1 note = notesBox.getNote(event.noteId)!;
              if(!note.deleted) {
                notesBox.updateNote(note
                  ..deleted = true
                  ..modifiedAt = event.noteDeletedAt);
              }
            }

            eventsBox.setEventAppliedToTrue(event);

            mainSendPort.send("pulledOne.new");
          } on BeshenceVaultException catch(e) {
            print("error while pulling:");
            print(e.httpCode);
            print(e.name);
            print(e.description);
            mainSendPort.send("pulledOne.error");
          }
          break;
        case "pushOne":
          try {
            EventV1? eventToUpload = eventsBox.getNotUploadedEvent();
            if(eventToUpload == null) {
              mainSendPort.send("pushedOne.noNew");
              return;
            }

            ServerV1? localInfoAboutServer = serversBox.getServer();
            if (localInfoAboutServer == null) return;

            BeshenceVault vault = BeshenceVault(
                address: localInfoAboutServer.address,
                token: localInfoAboutServer.token);
            final BeshenceChain chain = vault.getChain("notes");

            String eventId = await chain.postEvent({
              "request_id": Uuid().v4(),
              "type": eventToUpload.type,
              "v": eventToUpload.v,
              "data": EventV1.convertStringToJSON(eventToUpload.data),
              if (localInfoAboutServer.lastEventId != null) "prev": localInfoAboutServer.lastEventId
            });

            serversBox.setServer(localInfoAboutServer..lastEventId = eventId);
            eventsBox.setEventId(eventToUpload.objectBoxId, eventId);
            mainSendPort.send("pushedOne.new");
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