class QuizOption {
  final String text;
  final String why;

  const QuizOption({required this.text, required this.why});
}

class NotebookQuizQuestion {
  final String question;
  final List<QuizOption> options;
  final int correctIndex;
  final String hint;

  const NotebookQuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.hint,
  });
}
