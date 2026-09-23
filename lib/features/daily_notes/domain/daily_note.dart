class DailyNote {
  const DailyNote({
    required this.id,
    required this.noteDate,
    this.title = '',
    required this.content,
    this.isSticky = false,
    this.isDone = false,
    this.completedAt,
    this.authorId,
    this.authorName = '',
    this.assignedToId,
    this.assignedToName = '',
    this.assignedRoleId,
    this.assignedRoleName = '',
  });

  final int id;
  final String noteDate;
  final String title;
  final String content;
  final bool isSticky;
  final bool isDone;
  final String? completedAt;
  final int? authorId;
  final String authorName;
  final int? assignedToId;
  final String assignedToName;
  final int? assignedRoleId;
  final String assignedRoleName;

  bool get isGeneral => !isSticky;
  String get kindLabel => isSticky ? 'Sticky' : 'General';

  factory DailyNote.fromJson(Map<String, dynamic> json) {
    return DailyNote(
      id: (json['id'] as num).toInt(),
      noteDate: (json['note_date'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      isSticky: json['is_sticky'] == true,
      isDone: json['is_done'] == true,
      completedAt: json['completed_at']?.toString(),
      authorId: (json['author'] as num?)?.toInt(),
      authorName: (json['author_name'] ?? json['author_username'] ?? '')
          .toString(),
      assignedToId: (json['assigned_to'] as num?)?.toInt(),
      assignedToName:
          (json['assigned_to_name'] ?? json['assigned_to_username'] ?? '')
              .toString(),
      assignedRoleId: (json['assigned_role'] as num?)?.toInt(),
      assignedRoleName: (json['assigned_role_name'] ?? '').toString(),
    );
  }
}

class DailyTaskItem {
  const DailyTaskItem({
    required this.id,
    required this.taskDate,
    required this.title,
    this.description = '',
    this.isDone = false,
    this.authorId,
    this.assignedToId,
    this.assignedToName = '',
  });

  final int id;
  final String taskDate;
  final String title;
  final String description;
  final bool isDone;
  final int? authorId;
  final int? assignedToId;
  final String assignedToName;

  factory DailyTaskItem.fromJson(Map<String, dynamic> json) {
    return DailyTaskItem(
      id: (json['id'] as num).toInt(),
      taskDate: (json['task_date'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      isDone: json['is_done'] == true,
      authorId: (json['author'] as num?)?.toInt(),
      assignedToId: (json['assigned_to'] as num?)?.toInt(),
      assignedToName:
          (json['assigned_to_name'] ?? json['assigned_to_username'] ?? '')
              .toString(),
    );
  }
}

class DailyStaffOption {
  const DailyStaffOption({
    required this.id,
    required this.displayName,
  });

  final int id;
  final String displayName;

  factory DailyStaffOption.fromJson(Map<String, dynamic> json) {
    return DailyStaffOption(
      id: (json['id'] as num).toInt(),
      displayName: (json['display_name'] ?? json['username'] ?? '').toString(),
    );
  }
}

class DailyRoleOption {
  const DailyRoleOption({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory DailyRoleOption.fromJson(Map<String, dynamic> json) {
    return DailyRoleOption(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
    );
  }
}

bool sessionCanAssignDailyNotes({
  required bool viewAll,
  bool isAdmin = false,
  bool isSuperAdmin = false,
  bool isSuperuser = false,
}) {
  return viewAll || isAdmin || isSuperAdmin || isSuperuser;
}

String noteAudienceLabel(DailyNote note) {
  final role = note.assignedRoleName.trim();
  final person = note.assignedToName.trim();
  if (role.isNotEmpty && person.isNotEmpty) return '$role · $person';
  if (role.isNotEmpty) return role;
  if (person.isNotEmpty) return person;
  return '';
}

List<DailyNote> unresolvedStickyNotes(Iterable<DailyNote> notes) {
  return [for (final n in notes) if (n.isSticky && !n.isDone) n];
}

bool hasBlockingStickyNotes(Iterable<DailyNote> notes) {
  return unresolvedStickyNotes(notes).isNotEmpty;
}

bool canToggleDailyNote(DailyNote note, int? userId, {bool viewAll = false}) {
  if (viewAll) return true;
  if (userId == null) return false;
  return note.authorId == userId || note.assignedToId == userId;
}

String todayIsoDate([DateTime? now]) {
  final d = now ?? DateTime.now();
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

Map<String, dynamic> createNotePayload({
  required String noteDate,
  required String content,
  String title = '',
  bool isSticky = false,
  int? assignedTo,
  int? assignedRole,
}) {
  return {
    'note_date': noteDate,
    'title': title.trim(),
    'content': content.trim(),
    'is_sticky': isSticky,
    if (assignedTo != null) 'assigned_to': assignedTo,
    if (assignedRole != null) 'assigned_role': assignedRole,
  };
}
