import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'pages/page.dart';
import 'services/database_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // On the web SQLite runs as WebAssembly (web/sqlite3.wasm) and keeps the
  // database in the browser's IndexedDB. One user, so no worker is needed.
  if (kIsWeb) databaseFactory = databaseFactoryFfiWebNoWebWorker;
  await initializeDateFormatting('th');

  // Opened once; every page and controller shares this connection.
  final db = await DatabaseService.open();
  runApp(buildApp(db));
}
