import 'dart:convert';

import 'package:objectbox/objectbox.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../objectbox.g.dart';

class EventsBoxV1 {
  late final Store _store;
  late final Box<EventV1> _eventsBox;

  EventsBoxV1._create(this._store) {
    _eventsBox = Box<EventV1>(_store);
  }

  static Future<EventsBoxV1> create() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final storeDir = join(docsDir.path, "notes_eventsbox_v1");
    final Store store;
    if (Store.isOpen(storeDir)) {
      store = Store.attach(getObjectBoxModel(), storeDir);
    } else {
      store = await openStore(directory: storeDir);
    }
    return EventsBoxV1._create(store);
  }

  void addEvent(EventV1 entry) {
    _eventsBox.put(entry, mode: PutMode.insert);
  }

  void setEventAppliedToTrue(EventV1 event) =>
      _eventsBox.put(event..applied = true, mode: PutMode.update);

  List<EventV1> getEventsOfNote(String noteId) => _eventsBox.getAll()
      .where((event) => ["create_note", "update_note", "delete_note"].contains(event.type)).toList()
      .where((event) => EventV1.convertStringToJSON(event.data)["id"] == noteId).toList();

  // TODO: order by... what?
  EventV1? getNotUploadedEvent() =>
      (_eventsBox.query(EventV1_.id.isNull())).build().findFirst();

  void setEventId(int eventObjectBoxId, String eventId) => _eventsBox.put(_eventsBox.get(eventObjectBoxId)!..id = eventId, mode: PutMode.update);
}

@Entity()
class EventV1 {
  @Id()
  int objectBoxId;
  /// Do not fill this parameter if the event is not synced.
  String? id;
  String type;
  String v;
  String data;
  /// The time when server got this event. Do not confuse with the timestamps in `data` section.
  DateTime? timestamp;
  bool applied;
  bool get synced => id != null;

  static Map<String, dynamic> convertStringToJSON(String value) => jsonDecode(value);
  static String convertJSONToString(Map<String, dynamic> value) => jsonEncode(value);

  EventV1({
    this.objectBoxId = 0,
    this.id,
    required this.type,
    required this.v,
    required this.data,
    this.timestamp,
    required this.applied});
}

class DeleteNoteEvent extends EventV1 {
  DeleteNoteEvent({required String noteId, required DateTime noteDeletedAt, required super.applied}) : super(
      type: "delete_note", v: "v1",
      data: EventV1.convertJSONToString({
        "id": noteId,
        "deleted_at": noteDeletedAt.millisecondsSinceEpoch
      }));

  factory DeleteNoteEvent.fromJson({required Map<String, dynamic> jsonEvent}) => DeleteNoteEvent(
      noteId: jsonEvent["data"]["id"],
      noteDeletedAt: DateTime.fromMillisecondsSinceEpoch(jsonEvent["data"]["deleted_at"]),
      applied: false);

  String get noteId => EventV1.convertStringToJSON(super.data)["id"];
  DateTime get noteDeletedAt => DateTime.fromMillisecondsSinceEpoch(EventV1.convertStringToJSON(super.data)["deleted_at"]);
}

class UpdateNoteEvent extends EventV1 {

  UpdateNoteEvent({required String noteId, String? noteTitle, String? noteText, required DateTime noteUpdatedAt, required super.applied}) : super(
      type: "update_note", v: "v1",
      data: EventV1.convertJSONToString({
        "id": noteId,
        if(noteTitle != null) "title": noteTitle,
        if(noteText != null) "text": noteText,
        "updated_at": noteUpdatedAt.millisecondsSinceEpoch
      }));

  factory UpdateNoteEvent.fromJson({required Map<String, dynamic> jsonEvent}) => UpdateNoteEvent(
      noteId: jsonEvent["data"]["id"],
      noteTitle: jsonEvent["data"]["title"],
      noteText: jsonEvent["data"]["text"],
      noteUpdatedAt: DateTime.fromMillisecondsSinceEpoch(jsonEvent["data"]["updated_at"]),
      applied: false);

  String get noteId => EventV1.convertStringToJSON(super.data)["id"];
  String? get noteTitle => EventV1.convertStringToJSON(super.data)["title"];
  String? get noteText => EventV1.convertStringToJSON(super.data)["text"];
  DateTime get noteUpdatedAt => DateTime.fromMillisecondsSinceEpoch(EventV1.convertStringToJSON(super.data)["updated_at"]);

}

class CreateNoteEvent extends EventV1 {
  CreateNoteEvent({required String noteId, required DateTime noteCreatedAt, required super.applied}) : super(
      type: "create_note", v: "v1",
      data: EventV1.convertJSONToString({
        "id": noteId,
        "created_at": noteCreatedAt.millisecondsSinceEpoch
      }));

  factory CreateNoteEvent.fromJson({required Map<String, dynamic> jsonEvent}) => CreateNoteEvent(
      noteId: jsonEvent["data"]["id"],
      noteCreatedAt: DateTime.fromMillisecondsSinceEpoch(jsonEvent["data"]["created_at"]),
      applied: false);

  String get noteId => EventV1.convertStringToJSON(super.data)["id"];
  DateTime get noteCreatedAt => DateTime.fromMillisecondsSinceEpoch(EventV1.convertStringToJSON(super.data)["created_at"]);
}