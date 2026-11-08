import 'package:sqflite/sqflite.dart';

import 'schema.dart';

/// The only class that talks to the database (SQLite on the device).
///
/// The app opens it once at startup and shares the instance, so the
/// connection stays open. Every statement is built from identifiers that
/// are checked against a whitelist pattern, and every value is sent as a
/// parameter (`?`). Values are never concatenated into SQL text.
class DatabaseConnector {
  DatabaseConnector(this._executor);

  /// Opens (and on first launch creates) the database at [path].
  ///
  /// [factory] defaults to sqflite's global factory, which `main` points at
  /// the WebAssembly implementation on the web.
  static Future<DatabaseConnector> open({
    DatabaseFactory? factory,
    String path = 'freecheck.db',
  }) async {
    final db = await (factory ?? databaseFactory).openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          for (final statement in schema) {
            await db.execute(statement);
          }
        },
      ),
    );
    return DatabaseConnector(db);
  }

  /// The [Database] for the shared instance, or a [Transaction] for
  /// instances handed out by [transaction].
  final DatabaseExecutor _executor;

  static final _identifier = RegExp(r'^[a-z_][a-z0-9_]*$');
  static final _orderBy = RegExp(r'^[a-z_][a-z0-9_]*( (ASC|DESC))?$');

  /// Returns true when at least one row in [table] matches [where].
  Future<bool> checkDuplicate(String table, Map<String, Object?> where) async {
    final params = <Object?>[];
    final sql =
        'SELECT EXISTS (SELECT 1 FROM ${_id(table)}'
        '${_where(where, params)}) AS found';
    final rows = await _executor.rawQuery(sql, params);
    return rows.first['found'] == 1;
  }

  /// Inserts [data] into [table] and returns the new row's id ([idColumn]
  /// is the table's INTEGER PRIMARY KEY, which SQLite returns as the rowid).
  Future<int> save(
    String table,
    Map<String, Object?> data, {
    String idColumn = 'id',
  }) async {
    if (data.isEmpty) throw ArgumentError('data must not be empty');
    _id(idColumn);
    final columns = data.keys.map(_id).join(', ');
    final placeholders = List.filled(data.length, '?').join(', ');
    return _executor.rawInsert(
      'INSERT INTO ${_id(table)} ($columns) VALUES ($placeholders)',
      data.values.map(_value).toList(),
    );
  }

  /// Returns rows from [table] matching [where].
  ///
  /// A [where] value that is a [List] becomes `IN (...)`; a `null` value
  /// becomes `IS NULL`. [columns] may hold aggregate expressions written by
  /// controllers (never user input), e.g. `AVG(score) AS avg_score`.
  Future<List<Map<String, dynamic>>> select(
    String table,
    Map<String, Object?> where, {
    List<String>? columns,
    String? orderBy,
  }) async {
    final params = <Object?>[];
    final cols = columns == null ? '*' : columns.join(', ');
    var sql = 'SELECT $cols FROM ${_id(table)}${_where(where, params)}';
    if (orderBy != null) {
      if (!_orderBy.hasMatch(orderBy)) {
        throw ArgumentError.value(orderBy, 'orderBy');
      }
      sql += ' ORDER BY $orderBy';
    }
    return query(sql, params);
  }

  /// Runs [sql] written in code (joins, aggregates) and returns its rows.
  /// Values must be passed in [params] and referenced as `?`.
  Future<List<Map<String, dynamic>>> query(
    String sql,
    List<Object?> params,
  ) async {
    final rows = await _executor.rawQuery(sql, params.map(_value).toList());
    return [for (final row in rows) Map<String, dynamic>.of(row)];
  }

  /// Sets [data] on every row of [table] matching [where].
  Future<void> update(
    String table,
    Map<String, Object?> where,
    Map<String, Object?> data,
  ) async {
    if (data.isEmpty) throw ArgumentError('data must not be empty');
    if (where.isEmpty) throw ArgumentError('update requires a where clause');
    final params = <Object?>[];
    final sets = data.entries
        .map((e) {
          params.add(_value(e.value));
          return '${_id(e.key)} = ?';
        })
        .join(', ');
    await _executor.rawUpdate(
      'UPDATE ${_id(table)} SET $sets${_where(where, params)}',
      params,
    );
  }

  /// Deletes every row of [table] matching [where].
  Future<void> delete(String table, Map<String, Object?> where) async {
    if (where.isEmpty) throw ArgumentError('delete requires a where clause');
    final params = <Object?>[];
    await _executor.rawDelete(
      'DELETE FROM ${_id(table)}${_where(where, params)}',
      params,
    );
  }

  /// Runs [action] inside one transaction. The [DatabaseConnector] passed to
  /// [action] must be used for every statement that belongs to it.
  Future<void> transaction(
    Future<void> Function(DatabaseConnector tx) action,
  ) async {
    final executor = _executor;
    if (executor is! Database) {
      // Already inside a transaction.
      return action(this);
    }
    await executor.transaction((txn) => action(DatabaseConnector(txn)));
  }

  String _id(String name) {
    if (!_identifier.hasMatch(name)) {
      throw ArgumentError.value(name, 'identifier', 'Invalid SQL identifier');
    }
    return name;
  }

  String _where(Map<String, Object?> where, List<Object?> params) {
    if (where.isEmpty) return '';
    final parts = where.entries.map((e) {
      final column = _id(e.key);
      final value = e.value;
      if (value == null) return '$column IS NULL';
      if (value is List) {
        if (value.isEmpty) return '0';
        params.addAll(value.map(_value));
        return '$column IN (${List.filled(value.length, '?').join(', ')})';
      }
      params.add(_value(value));
      return '$column = ?';
    });
    return ' WHERE ${parts.join(' AND ')}';
  }

  /// SQLite stores booleans as 0/1 and timestamps as ISO-8601 text in whole
  /// seconds (TIMESTAMP(0)).
  static Object? _value(Object? value) => switch (value) {
    bool() => value ? 1 : 0,
    DateTime() => value.toIso8601String().replaceFirst(RegExp(r'\.\d+'), ''),
    _ => value,
  };
}
