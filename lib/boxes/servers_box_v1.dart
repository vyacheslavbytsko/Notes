import 'package:objectbox/objectbox.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../objectbox.g.dart';

class ServersBoxV1 {
  late final Store _store;
  late final Box<ServerV1> _serversBox;

  ServersBoxV1._create(this._store) {
    _serversBox = Box<ServerV1>(_store);
  }

  static Future<ServersBoxV1> create() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final storeDir = join(docsDir.path, "notes_serversbox_v1");
    final Store store;
    if (Store.isOpen(storeDir)) {
      store = Store.attach(getObjectBoxModel(), storeDir);
    } else {
      store = await openStore(directory: storeDir);
    }
    return ServersBoxV1._create(store);
  }

  void setServer(ServerV1 server) => _serversBox.put(server);
  ServerV1? getServer() => _serversBox.count() > 0 ? _serversBox.getAll()[0] : null;

}

@Entity()
class ServerV1 {
  @Id()
  int objectBoxId;
  @Unique()
  String address;
  String token;
  @Unique()
  int order;
  String? lastEventId;

  ServerV1({this.objectBoxId = 0, required this.address, required this.token, required this.order, required this.lastEventId});
}