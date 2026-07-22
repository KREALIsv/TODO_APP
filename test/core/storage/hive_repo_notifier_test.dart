import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/core/storage/hive_repo_notifier.dart';

void main() {
  test('HiveRepoNotifier notifies on reloadComplete', () {
    var count = 0;
    final boxListenable = ValueNotifier(0);
    final notifier = HiveRepoNotifier();
    notifier.addListener(() => count++);
    notifier.bind(boxListenable);

    notifier.reloadComplete();
    expect(count, 1);
  });
}
