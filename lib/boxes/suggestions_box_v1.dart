import 'package:objectbox/objectbox.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../objectbox.g.dart';

class SuggestionsBoxV1 {
  late final Store _store;
  late final Box<SuggestionV1> _suggestionsBox;

  SuggestionsBoxV1._create(this._store) {
    _suggestionsBox = Box<SuggestionV1>(_store);
  }

  static Future<SuggestionsBoxV1> create() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final storeDir = join(docsDir.path, "notes_suggestionsbox_v1");
    final Store store;
    if (Store.isOpen(storeDir)) {
      store = Store.attach(getObjectBoxModel(), storeDir);
    } else {
      store = await openStore(directory: storeDir);
    }
    return SuggestionsBoxV1._create(store);
  }

  SuggestionV1 getSuggestion(String name) {
    List<SuggestionV1> suggestion = (_suggestionsBox.query(SuggestionV1_.name.equals(name)).build()).find();
    if(suggestion.isEmpty) return SuggestionV1(name: name, data: null);
    return suggestion[0];
  }

  void setSuggestion(SuggestionV1 suggestion) => _suggestionsBox.put(suggestion);
}

@Entity()
class SuggestionV1 {
  @Id()
  int objectBoxId;
  @Unique()
  String name;
  String? data;

  SuggestionV1({this.objectBoxId = 0, required this.name, required this.data});
}
