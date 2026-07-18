import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:todos_app/features/notes/data/tags_repository.dart';
import 'package:todos_app/features/notes/domain/default_tags.dart';
import 'package:todos_app/features/notes/domain/tag_colors.dart';

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

  test('ensureTags assigns and remembers colors', () async {
    await repo.ensureTags(['Gym']);
    final id = repo.getColorId('Gym');
    expect(id, isNotNull);
    expect(repo.colorFor('Gym').background, isNotNull);

    await repo.setColor('Gym', 'brand_pink');
    expect(repo.getColorId('gym'), 'brand_pink');
    expect(repo.colorFor('GYM').background, TagColors.brandPink);
  });

  test('remove clears color assignment', () async {
    await repo.ensureTag('Temporal', colorId: 'brand_pink');
    await repo.remove('Temporal');
    expect(repo.getColorId('Temporal'), isNull);
  });

  test('remembers opacity and rename keeps style', () async {
    await repo.ensureTag('Gym', colorId: 'brand_pink', opacity: 0.5);
    expect(repo.getOpacity('Gym'), 0.5);

    final ok = await repo.rename('Gym', 'Gymnasio');
    expect(ok, isTrue);
    expect(repo.getAll(), contains('Gymnasio'));
    expect(repo.getAll(), isNot(contains('Gym')));
    expect(repo.getColorId('Gymnasio'), 'brand_pink');
    expect(repo.getOpacity('Gymnasio'), 0.5);
  });

  test('rename fails on name conflict', () async {
    await repo.ensureTags(['Alpha', 'Beta']);
    final ok = await repo.rename('Alpha', 'Beta');
    expect(ok, isFalse);
    expect(repo.getAll(), containsAll(['Alpha', 'Beta']));
  });
}
