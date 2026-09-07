import 'package:supabase_flutter/supabase_flutter.dart';

import 'classroom_models.dart';

class ClassroomRepository {
  final SupabaseClient _client;

  ClassroomRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<List<ClassroomCourse>> fetchCourses() async {
    final rows = await _client
        .from('classroom_courses')
        .select()
        .order('created_at', ascending: false);
    return rows
        .map((row) => ClassroomCourse.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<ClassroomAssignment>> fetchAssignments(String courseId) async {
    final rows = await _client
        .from('classroom_assignments')
        .select()
        .eq('course_id', courseId)
        .order('due_at', ascending: true);
    return rows
        .map((row) => ClassroomAssignment.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<ClassroomSubmission?> fetchMySubmission(String assignmentId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _client
        .from('classroom_submissions')
        .select()
        .eq('assignment_id', assignmentId)
        .eq('student_id', userId)
        .maybeSingle();

    if (row == null) return null;
    return ClassroomSubmission.fromMap(Map<String, dynamic>.from(row));
  }

  Future<ClassroomSubmission> upsertMySubmission({
    required String assignmentId,
    String? text,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to submit classwork.');
    }

    final row = await _client
        .from('classroom_submissions')
        .upsert({
          'assignment_id': assignmentId,
          'student_id': userId,
          'text': text,
          'submitted_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'assignment_id,student_id')
        .select()
        .single();

    return ClassroomSubmission.fromMap(Map<String, dynamic>.from(row));
  }
}
