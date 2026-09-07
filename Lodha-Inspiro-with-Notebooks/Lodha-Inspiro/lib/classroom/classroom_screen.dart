import 'dart:ui';

import 'package:flutter/material.dart';

import 'classroom_models.dart';
import 'classroom_repository.dart';

class ClassroomScreen extends StatefulWidget {
  const ClassroomScreen({super.key});

  @override
  State<ClassroomScreen> createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends State<ClassroomScreen> {
  final ClassroomRepository _repository = ClassroomRepository();
  final Color _accentBlue = const Color(0xFF32C5FF);
  List<ClassroomCourse> _courses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final courses = await _repository.fetchCourses();
      if (!mounted) return;
      setState(() {
        _courses = courses;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your classes yet.';
      });
    }
  }

  void _openCourse(ClassroomCourse course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClassroomCourseScreen(
          course: course,
          repository: _repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    return RefreshIndicator(
      color: _accentBlue,
      onRefresh: _loadCourses,
      child: ListView(
        key: const ValueKey(1),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        children: [
          Row(
            children: [
              Builder(
                builder: (context) => IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.menu_rounded, color: textColor, size: 28),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Classroom',
                style: TextStyle(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Google Sans Flex',
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _glassBanner(isDark, textColor),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your classes',
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Google Sans Flex',
                ),
              ),
              IconButton(
                onPressed: _loadCourses,
                icon: Icon(Icons.refresh_rounded, color: _accentBlue),
                tooltip: 'Refresh classes',
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF32C5FF)),
              ),
            )
          else if (_error != null)
            _emptyState(isDark, Icons.cloud_off_rounded, _error!, 'Try again', _loadCourses)
          else if (_courses.isEmpty)
            _emptyState(
              isDark,
              Icons.school_outlined,
              'No classes have been added yet.',
              null,
              null,
            )
          else
            ..._courses.map((course) => _courseCard(course, isDark, textColor)),
        ],
      ),
    );
  }

  Widget _glassBanner(bool isDark, Color textColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _accentBlue.withOpacity(isDark ? 0.24 : 0.16),
                isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.72),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _accentBlue.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: _accentBlue.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_stories_rounded, color: _accentBlue),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stay on top of classwork', style: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
                    const SizedBox(height: 4),
                    Text('Open a class to see assignments and submit work.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13, fontFamily: 'Google Sans Flex')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _courseCard(ClassroomCourse course, bool isDark, Color textColor) {
    return GestureDetector(
      onTap: () => _openCourse(course),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(color: _accentBlue.withOpacity(0.14), borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.menu_book_rounded, color: _accentBlue),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.name, style: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
                  if (course.section != null && course.section!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(course.section!, style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13, fontFamily: 'Google Sans Flex')),
                  ],
                  if (course.description != null && course.description!.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(course.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12, fontFamily: 'Google Sans Flex')),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white54 : Colors.black38),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(bool isDark, IconData icon, String text, String? action, VoidCallback? onAction) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 45),
      child: Column(
        children: [
          Icon(icon, size: 56, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 14),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontFamily: 'Google Sans Flex')),
          if (action != null) ...[
            const SizedBox(height: 14),
            TextButton(onPressed: onAction, child: Text(action, style: TextStyle(color: _accentBlue, fontFamily: 'Google Sans Flex'))),
          ],
        ],
      ),
    );
  }
}

class ClassroomCourseScreen extends StatefulWidget {
  final ClassroomCourse course;
  final ClassroomRepository repository;

  const ClassroomCourseScreen({super.key, required this.course, required this.repository});

  @override
  State<ClassroomCourseScreen> createState() => _ClassroomCourseScreenState();
}

class _ClassroomCourseScreenState extends State<ClassroomCourseScreen> {
  List<ClassroomAssignment> _assignments = [];
  bool _loading = true;
  final Color _accentBlue = const Color(0xFF32C5FF);

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    try {
      final assignments = await widget.repository.fetchAssignments(widget.course.id);
      if (!mounted) return;
      setState(() {
        _assignments = assignments;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openAssignment(ClassroomAssignment assignment) async {
    final submission = await widget.repository.fetchMySubmission(assignment.id);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignmentSheet(
        assignment: assignment,
        initialSubmission: submission,
        repository: widget.repository,
        accentBlue: _accentBlue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFEBF0F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.course.name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _accentBlue))
          : RefreshIndicator(
              color: _accentBlue,
              onRefresh: _loadAssignments,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  if (widget.course.description != null && widget.course.description!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      margin: const EdgeInsets.only(bottom: 22),
                      decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.white, borderRadius: BorderRadius.circular(22)),
                      child: Text(widget.course.description!, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontFamily: 'Google Sans Flex')),
                    ),
                  Text('Classwork', style: TextStyle(color: textColor, fontSize: 21, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
                  const SizedBox(height: 12),
                  if (_assignments.isEmpty)
                    Padding(padding: const EdgeInsets.symmetric(vertical: 50), child: Center(child: Text('No assignments yet.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontFamily: 'Google Sans Flex'))))
                  else
                    ..._assignments.map((assignment) => _assignmentCard(assignment, isDark, textColor)),
                ],
              ),
            ),
    );
  }

  Widget _assignmentCard(ClassroomAssignment assignment, bool isDark, Color textColor) {
    final due = assignment.dueAt;
    return GestureDetector(
      onTap: () => _openAssignment(assignment),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _accentBlue.withOpacity(0.12), shape: BoxShape.circle), child: Icon(Icons.assignment_rounded, color: _accentBlue)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(assignment.title, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
              if (assignment.description != null && assignment.description!.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(assignment.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13, fontFamily: 'Google Sans Flex')),
              ],
              if (due != null) ...[
                const SizedBox(height: 8),
                Text('Due ${due.day}/${due.month}/${due.year}', style: TextStyle(color: _accentBlue, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Google Sans Flex')),
              ],
            ])),
            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white54 : Colors.black38),
          ],
        ),
      ),
    );
  }
}

class _AssignmentSheet extends StatefulWidget {
  final ClassroomAssignment assignment;
  final ClassroomSubmission? initialSubmission;
  final ClassroomRepository repository;
  final Color accentBlue;

  const _AssignmentSheet({required this.assignment, required this.initialSubmission, required this.repository, required this.accentBlue});

  @override
  State<_AssignmentSheet> createState() => _AssignmentSheetState();
}

class _AssignmentSheetState extends State<_AssignmentSheet> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialSubmission?.text ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.repository.upsertMySubmission(assignmentId: widget.assignment.id, text: _controller.text.trim());
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assignment submitted successfully.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not submit assignment.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 20),
            Text(widget.assignment.title, style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
            if (widget.assignment.description != null) ...[
              const SizedBox(height: 10),
              Text(widget.assignment.description!, style: TextStyle(color: isDark ? Colors.white70 : Colors.black65, fontFamily: 'Google Sans Flex')),
            ],
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              minLines: 4,
              maxLines: 7,
              style: TextStyle(color: textColor, fontFamily: 'Google Sans Flex'),
              decoration: InputDecoration(hintText: 'Write your submission...', filled: true, fillColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.04), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
              label: Text(widget.initialSubmission == null ? 'Submit work' : 'Update submission', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
              style: ElevatedButton.styleFrom(backgroundColor: widget.accentBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
            )),
          ]),
        ),
      ),
    );
  }
}
