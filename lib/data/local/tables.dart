import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

final externalIdUuid = Uuid();

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get externalId =>
      text().unique().clientDefault(externalIdUuid.v4)();

  TextColumn get name => text().unique()();
}

class ListModels extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get externalId =>
      text().unique().clientDefault(externalIdUuid.v4)();

  IntColumn get categoryId =>
      integer().references(Categories, #id, onDelete: KeyAction.restrict)();

  TextColumn get name => text()();

  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get externalId =>
      text().unique().clientDefault(externalIdUuid.v4)();

  IntColumn get listId =>
      integer().references(ListModels, #id, onDelete: KeyAction.cascade)();

  TextColumn get content => text()();

  DateTimeColumn get date => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
