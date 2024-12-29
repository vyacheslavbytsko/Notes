import 'dart:isolate';

import 'package:beshence_vault/beshence_vault.dart';
import 'package:uuid/uuid.dart';

import '../boxes/local_notes_box_v1.dart';
import '../boxes/server_notes_box_v1.dart';
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
            notesChangeNotifier.updateNotes();
          }
          print("PULLED. SENDING PUSH");
          isolateSendPort.send("push");
          break;
        case "pushed":
          print("PUSHED. SENDING PULL");
          Future.delayed(Duration(seconds: 3), () => isolateSendPort.send("pull"));
      }
    });

    isolateSendPort.send("ping");
  }

  @override
  Future<void> isolate(ReceivePort isolateReceivePort, SendPort mainSendPort) async {
    ServersBoxV1 serversBox = await ServersBoxV1.create();
    ServerNotesBoxV1 serverNotesBox = await ServerNotesBoxV1.create();
    LocalNotesBoxV1 localNotesBox = await LocalNotesBoxV1.create();

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
            final String? localLastEventId = localInfoAboutServer.lastEventId;

            BeshenceVault vault = BeshenceVault(
                address: localInfoAboutServer.address,
                token: localInfoAboutServer.token);
            final BeshenceChain chain = vault.getChain("notes");
            final String? serverLastEventId = await chain.lastEventId;

            if (serverLastEventId != localLastEventId &&
                serverLastEventId != null) {
              Map<String, dynamic> newEvents = {};
              List<String> newEventsIds = [serverLastEventId];

              // fetching all events; serverLastEventId -> localLastEventId
              // sooner we'll be able to do localLastEventId -> serverLastEventId
              String? eventIdToFetch = serverLastEventId;
              while (eventIdToFetch != localLastEventId &&
                  eventIdToFetch != null) {
                final event = await chain.getEvent(eventIdToFetch);
                newEvents[eventIdToFetch] = event;
                eventIdToFetch = event["parent"];
                if (eventIdToFetch != null) newEventsIds.add(eventIdToFetch);
              }
              newEventsIds.remove(localLastEventId);

              // we've fetched all events
              // now we're going to update serverNotesBox according to events
              // we go localLastEventId -> serverLastEventId
              newEventsIds = newEventsIds.reversed.toList();
              for (String newEventId in newEventsIds) {
                dynamic newEvent = newEvents[newEventId];
                print("for $newEventId: ${newEvent["type"]}");
                switch (newEvent["type"]) {
                  case "create_note":
                    serverNotesBox.addServerNote(ServerNoteV1(
                        id: newEvent["data"]["note_id"],
                        createdAt: DateTime.fromMillisecondsSinceEpoch(
                            newEvent["data"]["created_at"] * 1000),
                        modifiedAt: DateTime.fromMillisecondsSinceEpoch(
                            newEvent["data"]["modified_at"] * 1000),
                        title: newEvent["data"]["title"],
                        text: newEvent["data"]["text"]));
                    print("pull: create_note ${newEvent["data"]["note_id"]}");
                    break;
                  case "update_note":
                    var note = serverNotesBox.getServerNote(
                        newEvent["data"]["note_id"]);
                    note.title = newEvent["data"].containsKey("title") ? newEvent["data"]["title"] : note.title;
                    note.text = newEvent["data"].containsKey("text") ? newEvent["data"]["text"] : note.text;
                    note.modifiedAt =
                    newEvent["data"]["modified_at"] != null ? DateTime
                        .fromMillisecondsSinceEpoch(
                        newEvent["data"]["modified_at"] * 1000) : note
                        .modifiedAt;
                    serverNotesBox.updateServerNote(note);
                    print("pull: update_note ${newEvent["data"]["note_id"]}");
                    break;
                  case "delete_note":
                    serverNotesBox.deleteServerNote(
                        serverNotesBox.getServerNote(
                            newEvent["data"]["note_id"]));
                    print("pull: delete_note ${newEvent["data"]["note_id"]}");
                    break;
                }
              }

              // we've updated snapshot of server info
              // now we update server last event id
              localInfoAboutServer.lastEventId = serverLastEventId;
              serversBox.setServer(localInfoAboutServer);
              
              // now we update local database
              List<ServerNoteV1> serverNotes = serverNotesBox.getAllServerNotes();
              Map<String, LocalNoteV1> localNotesMap = {for(var localNote in localNotesBox.getAllLocalNotes()) localNote.id: localNote};
              for(ServerNoteV1 serverNote in serverNotes) {
                LocalNoteV1? localNote = localNotesMap[serverNote.id];
                if(localNote == null) {
                  localNotesBox.addLocalNote(LocalNoteV1(id: serverNote.id, createdAt: serverNote.createdAt, modifiedAt: serverNote.modifiedAt, title: serverNote.title, text: serverNote.text));
                } else {
                  if(serverNote.modifiedAt.isAfter(localNote.modifiedAt)) {
                    localNote.modifiedAt = serverNote.modifiedAt;
                    localNote.title = serverNote.title;
                    localNote.text = serverNote.text;
                    localNotesBox.updateLocalNote(localNote);
                  }
                  localNotesMap.remove(localNote.id);
                }
              }
              for(LocalNoteV1 localNote in localNotesMap.values) {
                localNotesBox.deleteLocalNote(localNote);
              }
              mainSendPort.send("pulled.new");
            } else {
              mainSendPort.send("pulled.nonew");
            }
          } on BeshenceVaultException catch(e) {
            print("error while pulling:");
            print(e.httpCode);
            print(e.name);
            print(e.description);
            mainSendPort.send("pulled.error");
          }
          break;
        case "push":
          try {
            List<LocalNoteV1> localNotes = localNotesBox.getAllLocalNotes();
            Map<String, ServerNoteV1> serverNotesMap = {
              for(ServerNoteV1 serverNote in serverNotesBox
                  .getAllServerNotes()) serverNote.id: serverNote
            };

            ServerV1? localInfoAboutServer = serversBox.getServer();
            if (localInfoAboutServer == null) return;

            BeshenceVault vault = BeshenceVault(
                address: localInfoAboutServer.address,
                token: localInfoAboutServer.token);
            final BeshenceChain chain = vault.getChain("notes");
            //print("serverLastEventId $serverLastEventId");

            for (LocalNoteV1 localNote in localNotes) {
              ServerNoteV1? serverNote = serverNotesMap[localNote.id];
              if (serverNote == null) {
                //if(!(localNote.title == null && localNote.text == null)) continue;
                final String? serverLastEventId = await chain.lastEventId;
                String eventId = await chain.postEvent({
                  "request_id": Uuid().v4(),
                  "type": "create_note",
                  "v": "v1",
                  "data": {
                    "note_id": localNote.id,
                    "created_at": localNote.createdAt.millisecondsSinceEpoch ~/
                        1000,
                    "modified_at": localNote.modifiedAt
                        .millisecondsSinceEpoch ~/ 1000,
                    "title": localNote.title,
                    "text": localNote.text
                  },
                  if (serverLastEventId != null) "parent": serverLastEventId
                });
                serverNotesBox.addServerNote(ServerNoteV1(id: localNote.id, createdAt: DateTime.fromMillisecondsSinceEpoch((localNote.createdAt.millisecondsSinceEpoch ~/ 1000) * 1000), modifiedAt: DateTime.fromMillisecondsSinceEpoch((localNote.modifiedAt.millisecondsSinceEpoch ~/ 1000) * 1000), title: localNote.title, text: localNote.text));
                localInfoAboutServer.lastEventId = eventId;
                serversBox.setServer(localInfoAboutServer);
                print("pushed: create_note $eventId");
                //mainSendPort.send("pushed.new");
                //return;
              } else {
                if (serverNote.modifiedAt.isBefore(localNote.modifiedAt)) {
                  //print("2");
                  final String? serverLastEventId = await chain.lastEventId;
                  String eventId = await chain.postEvent({
                    "request_id": Uuid().v4(),
                    "type": "update_note",
                    "v": "v1",
                    "data": {
                      "note_id": localNote.id,
                      "modified_at": localNote.modifiedAt
                          .millisecondsSinceEpoch ~/ 1000,
                      if(serverNote.title != localNote.title) "title": localNote
                          .title,
                      if(serverNote.text != localNote.text) "text": localNote
                          .text
                    },
                    if (serverLastEventId != null) "parent": serverLastEventId
                  });
                  serverNote.modifiedAt = DateTime.fromMillisecondsSinceEpoch((localNote.modifiedAt.millisecondsSinceEpoch ~/ 1000) * 1000);
                  if(serverNote.title != localNote.title) serverNote.title = localNote.title;
                  if(serverNote.text != localNote.text) serverNote.text = localNote.text;
                  serverNotesBox.updateServerNote(serverNote);
                  localInfoAboutServer.lastEventId = eventId;
                  serversBox.setServer(localInfoAboutServer);
                  print("pushed: update_note $eventId");
                  //mainSendPort.send("pushed.new");
                  //return;
                }
              }
              serverNotesMap.remove(localNote.id);
            }
            for (ServerNoteV1 serverNote in serverNotesMap.values) {
              final String? serverLastEventId = await chain.lastEventId;
              String eventId = await chain.postEvent({
                "request_id": Uuid().v4(),
                "type": "delete_note",
                "v": "v1",
                "data": {
                  "note_id": serverNote.id
                },
                if (serverLastEventId != null) "parent": serverLastEventId
              });
              serverNotesBox.deleteServerNote(serverNote);
              localInfoAboutServer.lastEventId = eventId;
              serversBox.setServer(localInfoAboutServer);
              print("pushed: delete_note $eventId");
              //print("3");
              //mainSendPort.send("pushed.new");
              //return;
            }
            //print("4");
            mainSendPort.send("pushed");
          } on BeshenceVaultException catch(e) {
            print("error while pushing:");
            print(e.httpCode);
            print(e.name);
            print(e.description);
            mainSendPort.send("pushed");
          }
          break;
      }
    });
  }
}