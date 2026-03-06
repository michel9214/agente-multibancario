import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

/// Cached entities for offline access
class CachedEntities extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get color => text().withDefault(const Constant('#1976D2'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get cachedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Pending operations queue for offline sync
class PendingOperations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get operationType => text()(); // OPEN_SHIFT, CLOSE_SHIFT, ADD_MOVEMENT
  TextColumn get payload => text()(); // JSON serialized data
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('PENDING'))(); // PENDING, SYNCING, FAILED
  TextColumn get errorMessage => text().nullable()();
}

/// Cached active shift data for offline display
class CachedShifts extends Table {
  TextColumn get id => text()();
  TextColumn get jsonData => text()(); // Full shift JSON
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get cachedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [CachedEntities, PendingOperations, CachedShifts])
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());

  static AppDatabase? _instance;
  static AppDatabase get instance {
    _instance ??= AppDatabase._();
    return _instance!;
  }

  @override
  int get schemaVersion => 1;

  // === Entities cache ===

  Future<void> cacheEntities(List<CachedEntitiesCompanion> entities) async {
    await batch((batch) {
      batch.deleteWhere(cachedEntities, (t) => const Constant(true));
      batch.insertAll(cachedEntities, entities);
    });
  }

  Future<List<CachedEntity>> getCachedEntities({bool activeOnly = true}) {
    final query = select(cachedEntities);
    if (activeOnly) {
      query.where((t) => t.isActive.equals(true));
    }
    query.orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.get();
  }

  // === Active shift cache ===

  Future<void> cacheActiveShift(String id, String jsonData) async {
    await into(cachedShifts).insertOnConflictUpdate(CachedShiftsCompanion(
      id: Value(id),
      jsonData: Value(jsonData),
      isActive: const Value(true),
      cachedAt: Value(DateTime.now()),
    ));
  }

  Future<CachedShift?> getActiveShiftCache() {
    final query = select(cachedShifts)
      ..where((t) => t.isActive.equals(true));
    return query.getSingleOrNull();
  }

  Future<void> clearActiveShiftCache() async {
    await (delete(cachedShifts)..where((t) => t.isActive.equals(true))).go();
  }

  // === Pending operations queue ===

  Future<int> addPendingOperation(String type, String payload) {
    return into(pendingOperations).insert(PendingOperationsCompanion(
      operationType: Value(type),
      payload: Value(payload),
      createdAt: Value(DateTime.now()),
    ));
  }

  Future<List<PendingOperation>> getPendingOperations() {
    final query = select(pendingOperations)
      ..where((t) => t.status.equals('PENDING'))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.get();
  }

  Future<void> markOperationSyncing(int id) async {
    await (update(pendingOperations)..where((t) => t.id.equals(id)))
        .write(const PendingOperationsCompanion(status: Value('SYNCING')));
  }

  Future<void> markOperationFailed(int id, String error) async {
    await (update(pendingOperations)..where((t) => t.id.equals(id)))
        .write(PendingOperationsCompanion(
      status: const Value('FAILED'),
      errorMessage: Value(error),
      retryCount: const Value(1), // Will increment in sync
    ));
  }

  Future<void> removeOperation(int id) async {
    await (delete(pendingOperations)..where((t) => t.id.equals(id))).go();
  }

  Future<int> pendingCount() async {
    final count = countAll();
    final query = selectOnly(pendingOperations)
      ..where(pendingOperations.status.equals('PENDING'))
      ..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'agente_multibanco.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
