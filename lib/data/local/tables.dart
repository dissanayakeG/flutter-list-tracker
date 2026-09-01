import 'package:drift/drift.dart';

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().customConstraint('UNIQUE')();
}

class ListModels extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get categoryId =>
      integer().references(Categories, #id, onDelete: KeyAction.restrict)();

  TextColumn get name => text()();

  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get listId =>
      integer().references(ListModels, #id, onDelete: KeyAction.cascade)();

  TextColumn get content => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
