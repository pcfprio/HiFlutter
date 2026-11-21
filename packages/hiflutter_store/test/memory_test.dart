import 'package:hiflutter_store/hiflutter_store.dart';

import 'contract/key_value_contract.dart';

void main() {
  runKeyValueStoreContract('memory', () async => HiKeyValueStore.memory());
}
