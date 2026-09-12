import 'package:cloud_firestore/cloud_firestore.dart';

enum ReminderStatus { scheduled, completed, snoozed, missed }

enum ReminderPriority {
  low(
    label: 'Sessiz',
    description: 'Ses ve titreşim yok, yalnızca bildirim panosunda görünür.',
  ),
  normal(
    label: 'Normal',
    description: 'Standart ses ve hafif titreşim, durum çubuğu simgesi.',
  ),
  important(
    label: 'Önemli',
    description: 'Ekrana fırlar (heads-up pop-up), saat ve kulaklıkta güçlü dürtür.',
  );

  const ReminderPriority({required this.label, required this.description});
  final String label;
  final String description;
}

class ReminderItem {
  const ReminderItem({
    required this.id,
    required this.title,
    required this.message,
    this.dueAt,
    required this.status,
    this.priority = ReminderPriority.normal,
    this.starred = false,
    this.earlyAlertMinutes,
    this.repeatRule,
    this.location,
    this.category = 'Hatırlatıcılarım',
    this.checklist = const [],
  });

  final String id;
  final String title;
  final String message;
  final DateTime? dueAt;
  final ReminderStatus status;
  final ReminderPriority priority;
  final bool starred;
  final int? earlyAlertMinutes;
  final String? repeatRule;
  final String? location;
  final String category;
  final List<String> checklist;

  bool get isPast => dueAt != null && dueAt!.isBefore(DateTime.now());

  bool get isMedicine {
    final lower = '$title $message'.toLowerCase();
    return lower.contains('duxet') ||
        lower.contains('aubagio') ||
        lower.contains('folik') ||
        lower.contains('ilaç') ||
        lower.contains('ilac') ||
        lower.contains('hap') ||
        lower.contains('medicine') ||
        lower.contains('pill') ||
        lower.contains('vitamin') ||
        lower.contains('antibiyotik');
  }

  factory ReminderItem.fromFirestore(String id, Map<String, dynamic> data) {
    final title = data['title'] as String? ?? '';
    final message = data['message'] as String? ?? '';
    final lower = '$title $message'.toLowerCase();
    final isMed = lower.contains('duxet') ||
        lower.contains('aubagio') ||
        lower.contains('folik') ||
        lower.contains('ilaç') ||
        lower.contains('ilac') ||
        lower.contains('hap') ||
        lower.contains('medicine') ||
        lower.contains('pill') ||
        lower.contains('vitamin') ||
        lower.contains('antibiyotik');

    // If priority is explicitly set in Firestore, respect it (unless it was default 'normal' for medicine).
    final priorityStr = data['priority'] as String?;
    final ReminderPriority resolvedPriority;
    if (priorityStr != null) {
      final parsed = ReminderPriority.values.firstWhere(
        (p) => p.name == priorityStr,
        orElse: () => ReminderPriority.normal,
      );
      if (isMed && parsed == ReminderPriority.normal) {
        resolvedPriority = ReminderPriority.important;
      } else {
        resolvedPriority = parsed;
      }
    } else {
      resolvedPriority =
          isMed ? ReminderPriority.important : ReminderPriority.normal;
    }

    final rawChecklist = data['checklist'];
    final List<String> parsedChecklist = rawChecklist is List
        ? rawChecklist.map((e) => e.toString()).toList()
        : const [];

    return ReminderItem(
      id: id,
      title: title,
      message: message,
      dueAt: (data['dueAt'] as Timestamp?)?.toDate(),
      status: ReminderStatus.values.firstWhere(
        (s) => s.name == (data['status'] as String? ?? 'scheduled'),
        orElse: () => ReminderStatus.scheduled,
      ),
      priority: resolvedPriority,
      starred: (data['starred'] as bool?) ?? false,
      earlyAlertMinutes: (data['earlyAlertMinutes'] as num?)?.toInt(),
      repeatRule: data['repeatRule'] as String?,
      location: data['location'] as String?,
      category: data['category'] as String? ?? 'Hatırlatıcılarım',
      checklist: parsedChecklist,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'message': message,
      'dueAt': dueAt == null ? null : Timestamp.fromDate(dueAt!),
      'status': status.name,
      'priority': priority.name,
      'starred': starred,
      'earlyAlertMinutes': earlyAlertMinutes,
      'repeatRule': repeatRule,
      'location': location,
      'category': category,
      'checklist': checklist,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ReminderItem copyWith({
    String? title,
    String? message,
    DateTime? dueAt,
    bool clearDueAt = false,
    ReminderStatus? status,
    ReminderPriority? priority,
    bool? starred,
    int? earlyAlertMinutes,
    bool clearEarlyAlert = false,
    String? repeatRule,
    bool clearRepeatRule = false,
    String? location,
    bool clearLocation = false,
    String? category,
    List<String>? checklist,
  }) {
    return ReminderItem(
      id: id,
      title: title ?? this.title,
      message: message ?? this.message,
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
      status: status ?? this.status,
      priority: priority ?? this.priority,
      starred: starred ?? this.starred,
      earlyAlertMinutes:
          clearEarlyAlert ? null : (earlyAlertMinutes ?? this.earlyAlertMinutes),
      repeatRule: clearRepeatRule ? null : (repeatRule ?? this.repeatRule),
      location: clearLocation ? null : (location ?? this.location),
      category: category ?? this.category,
      checklist: checklist ?? this.checklist,
    );
  }
}
