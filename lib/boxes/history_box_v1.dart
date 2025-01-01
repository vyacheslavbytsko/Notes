import 'package:objectbox/objectbox.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../objectbox.g.dart';

class HistoryBoxV1 {
  late final Store _store;
  late final Box<HistoryEntryV1> _historyBox;

  HistoryBoxV1._create(this._store) {
    _historyBox = Box<HistoryEntryV1>(_store);
  }

  static Future<HistoryBoxV1> create() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final storeDir = join(docsDir.path, "notes_historybox_v1");
    final Store store;
    if (Store.isOpen(storeDir)) {
      store = Store.attach(getObjectBoxModel(), storeDir);
    } else {
      store = await openStore(directory: storeDir);
    }
    return HistoryBoxV1._create(store);
  }

  List<HistoryEntryV1> getAllEntries() => _historyBox.getAll();

  List<HistoryEntryV1> getAllEntriesSorted() =>
      (_historyBox.query()
        ..order(HistoryEntryV1_.noteModifiedAt)).build().find();

  HistoryEntryV1? getEntryByEventId(String eventId) =>
      (_historyBox.query(HistoryEntryV1_.chainEventId.equals(eventId)))
          .build()
          .findFirst();

  void addEntry(HistoryEntryV1 entry) {
    assert (!(entry.chainEventId != null &&
        getEntryByEventId(entry.chainEventId!) != null));
    _historyBox.put(entry, mode: PutMode.insert);
  }

  void setEntryAppliedToTrue(HistoryEntryV1 entry) =>
      _historyBox.put(entry..applied = true, mode: PutMode.update);

  void setEntryEventId(HistoryEntryV1 entry, String eventId) =>
      _historyBox.put(entry..chainEventId = eventId, mode: PutMode.update);

  List<HistoryEntryV1> getUpdatesFromTimestamp(String noteId,
      DateTime timestamp) => (_historyBox.query(
      HistoryEntryV1_.type.equals("update_note").and(
          HistoryEntryV1_.noteModifiedAt.greaterOrEqualDate(timestamp)).and(HistoryEntryV1_.noteId.equals(noteId)))
    ..order(HistoryEntryV1_.noteModifiedAt)).build().find();

  List<HistoryEntryV1> getAllNotAppliedEntries() =>
      (_historyBox.query(HistoryEntryV1_.applied.equals(false))
        ..order(HistoryEntryV1_.noteModifiedAt)).build().find();

  List<HistoryEntryV1> getAllNotUploadedEntries() =>
      (_historyBox.query(HistoryEntryV1_.chainEventId.isNull())
        ..order(HistoryEntryV1_.noteModifiedAt)).build().find();

  HistoryEntryV1? getFirstNotUploadedEntry() =>
      (_historyBox.query(HistoryEntryV1_.chainEventId.isNull())
        ..order(HistoryEntryV1_.noteModifiedAt)).build().findFirst();

}

@Entity()
class HistoryEntryV1 {
  @Id()
  int objectBoxId;
  String noteId;
  String type;
  String? noteTitle;
  String? noteText;
  DateTime? noteCreatedAt;
  DateTime noteModifiedAt;
  String? chainEventId;
  bool applied;

  HistoryEntryV1({this.objectBoxId = 0, required this.noteId, required this.type, required this.noteTitle, required this.noteText, required this.noteCreatedAt, required this.noteModifiedAt, required this.chainEventId, required this.applied});
}