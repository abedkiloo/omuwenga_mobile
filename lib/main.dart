import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'sync/application/connectivity_plus_monitor.dart';
import 'sync/data/app_database.dart';
import 'sync/data/secure_pii_key_store.dart';
import 'sync/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.file();
  final connectivity = ConnectivityPlusMonitor();
  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((ref) {
          ref.onDispose(db.close);
          return db;
        }),
        piiKeyStoreProvider.overrideWithValue(SecurePiiKeyStore()),
        connectivityMonitorProvider.overrideWith((ref) {
          ref.onDispose(connectivity.dispose);
          return connectivity;
        }),
      ],
      child: const CompleteByteApp(),
    ),
  );
}
