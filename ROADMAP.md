# Lodha Inspiro Roadmap

Lodha Inspiro is being developed as a student super-app prototype. The project is intentionally evolving, so this roadmap tracks the features we agreed to build without pretending the prototype is already a finished school platform.

## 1. AI Notebook 2.0

- [x] Create multiple notebooks
- [x] Add pasted text, TXT/MD and PDF sources
- [x] Source-grounded Gemini Q&A
- [x] Suggested study questions
- [x] Notebook summaries
- [x] Audio Overview script + device narration
- [x] Create, edit and delete notes
- [x] Save useful AI answers as notes
- [x] Download notes as PDF, Word, PowerPoint or PNG on Android
- [x] Ask AI + Web mode in notebook chat
- [x] Voice-to-text input in notebook AI chat
- [x] AI-generated classwork from Notebook Studio
- [x] Open and complete generated classwork in-app
- [ ] Click a citation to jump to the exact source passage
- [ ] Better source previews and source management
- [ ] Streaming AI responses
- [ ] Study tools such as quiz, flashcards and key terms

## 2. Classroom

- [x] Classroom data models
- [x] Supabase classroom schema foundation
- [x] Course/subject repository flow
- [x] Assignment repository flow
- [x] Student submission repository flow
- [x] Demo classwork flow for testing
- [ ] Class dashboard UI
- [ ] Subjects and teachers UI
- [ ] Classwork/assignments UI
- [ ] Assignment details and due dates UI
- [ ] Student submission UI
- [ ] Teacher announcements
- [ ] Materials/resources per class
- [ ] Basic grades/progress view
- [ ] AI help for understanding class material

## 3. Advanced Messaging

- [x] Student/teacher/classmate/group conversations
- [x] Persistent Supabase-backed chats
- [x] Image attachments
- [x] Voice/video calling foundation
- [x] Reaction data foundation
- [x] Reply/quote data foundation
- [x] Edit/delete message state foundation
- [x] Message reactions UI
- [x] Reply/quote UI
- [x] Voice-to-text chat composer
- [x] Private per-user chat attachment storage
- [x] Chat participant isolation through Supabase RLS
- [ ] Typing indicators
- [ ] Read/delivery states
- [ ] Better group management
- [ ] Attachment previews and progress UI

## 4. Inspiro AI

- [x] General AI assistant inside the app
- [x] Inspiro AI on the Home screen
- [x] Optional web search for current answers
- [x] Voice-to-text input for Home AI
- [ ] Student-friendly study mode
- [ ] Explain, summarize, brainstorm and quiz actions
- [ ] Optional context from the student's notebooks/classes
- [x] Clear separation between general AI and source-grounded notebook answers

## 5. Notifications & Realtime

- [x] Realtime chat updates
- [x] New-message notifications
- [x] Realtime announcements screen updates
- [ ] Assignment reminders
- [ ] Announcement notifications
- [ ] Call/incoming-event handling
- [ ] Notification preferences

## 6. Backend & Security

- [x] Supabase authentication foundation
- [x] Row-level security for notebook data
- [x] Hardened database function search paths
- [x] Chat participant isolation policies
- [x] Private chat attachment storage policies
- [ ] Move Gemini requests behind a Supabase Edge Function
- [ ] Keep API secrets out of the Flutter client
- [ ] Move large source files to Supabase Storage
- [ ] Audit RLS policies for chats, classroom data and future features
- [ ] Add basic rate limiting/abuse protection around AI endpoints

## 7. UI, Quality & Release Readiness

- [x] Light/dark mode foundation
- [x] Google Sans Flex typography
- [x] Liquid-glass visual direction
- [x] Reusable Liquid Glass card, button and backdrop components
- [x] Shared Inspiro spacing, radius, typography and motion tokens
- [x] Shared accessibility helpers for interactive/section semantics
- [x] Automated Flutter analysis/tests in GitHub Actions
- [ ] Consistent design-system adoption across existing screens
- [ ] Notebook wallpaper/design applied consistently across notebook surfaces
- [ ] Bluish gradient treatment for shared light/dark components
- [ ] Smooth iOS-style screen transitions and shared-element motion
- [ ] Loading, empty and error states across the app
- [ ] Full accessibility pass
- [ ] CI Android build checks
- [ ] Clean release configuration

## Current Build Order

1. Classroom UI and integration
2. Advanced messaging UI and integration
3. Notebook 2.0 citations and source UX
4. Notifications/realtime
5. Backend security hardening
6. UI polish, tests and release readiness

### Batch history

- **Batch 1:** messaging reactions, reply/quote UI, edit/delete actions, realtime message updates, and new-message notifications were wired into the Flutter chat experience.
- **Batch 2:** Android note downloads and reusable Liquid Glass building blocks were added, followed by Home Inspiro AI, optional web search, announcements integration, voice-to-text composer support, private chat attachment handling, demo classwork, and AI-generated classwork in Notebook Studio.
- **Batch 2 also:** notebook AI chat now has a distinct Ask AI + Web mode, and generated classwork can be opened and completed inside the app.

This roadmap is a living plan. Features can be changed, expanded or removed as the prototype grows.
