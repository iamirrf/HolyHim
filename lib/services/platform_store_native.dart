import 'package:holyher/services/durable_store.dart';
import 'package:holyher/services/local_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

LocalStore createPlatformStore(Ref ref, String account) => SqliteLocalStore(
    account: account,
    open: ref.watch(localDatabaseProvider),
    legacy: PreferencesStore(prefix: '$account:'));
Future<void> eraseBrowserAccount(String account) async {}
void releaseBrowserAccount(String account) {}
