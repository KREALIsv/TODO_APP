import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:todos_app/features/notes/data/tags_repository.dart';
import 'package:todos_app/features/notes/domain/default_tags.dart';

void main() {
  late Directory tempDir;
  late TagsRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tags_repo_test_');
    Hive.init(tempDir.path);
    final box = await Hive.openBox<dynamic>(
      'tags_test_${DateTime.now().microsecondsSinceEpoch}',
    );
    repo = TagsRepository.instance;
    await repo.initWithBox(box);
    await repo.clear();
    await repo.ensureDefaults();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('init seeds default tags', () {
    expect(repo.getAll(), containsAll(kDefaultTags));
    expect(repo.getAll().length, kDefaultTags.length);
  });

  test('ensureTags grows the catalog without duplicates', () async {
    await repo.ensureTags(['Urgente', 'Gym', 'gym', '  Viaje  ']);

    final all = repo.getAll();
    expect(all.where((t) => t.toLowerCase() == 'urgente').length, 1);
    expect(all, contains('Gym'));
    expect(all, isNot(contains('gym')));
    expect(all, contains('Viaje'));
    expect(all.length, kDefaultTags.length + 2);
  });

  test('remove deletes from catalog only', () async {
    await repo.ensureTags(['Temporal']);
    await repo.remove('Temporal');
    expect(repo.getAll(), isNot(contains('Temporal')));
    expect(repo.getAll(), containsAll(kDefaultTags));
  });

  test('ensureDefaults is idempotent', () async {
    await repo.ensureDefaults();
    await repo.ensureDefaults();
    expect(repo.getAll().length, kDefaultTags.length);
  });
}
