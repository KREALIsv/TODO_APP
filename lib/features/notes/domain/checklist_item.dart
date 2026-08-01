/// Sentinel so [ChecklistItem.copyWith] can clear nullable fields.
const Object _unset = Object();

class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.title,
    this.completed = false,
    this.sortOrder = 0,
  });

  final String id;
  final String title;
  final bool completed;
  final int sortOrder;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'completed': completed,
      'sortOrder': sortOrder,
    };
  }

  factory ChecklistItem.fromMap(Map<dynamic, dynamic> map) {
    final rawOrder = map['sortOrder'];
    return ChecklistItem(
      id: map['id'] as String,
      title: (map['title'] as String?) ?? '',
      completed: (map['completed'] as bool?) ?? false,
      sortOrder: rawOrder is int
          ? rawOrder
          : rawOrder is num
              ? rawOrder.toInt()
              : 0,
    );
  }

  ChecklistItem copyWith({
    String? id,
    String? title,
    bool? completed,
    int? sortOrder,
  }) {
    return ChecklistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

List<ChecklistItem> checklistItemsFromMap(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map(ChecklistItem.fromMap)
      .where((item) => item.title.trim().isNotEmpty || item.id.isNotEmpty)
      .toList();
}

List<Map<String, dynamic>> checklistItemsToMap(List<ChecklistItem> items) {
  return items.map((item) => item.toMap()).toList();
}
