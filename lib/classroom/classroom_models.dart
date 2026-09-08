class ClassroomCourse {
  final String id;
  final String teacherId;
  final String name;
  final String? section;
  final String? description;
  final DateTime createdAt;

  const ClassroomCourse({
    required this.id,
    required this.teacherId,
    required this.name,
    this.section,
    this.description,
    required this.createdAt,
  });

  factory ClassroomCourse.fromMap(Map<String, dynamic> map) {
    return ClassroomCourse(
      id: map['id'] as String,
      teacherId: map['teacher_id'] as String,
      name: map['name'] as String,
      section: map['section'] as String?,
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class ClassroomAssignment {
  final String id;
  final String courseId;
  final String title;
  final String? description;
  final DateTime? dueAt;
  final DateTime createdAt;

  const ClassroomAssignment({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    this.dueAt,
    required this.createdAt,
  });

  factory ClassroomAssignment.fromMap(Map<String, dynamic> map) {
    return ClassroomAssignment(
      id: map['id'] as String,
      courseId: map['course_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      dueAt: map['due_at'] == null
          ? null
          : DateTime.parse(map['due_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class ClassroomSubmission {
  final String id;
  final String assignmentId;
  final String studentId;
  final String? text;
  final DateTime? submittedAt;
  final DateTime? returnedAt;

  const ClassroomSubmission({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    this.text,
    this.submittedAt,
    this.returnedAt,
  });

  factory ClassroomSubmission.fromMap(Map<String, dynamic> map) {
    return ClassroomSubmission(
      id: map['id'] as String,
      assignmentId: map['assignment_id'] as String,
      studentId: map['student_id'] as String,
      text: map['text'] as String?,
      submittedAt: map['submitted_at'] == null
          ? null
          : DateTime.parse(map['submitted_at'] as String),
      returnedAt: map['returned_at'] == null
          ? null
          : DateTime.parse(map['returned_at'] as String),
    );
  }
}
