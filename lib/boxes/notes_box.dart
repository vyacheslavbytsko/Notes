import 'package:objectbox/objectbox.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../objectbox.g.dart';

class NotesBox {
  late final Store _store;
  late final Box<Note> _localNotesBox;

  NotesBox._create(this._store) {
    _localNotesBox = Box<Note>(_store);
  }

  static Future<NotesBox> create() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final storeDir = join(docsDir.path, "notesbox");
    final Store store;
    if (Store.isOpen(storeDir)) {
      store = Store.attach(getObjectBoxModel(), storeDir);
    } else {
      store = await openStore(directory: storeDir);
    }
    return NotesBox._create(store);
  }

  List<Note> getAllLocalNotes() => _localNotesBox.getAll();
  void addLocalNote(Note note) => _localNotesBox.put(note, mode: PutMode.insert);
  void updateLocalNote(Note note) => _localNotesBox.put(note, mode: PutMode.update);
  Note getLocalNote(String id) => _localNotesBox.query(Note_.id.equals(id)).build().find()[0];
}

@Entity()
class Note {
  @Id()
  int objectBoxId;
  @Unique()
  String id;
  DateTime modifiedAt;
  String title;
  String text;

  Note({this.objectBoxId = 0, required this.id, required this.modifiedAt, required this.title, required this.text});
}
