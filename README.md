<p align="center">
  <img src="https://github.com/user-attachments/assets/a02b4308-47f7-4aee-93fa-2a00e543e45f" alt="Bingnondo Cafe Logo" width="200"/>
</p>

<h1 align="center">Bingnondo Café — Mobile App</h1>

<p align="center">
  A Flutter-based food ordering app for Bingnondo Café customers — browse the menu, place orders, track delivery, and chat with support in one place.
</p>

---

## Overview

The Bingnondo App is the customer-facing mobile application for Bingnondo Café. Customers can browse the full menu, add items to cart, check out via GCash or cash on delivery, and track their rider in real time on a live map — all wrapped in Bingnondo's warm Chinese-heritage design.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart SDK ^3.12.2) |
| State Management | Provider |
| Navigation | go_router |
| HTTP Client | http |
| Realtime | Socket.io client |
| Maps | flutter_map (OpenStreetMap) + geolocator |
| Push Notifications | Firebase Cloud Messaging (FCM) + flutter_local_notifications |
| Auth Storage | flutter_secure_storage |
| UI / Fonts | Google Fonts, flutter_svg, shimmer, loading_animation_widget |
| Form Handling | flutter_form_builder + form_builder_validators |
| Backend | Express + PostgreSQL (shared with manager dashboard) |

---

## Features

- **Menu Browsing** — browse categories and items with live availability updates via Socket.io
- **Cart & Checkout** — add items with variants, choose delivery address via map pin-drop, pay via GCash or cash
- **Order Tracking** — real-time rider location on an interactive map
- **My Orders** — full order history with status and details
- **Push Notifications** — FCM-powered notifications for order status updates; opens the Notifications page on tap
- **Chatbot** — built-in AI chatbot for menu and order questions
- **Support Chat** — live chat with store support
- **Account Settings** — profile management, address history, notification preferences
- **OTP Authentication** — email-based OTP for sign-up and password reset

---

## Project Structure

```
Bingnondo_App-main/
├── lib/
│   ├── main.dart
│   ├── firebase_options.dart
│   ├── models/              # Data models (menu, cart, order, tracking, etc.)
│   ├── screens/
│   │   ├── auth/            # Login, signup, OTP, forgot password
│   │   ├── menu/            # Home menu screen
│   │   ├── cart/            # Cart and checkout
│   │   ├── orders/          # My orders
│   │   ├── tracking/        # Live order tracking map
│   │   ├── notifications/   # Notifications
│   │   ├── chat/            # Support chat
│   │   ├── chatbot/         # AI chatbot
│   │   ├── address/         # Address picker (map pin-drop)
│   │   ├── profile/         # Complete profile
│   │   └── settings/        # Account settings
│   └── services/            # API service, providers, auth, business hours
├── assets/
│   └── images/              # App icon, backgrounds, lucky cat, ndo_bot
├── android/                 # Android-specific config
└── ios/                     # iOS-specific config
```

---

## Getting Started

### Prerequisites

- Flutter SDK (Dart ^3.12.2)
- Android Studio or Xcode (for device/emulator)
- A running instance of the Bingnondo backend

### Run the App

```bash
flutter pub get
flutter run
```

For a release build:

```bash
flutter build apk          # Android
flutter build ios          # iOS (requires Mac + Xcode)
```

---

## Firebase & Push Notifications

The Android Firebase config is already at `android/app/google-services.json`.

### Setup Steps

1. In Firebase Console, open (or create) the Bingnondo project
2. Register the Android app using the `applicationId` from `android/app/build.gradle.kts`
3. Register the iOS app using the iOS bundle ID from Xcode
4. Copy your **Web API key** and **Project ID** from **Project Settings → General**
5. Update `lib/firebase_options.dart` with your project values

### iOS Additional Steps

Configure your Firebase credentials in `firebase_options.json` (gitignored), then run:

```bash
flutter run --dart-define-from-file=firebase_options.json
```

Enable **Push Notifications** in Xcode and configure an APNs authentication key in Firebase for iOS push delivery.

> **Note:** The API key in `firebase_options.dart` is public client configuration. Never put a service-account private key inside the Flutter app.

---

## Environment Notes

- The app connects to the Bingnondo Express backend (default port `5000`)
- Update the base URL in `lib/services/api_service.dart` to point to your backend host
- Background/closed-app push notification delivery also requires the backend Railway service account and Supabase token table migration described in the backend README

---

## License

Private repository — Bingnondo Café. Not licensed for public distribution.
