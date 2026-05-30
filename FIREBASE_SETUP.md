# Firebase Setup

This project now has Firebase Auth, Firestore leaderboard, and Realtime Database multiplayer code.

## Required Firebase services

Enable these in Firebase Console:

- Authentication: Email/Password and Anonymous
- Cloud Firestore
- Realtime Database

## Configure the app

Already completed for project `wrap-maze`:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `.firebaserc`
- `firebase.json`

To reconfigure later, run:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Select this Firebase project and Android/Web targets. This should create:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- web Firebase app settings inside `firebase_options.dart`

## Security rules

Use:

- `firebase_firestore.rules` for Firestore
- `firebase_database.rules.json` for Realtime Database

Rules were deployed with:

```bash
firebase deploy --only firestore:rules,database --project wrap-maze
```
