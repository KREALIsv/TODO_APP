/// Sentinel so [NoteAttachment.copyWith] can clear nullable fields.
const Object _unset = Object();

class NoteAttachment {
  const NoteAttachment({
    required this.id,
    required this.noteId,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
    required this.createdAt,
    required this.sortOrder,
    this.width,
    this.height,
  });

  final String id;
  final String noteId;
  final String fileName;
  final String mimeType;
  final int byteSize;
  final DateTime createdAt;
  final int sortOrder;
  final int? width;
  final int? height;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'noteId': noteId,
      'fileName': fileName,
      'mimeType': mimeType,
      'byteSize': byteSize,
      'createdAt': createdAt.toIso8601String(),
      'sortOrder': sortOrder,
      'width': width,
      'height': height,
    };
  }

  factory NoteAttachment.fromMap(Map<dynamic, dynamic> map) {
    final rawSize = map['byteSize'];
    final rawOrder = map['sortOrder'];
    final rawWidth = map['width'];
    final rawHeight = map['height'];

    return NoteAttachment(
      id: map['id'] as String,
      noteId: map['noteId'] as String,
      fileName: (map['fileName'] as String?) ?? 'image.jpg',
      mimeType: (map['mimeType'] as String?) ?? 'image/jpeg',
      byteSize: rawSize is int
          ? rawSize
          : rawSize is num
              ? rawSize.toInt()
              : 0,
      createdAt: DateTime.parse(map['createdAt'] as String),
      sortOrder: rawOrder is int
          ? rawOrder
          : rawOrder is num
              ? rawOrder.toInt()
              : 0,
      width: rawWidth is int
          ? rawWidth
          : rawWidth is num
              ? rawWidth.toInt()
              : null,
      height: rawHeight is int
          ? rawHeight
          : rawHeight is num
              ? rawHeight.toInt()
              : null,
    );
  }

  NoteAttachment copyWith({
    String? id,
    String? noteId,
    String? fileName,
    String? mimeType,
    int? byteSize,
    DateTime? createdAt,
    int? sortOrder,
    Object? width = _unset,
    Object? height = _unset,
  }) {
    return NoteAttachment(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      byteSize: byteSize ?? this.byteSize,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
      width: identical(width, _unset) ? this.width : width as int?,
      height: identical(height, _unset) ? this.height : height as int?,
    );
  }
}
