import 'package:objectbox/objectbox.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../objectbox.g.dart';

class NotesBoxV1 {
  late final Store _store;
  late final Box<NoteV1> _notesBox;

  NotesBoxV1._create(this._store) {
    _notesBox = Box<NoteV1>(_store);
  }

  static Future<NotesBoxV1> create() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final storeDir = join(docsDir.path, "notes_notesbox_v1");
    final Store store;
    if (Store.isOpen(storeDir)) {
      store = Store.attach(getObjectBoxModel(), storeDir);
    } else {
      store = await openStore(directory: storeDir);
    }
    return NotesBoxV1._create(store);
  }

  List<NoteV1> getAllNotes() => (_notesBox.query(NoteV1_.deleted.equals(false))).build().find();

  List<NoteV1> getAllNotesSorted() =>
      (_notesBox.query(NoteV1_.deleted.equals(false))
        ..order(NoteV1_.modifiedAt, flags: Order.descending)).build().find();

  void addNote(NoteV1 note) => _notesBox.put(note, mode: PutMode.insert);

  void updateNote(NoteV1 note) => _notesBox.put(note, mode: PutMode.update);

  NoteV1? getNote(String id) {
    var result = _notesBox.query(NoteV1_.id.equals(id)).build().find();
    if (result.isNotEmpty) return result[0];
    return null;
  }

  int get notesLength => _notesBox.count();
}

@Entity()
class NoteV1 {
  @Id()
  int objectBoxId;
  @Unique()
  String id;
  DateTime createdAt;
  DateTime modifiedAt;
  String? title;
  String? text;
  bool deleted;

  NoteV1({this.objectBoxId = 0, required this.id, required this.createdAt, required this.modifiedAt, required this.title, required this.text, this.deleted = false});
}
