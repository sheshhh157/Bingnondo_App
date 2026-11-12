# Bingnondo_App

## Firebase push notifications

The Android Firebase config has been added at
`android/app/google-services.json`. Android uses the matching project settings
in `lib/firebase_options.dart`; replace them if you change Firebase projects.
For local builds, run `flutter run`. You only need the ignored
`firebase_options.json` dart-defines file when configuring iOS:

1. In Firebase Console, create/open the Bingnondo project and register the
   Android app using `com.example.bingnondo_app` (or the `applicationId` in
   `android/app/build.gradle.kts` if you change it). Register the iOS app using
   the iOS bundle ID from Xcode.
2. Copy the Web API key and Project ID from **Project settings → General**.
   Copy the Sender ID and each platform's App ID from the registered apps.
   The API key is public client configuration; never put the service-account
   private key in this Flutter app.
3. Configure an APNs authentication key in Firebase for iOS push delivery, and
   enable **Push Notifications** for the iOS target in Xcode.
4. Run/build Android with:

   ```bash
   flutter run
   flutter build apk
   ```

   For iOS, configure its Firebase API key, project ID, sender ID, iOS App ID,
   and bundle ID in `firebase_options.json`, then use
   `flutter run --dart-define-from-file=firebase_options.json`.

The app asks for notification permission after sign-in, registers the FCM
device token with the backend, displays foreground pushes, and opens the
Notifications page when a push is tapped. Background/closed-app notification
delivery also requires the backend Railway service account and Supabase token
table migration described in the backend README.