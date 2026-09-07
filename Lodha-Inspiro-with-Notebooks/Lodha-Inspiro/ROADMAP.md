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
- [ ] Click a citation to jump to the exact source passage
- [ ] Better source previews and source management
- [ ] Streaming AI responses
- [ ] Study tools such as quiz, flashcards and key terms

## 2. Classroom

- [ ] Class dashboard
- [ ] Subjects and teachers
- [ ] Classwork/assignments
- [ ] Assignment details and due dates
- [ ] Student submission flow
- [ ] Teacher announcements
- [ ] Materials/resources per class
- [ ] Basic grades/progress view
- [ ] AI help for understanding class material

## 3. Advanced Messaging

- [x] Student/teacher/classmate/group conversations
- [x] Persistent Supabase-backed chats
- [x] Image attachments
- [x] Voice/video calling foundation
- [ ] Message reactions
- [ ] Reply/quote messages
- [ ] Typing indicators
- [ ] Read/delivery states
- [ ] Better group management
- [ ] Safer attachment storage through Supabase Storage

## 4. Inspiro AI

- [ ] General AI assistant inside the app
- [ ] Student-friendly study mode
- [ ] Explain, summarize, brainstorm and quiz actions
- [ ] Optional context from the student's notebooks/classes
- [ ] Clear separation between general AI and source-grounded notebook answers

## 5. Notifications & Realtime

- [ ] Realtime chat updates
- [ ] New-message notifications
- [ ] Assignment reminders
- [ ] Announcement notifications
- [ ] Call/incoming-event handling
- [ ] Notification preferences

## 6. Backend & Security

- [x] Supabase authentication foundation
- [x] Row-level security for notebook data
- [ ] Move Gemini requests behind a Supabase Edge Function
- [ ] Keep API secrets out of the Flutter client
- [ ] Move large source files to Supabase Storage
- [ ] Audit RLS policies for chats, classroom data and future features
- [ ] Add basic rate limiting/abuse protection around AI endpoints

## 7. UI, Quality & Release Readiness

- [x] Light/dark mode foundation
- [x] Google Sans Flex typography
- [x] Liquid-glass visual direction
- [ ] Consistent design system and reusable components
- [ ] Loading, empty and error states across the app
- [ ] Accessibility pass
- [ ] Automated Flutter analysis/tests
- [ ] CI build checks
- [ ] Clean release configuration

## Build order

1. Notebook 2.0 polish and citations
2. Classroom foundation
3. Advanced messaging polish
4. Inspiro AI
5. Notifications/realtime
6. Backend security hardening
7. UI polish, tests and release readiness

This roadmap is a living plan. Features can be changed, expanded or removed as the prototype grows.
