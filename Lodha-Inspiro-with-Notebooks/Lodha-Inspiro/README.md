# Lodha Inspiro

A new Flutter project created with FlutLab - https://flutlab.io

## 🧠 Notebooks (new): a Gemini-powered NotebookLM-style feature

The "Notebooks" tab (formerly the placeholder "Classwork" tab) lets a student
create a notebook, add sources (pasted text, `.txt`/`.md`, or a PDF), and:

- **Chat** with those sources only — grounded Q&A, not general knowledge
- **Summarize** the whole notebook in one tap
- **Audio Overview** — generates a two-host discussion script and narrates it
  on-device (via `flutter_tts`)

### Setup

1. **Get a Gemini API key** — free, from [Google AI Studio](https://aistudio.google.com/apikey).
2. **Set the key.** Either:
   - Edit `lib/gemini/gemini_config.dart` and paste it into `apiKey`, or
   - (Recommended, so it's not committed to git) run with:
     ```
     flutter run --dart-define=GEMINI_API_KEY=your_key_here
     ```
3. **Add the Supabase tables.** Open your Supabase project → SQL Editor →
   paste and run `supabase_notebooks_schema.sql` from the project root. This
   adds `notebooks`, `notebook_sources`, and `notebook_messages`, all with
   row-level security so each student only sees their own.
4. `flutter pub get`, then run on any target platform.

### Architecture notes

- `lib/gemini/gemini_service.dart` — single choke point for every Gemini
  call (chat, summarize, suggest questions, audio script). Swapping models,
  adding streaming, or moving the key behind a backend later is a one-file
  change.
- Files (PDFs) are sent to Gemini as inline base64 data rather than parsed
  client-side — Gemini reads PDFs natively server-side, which is what keeps
  source upload working identically on Android/iOS/macOS/Windows/web without
  a native PDF-parsing dependency per platform.
- `base64_data` is stored inline in Postgres for now. For larger files,
  switch to a Supabase Storage bucket and store a path instead.
- The Gemini key currently ships in the client. Fine for prototyping; before
  a real release, proxy calls through a Supabase Edge Function so the key
  never lives on-device.

### Not yet built (roadmap)

- Server-side/studio-quality TTS for Audio Overview (currently uses the
  device's own TTS voice, not a generated podcast-style voice)
- Notes panel (turning AI answers into saved, editable notes)
- Multi-user shared notebooks (classmates collaborating on one notebook)
- Citation click-through to the exact source passage

## Getting Started

A few resources to get you started if this is your first Flutter project:

- https://flutter.dev/docs/get-started/codelab
- https://flutter.dev/docs/cookbook

For help getting started with Flutter, view our
https://flutter.dev/docs, which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Getting Started: FlutLab - Flutter Online IDE

- How to use FlutLab? Please, view our https://flutlab.io/docs
- Join the discussion and conversation on https://flutlab.io/residents
