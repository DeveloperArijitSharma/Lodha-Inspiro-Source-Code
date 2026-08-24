# 🎓 Lodha Inspiro — Modern Student Portal App

**Lodha Inspiro** is a feature-rich, high-performance student portal and communication application built with **Flutter**. It features a modern **Glassmorphism UI**, secure backend data synchronization powered by **Supabase**, and real-time voice and video calling powered by **Agora RTC**.

---

## ✨ Key Features

* **🎨 Glassmorphic UI Design:** A sleek, translucent frosted-glass aesthetic supporting both light and dark modes.
* **🔐 Secure Authentication:** User login, registration, and persistent sessions managed via Supabase Auth.
* **💬 Real-Time Messaging:** Instant communication channels categorized into Classmates, Teachers, and Groups with real-time database syncing.
* **📎 Media Attachments:** Seamlessly pick and upload images from your device gallery directly into chats using Supabase Storage.
* **📞 HD Voice & Video Calls:** Real-time 1-on-1 audio and video calling integrated with **Agora RTC Engine**, featuring mute toggles, speaker routing, camera flipping, and a call timer.
* **🛡️ Data Privacy & Isolation:** Chat queries and histories are secured and isolated per user profile.

---

## 📱 Tech Stack

* **Frontend:** Flutter (Dart)
* **Backend & Database:** Supabase (PostgreSQL, Auth, Storage)
* **Real-Time Communication:** Agora RTC Engine (`agora_rtc_engine`)
* **UI Utilities:** Google Fonts, Image Picker, Permission Handler, Flutter Blur (Glassmorphism)

---

## 📂 Project Structure

```text
lodha_inspiro/
│
├── android/               # Android native configuration & resources
├── ios/                   # iOS native configuration & resources
├── lib/
│   ├── main.dart          # App entry point & Theme controller
│   ├── login_screen.dart  # Authentication & Signup gateway
│   ├── home_screen.dart   # Dashboard, Classwork, and Chat list view
│   ├── chat_screen.dart   # Messaging interface & media uploads
│   └── call_screen.dart   # Agora Voice/Video call interface
│
├── pubspec.yaml           # Project dependencies
└── README.md              # Project documentation
