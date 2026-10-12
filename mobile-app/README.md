# Prime School Mobile Application

Official cross-platform mobile application for **Prime School Management System**, developed by **Primeskill Solutions Private Limited**.

## Overview
- **Platforms Supported**: Android (APK/AAB), iOS (IPA), macOS, Web
- **Technology Stack**: Flutter (Dart 3.8+), Material 3, Firebase Messaging
- **Target Backend**: Prime School Management Platform (PHP CodeIgniter REST API)

## Key Features
- **Student & Parent Portals**: Academic timetable, attendance tracking, syllabus status, homework & assignments.
- **Examinations**: CBSE Examination, Online Exams, Instant Results & Report Cards.
- **Finance & Fees**: Fee schedules, online fee payment integration, payment receipts.
- **Virtual Learning**: Live interactive classes via Zoom and Google Meet, Online Courses with video player.
- **Communications**: Instant push notifications via Firebase, notice board, visitor logs, and student behaviour records.
- **Offline Mode & Multi-Currency**: Offline data caching with full INR (₹) / localized currency formatting.

## Build Instructions

### Android
```bash
flutter build apk --release
# Or for Google Play Store Bundle:
flutter build appbundle --release
```

### iOS
```bash
flutter build ipa --release
```
