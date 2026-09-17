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

class Languages extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get externalId =>
      text().unique().clientDefault(externalIdUuid.v4)();

  TextColumn get name => text().unique()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class VocabularyCategories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get externalId =>
      text().unique().clientDefault(externalIdUuid.v4)();

  TextColumn get name => text().unique()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class VocabularySubcategories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get externalId =>
      text().unique().clientDefault(externalIdUuid.v4)();

  IntColumn get categoryId => integer().references(
    VocabularyCategories,
    #id,
    onDelete: KeyAction.restrict,
  )();

  TextColumn get name => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {categoryId, name},
  ];
}

class VocabularyWords extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get externalId =>
      text().unique().clientDefault(externalIdUuid.v4)();

  IntColumn get languageId =>
      integer().references(Languages, #id, onDelete: KeyAction.restrict)();

  IntColumn get categoryId => integer().references(
    VocabularyCategories,
    #id,
    onDelete: KeyAction.restrict,
  )();

  IntColumn get subcategoryId => integer().nullable().references(
    VocabularySubcategories,
    #id,
    onDelete: KeyAction.restrict,
  )();

  TextColumn get word => text()();

  TextColumn get meaning => text()();

  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {languageId, categoryId, subcategoryId, word, meaning},
  ];
}

class AppPreferences extends Table {
  IntColumn get id => integer()();
  TextColumn get themeMode => text().withDefault(const Constant('dark'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
