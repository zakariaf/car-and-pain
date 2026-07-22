import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder infra providers throw until overridden at bootstrap', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Riverpod wraps a create-time throw; assert the underlying
    // UnimplementedError (and its bootstrap hint) surfaces.
    void expectUnimplemented(void Function() read) {
      expect(
        read,
        throwsA(
          predicate<Object>(
            (e) =>
                e.toString().contains('UnimplementedError') &&
                e.toString().contains('bootstrap()'),
          ),
        ),
      );
    }

    expectUnimplemented(() => container.read(appDatabaseProvider));
    expectUnimplemented(() => container.read(secureKeyStoreProvider));
    expectUnimplemented(() => container.read(appDirsProvider));
    expectUnimplemented(() => container.read(appTimeZoneProvider));
  });

  test('diagnosticsRepository consumes the injected database via DI', () {
    final db = AppDatabase.memory();
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final repo = container.read(diagnosticsRepositoryProvider);
    expect(repo.databaseLabel(), 'car-and-pain schema v7');
  });
}
