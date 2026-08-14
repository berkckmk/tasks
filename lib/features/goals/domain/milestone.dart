class Milestone {
  const Milestone({
    required this.id,
    required this.title,
    this.isDone = false,
  });

  final String id;
  final String title;
  final bool isDone;

  Milestone copyWith({String? title, bool? isDone}) {
    return Milestone(
      id: id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
    );
  }

  factory Milestone.fromMap(Map<String, dynamic> map) {
    return Milestone(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      isDone: map['isDone'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'isDone': isDone};
}
