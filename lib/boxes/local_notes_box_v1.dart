import 'package:objectbox/objectbox.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../objectbox.g.dart';

class LocalNotesBoxV1 {
  late final Store _store;
  late final Box<LocalNoteV1> _localNotesBox;

  LocalNotesBoxV1._create(this._store) {
    _localNotesBox = Box<LocalNoteV1>(_store);
  }

  static Future<LocalNotesBoxV1> create() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final storeDir = join(docsDir.path, "notes_localnotesbox_v1");
    final Store store;
    if (Store.isOpen(storeDir)) {
      store = Store.attach(getObjectBoxModel(), storeDir);
    } else {
      store = await openStore(directory: storeDir);
    }
    return LocalNotesBoxV1._create(store);
  }

  List<LocalNoteV1> getAllLocalNotes() => _localNotesBox.getAll();
  List<LocalNoteV1> getAllLocalNotesSorted() => (_localNotesBox.query()..order(LocalNoteV1_.modifiedAt, flags: Order.descending)).build().find();
  void addLocalNote(LocalNoteV1 note) => _localNotesBox.put(note, mode: PutMode.insert);
  void updateLocalNote(LocalNoteV1 note) => _localNotesBox.put(note, mode: PutMode.update);
  LocalNoteV1? getLocalNote(String id) {
    var result = _localNotesBox.query(LocalNoteV1_.id.equals(id)).build().find();
    if(result.isNotEmpty) return result[0];
    return null;
  }
  void deleteLocalNote(LocalNoteV1 note) => _localNotesBox.remove(note.objectBoxId);
  int get localNotesLength => _localNotesBox.count();
}

@Entity()
class LocalNoteV1 {
  @Id()
  int objectBoxId;
  @Unique()
  String id;
  DateTime createdAt;
  DateTime modifiedAt;
  String? title;
  String? text;

  LocalNoteV1({this.objectBoxId = 0, required this.id, required this.createdAt, required this.modifiedAt, required this.title, required this.text});
}
