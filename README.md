# Lodha Inspiro

Lodha Inspiro is a student-focused Flutter super-app prototype bringing learning, communication, live classes and AI study tools into one place.

## What is included

### 📚 Inspiro Notebooks
A NotebookLM-style study workspace powered by Gemini:

- Create multiple private notebooks
- Add pasted text, TXT, Markdown and PDF sources
- Ask questions grounded only in notebook sources
- Get source-aware answers instead of unsupported guesses
- Generate notebook summaries
- Generate suggested study questions
- Generate an Audio Overview script and narrate it on-device
- Save AI answers as editable notes
- Create and edit notes manually
- Delete sources and notes
- Store notebook data in Supabase with per-user row-level security

### 🤖 Inspiro AI
A separate general-purpose student assistant powered by the same Gemini service layer. It can help with explanations, study planning, brainstorming and quick quizzes without being tied to one notebook.

### 💬 Communication
The existing app includes student/teacher/group messaging, image attachments and calling support through the existing Supabase and Agora integrations.

### 🏫 Learning & live classes
The app already has the student home/live-class experience and uses the Classwork area for the new Notebooks workspace.

## Gemini setup

The Gemini integration is configured through `lib/gemini/gemini_config.dart` and supports a compile-time environment variable:

```bash
flutter run --dart-define=GEMINI_API_KEY=your_key_here
```

For a real production deployment, Gemini requests should eventually move behind a backend such as a Supabase Edge Function so the API key is not shipped inside the client app.

## Supabase setup

Run `supabase_notebooks_schema.sql` in the Supabase SQL Editor. It creates the notebook, source, message and note tables and enables row-level security so notebook records are private to their owner.

For larger uploaded files, the current inline `base64_data` approach should eventually be replaced with Supabase Storage.

## Architecture direction

The project is intentionally being built in small, reviewable steps:

`Flutter UI → Inspiro AI layer → Notebook AI / General AI → Supabase + sources`

The AI service is kept behind one Gemini service layer so streaming, richer citations, backend proxying and other model changes can be added later without rewriting every screen.

## Roadmap

1. **Notebook 2.0**: richer source handling, stronger citations, better study tools and improved AI UX.
2. **Classroom**: assignments, submissions, class announcements and teacher/student workflows.
3. **Advanced Messaging**: stronger realtime chat, media handling, read states and classroom groups.
4. **Inspiro AI**: persistent conversations, more study modes and better student controls.
5. **Notifications & realtime events**: central event handling for messages, assignments and classes.
6. **Security & backend**: Supabase Edge Functions, secure Gemini access and tighter data policies.
7. **UI, accessibility & performance**: polished responsive layouts, loading states, error states and accessibility improvements.

This is a small project and the architecture/UI will evolve as new ideas are added.
