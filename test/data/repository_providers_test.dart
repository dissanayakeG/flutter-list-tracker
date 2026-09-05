import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_tracker/data/local/app_database.dart';
import 'package:list_tracker/data/repository/category_repository.dart';
import 'package:list_tracker/data/repository/entry_repository.dart';
import 'package:list_tracker/data/repository/list_repository.dart';
import 'package:list_tracker/data/repository/repository_providers.dart';
import 'package:list_tracker/data/repository/transfer_repository.dart';

void main() {
  test('category streams can use only a category repository override', () {
    final repository = _CategoryRepository();
    final container = ProviderContainer(
      overrides: [categoryRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    container.read(categoriesProvider);
    expect(repository.watchRequests, 1);
  });

  test('list streams can use only a list repository override', () {
    final repository = _ListRepository();
    final container = ProviderContainer(
      overrides: [listRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    container.read(listSummariesProvider);
    container.read(listDetailProvider(1));
    expect(repository.watchListsRequests, 1);
    expect(repository.watchListRequests, 1);
  });

  test('entry streams can use only an entry repository override', () {
    final repository = _EntryRepository();
    final container = ProviderContainer(
      overrides: [entryRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    container.read(entriesProvider(1));
    expect(repository.watchRequests, 1);
  });

  test('transfer repository can be overridden without other repositories', () {
    final repository = _TransferRepository();
    final container = ProviderContainer(
      overrides: [transferRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    expect(container.read(transferRepositoryProvider), same(repository));
  });
}

class _CategoryRepository implements CategoryRepository {
  var watchRequests = 0;

  @override
  Stream<List<Category>> watchCategories() {
    watchRequests += 1;
    return const Stream.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ListRepository implements ListRepository {
  var watchListsRequests = 0;
  var watchListRequests = 0;

  @override
  Stream<List<ListWithCategory>> watchLists() {
    watchListsRequests += 1;
    return const Stream.empty();
  }

  @override
  Stream<ListWithCategory?> watchList(int id) {
    watchListRequests += 1;
    return const Stream.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EntryRepository implements EntryRepository {
  var watchRequests = 0;

  @override
  Stream<List<Entry>> watchEntries(int listId) {
    watchRequests += 1;
    return const Stream.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TransferRepository implements TransferRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
