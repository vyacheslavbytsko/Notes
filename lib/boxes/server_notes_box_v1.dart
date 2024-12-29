import 'package:objectbox/objectbox.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../objectbox.g.dart';

class ServerNotesBoxV1 {
  late final Store _store;
  late final Box<ServerNoteV1> _serverNotesBox;

  ServerNotesBoxV1._create(this._store) {
    _serverNotesBox = Box<ServerNoteV1>(_store);
  }

  static Future<ServerNotesBoxV1> create() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final storeDir = join(docsDir.path, "notes_servernotesbox_v1");
    final Store store;
    if (Store.isOpen(storeDir)) {
      store = Store.attach(getObjectBoxModel(), storeDir);
    } else {
      store = await openStore(directory: storeDir);
    }
    return ServerNotesBoxV1._create(store);
  }

  List<ServerNoteV1> getAllServerNotes() => _serverNotesBox.getAll();
  void addServerNote(ServerNoteV1 note) => _serverNotesBox.put(note, mode: PutMode.insert);
  void updateServerNote(ServerNoteV1 note) => _serverNotesBox.put(note, mode: PutMode.update);
  ServerNoteV1 getServerNote(String id) => _serverNotesBox.query(ServerNoteV1_.id.equals(id)).build().find()[0];
  void deleteServerNote(ServerNoteV1 note) => _serverNotesBox.remove(note.objectBoxId);
}

@Entity()
class ServerNoteV1 {
  @Id()
  int objectBoxId;
  @Unique()
  String id;
  DateTime createdAt;
  DateTime modifiedAt;
  String? title;
  String? text;

  ServerNoteV1({this.objectBoxId = 0, required this.id, required this.createdAt, required this.modifiedAt, required this.title, required this.text});
}
