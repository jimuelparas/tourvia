# Tourvia — Backend Implementation Plan
> **Stack:** Flutter + Firebase (Auth, Firestore, Storage, Cloud Messaging, Cloud Functions)
> **Approach:** One step at a time. Each step is independent and buildable on its own.
> **Status Legend:** `[ ]` Not started · `[/]` In progress · `[x]` Done

---

## Overview of Steps

| Step | Module | What Gets Built |
|------|--------|----------------|
| **Step 1** | Firebase Setup | Install & configure Firebase project |
| **Step 2** | Authentication | Tour Guide register / login / forgot password |
| **Step 3** | Tourist Login | Tourist login via Access Code (no account) |
| **Step 4** | Access Codes | Guide generates codes saved in Firestore |
| **Step 5** | Itinerary | Guide CRUD itinerary; tourist reads in real-time |
| **Step 6** | Attendance | Guide marks attendance per stop; saved to Firestore |
| **Step 7** | Group Chat | Real-time Firestore chat + Firebase Storage for media |
| **Step 8** | Live Tracking | Firestore location updates + boundary alerts |
| **Step 9** | SOS Alerts | Firestore SOS doc + FCM push notifications |
| **Step 10** | Weather | OpenWeatherMap API integration |
| **Step 11** | Chatbot | OpenAI API integration (Philippines-only scope) |
| **Step 12** | Push Notifications | FCM setup for all alert types |

---

## STEP 1 — Firebase Project Setup

**Goal:** Connect the Flutter app to a Firebase project.

### 1.1 Create Firebase Project
- [x] Go to [https://console.firebase.google.com](https://console.firebase.google.com)
- [x] Create a new project named `Tourvia`
- [x] Enable Google Analytics (optional)

### 1.2 Install FlutterFire CLI
- [x] `dart pub global activate flutterfire_cli`

### 1.3 Add Firebase packages to `pubspec.yaml`
- [x] Add `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_messaging`

### 1.4 Configure app for Android + Web
- [x] `flutterfire configure`
This auto-generates `lib/firebase_options.dart`.

### 1.5 Initialize Firebase in `main.dart`
- [x] `await Firebase.initializeApp(...)`

### 1.6 Firestore Data Structure (Top-level collections)
```
/users/{userId}           → Tour guide accounts
/tour_sessions/{sessionId}
  /codes/{codeId}         → Access codes
  /itinerary/{stopId}     → Itinerary stops
  /attendance/{stopId}/records/{touristId}
  /chat/{messageId}       → Chat messages
  /locations/{userId}     → Live GPS locations
  /sos/{alertId}          → SOS alerts
/tourists/{codeId}        → Tourist session (no account)
```

---

## STEP 2 — Tour Guide Authentication (US-01, US-02, US-03)

**Goal:** Real Firebase Auth for Tour Guides.

### 2.1 Files to create
```
lib/core/services/auth_service.dart
lib/features/auth/providers/auth_provider.dart
```

### 2.2 Registration (US-01)
- [x] `AuthService.registerTourGuide(name, email, password, tourGuideId, phone, age)`
- [x] Creates Firebase Auth user
- [x] Writes to Firestore `/users/{uid}` with status: `"pending"`
- [x] Shows "Account pending approval" message on login

### 2.3 Login (US-02)
- [x] `AuthService.loginTourGuide(email, password)`
- [x] After sign-in, check Firestore `/users/{uid}.status`
  - `"pending"` → show pending banner
  - `"rejected"` → show rejected banner
  - `"approved"` → navigate to dashboard

### 2.4 Forgot Password (US-03)
- [x] `AuthService.sendPasswordReset(email)`
- [x] Calls `FirebaseAuth.instance.sendPasswordResetEmail(email: email)`
- [x] Replaces the 2-second fake delay in `forgot_password_screen.dart`

### 2.5 Admin Approval Flow (US-01)
- [ ] Admin Cloud Function or Firestore rule: only `status == "approved"` can access features
- [ ] For now: manually set `status = "approved"` in Firestore console

### 2.6 Firestore Document: `/users/{uid}`
```json
{
  "uid": "...",
  "fullName": "Juan Dela Cruz",
  "email": "juan@email.com",
  "phone": "09171234567",
  "age": 30,
  "tourGuideId": "TG-001",
  "status": "pending",  // pending | approved | rejected
  "createdAt": Timestamp
}
```

---

## STEP 3 — Tourist Login via Access Code (US-04)

**Goal:** Tourist enters a code → looks up Firestore → gets tour session access.

### 3.1 Files to create
```
lib/core/services/access_code_service.dart
```

### 3.2 Flow
- [x] `AccessCodeService.validateCode(code)` → query `/tour_sessions/{sessionId}/codes` where `code == input AND isActive == true`
- [x] If found: save session info to local state (no Firebase Auth account needed)
- [x] Tourist name prompt: ask tourist to enter their name → write to Firestore code doc
- [x] Navigate to `TouristDashboardScreen` with session context

### 3.3 Firestore: Code doc update on tourist login
```json
{
  "code": "TRV-A1B2C3",
  "isActive": true,
  "touristName": "Maria Clara",  // set by tourist on first login
  "claimedAt": Timestamp,
  "sessionId": "..."
}
```

---

## STEP 4 — Access Code Generation (US-06)

**Goal:** Guide generates codes; saved to Firestore; tourists can claim them.

### 4.1 Files to modify
```
lib/features/tour_guide/screens/tour_guide_access_log_screen.dart
lib/core/services/access_code_service.dart
```

### 4.2 Generate codes
- [x] `AccessCodeService.generateCodes(sessionId, count)` → batch write to Firestore
- [x] Each code doc: `{ code, isActive: true, touristName: null, createdAt }`
- [x] Replace `_generateCodes()` local method with Firestore batch write

### 4.3 Real-time code list
- [x] Use `StreamBuilder` on `/tour_sessions/{id}/codes` to show live code list
- [x] Show tourist names as they claim codes (real-time update)

### 4.4 Delete / Invalidate code
- [x] `AccessCodeService.deactivateCode(codeId)` → sets `isActive: false`
- [x] Replace local `_deleteCode()` with Firestore update

---

## STEP 5 — Tour Itinerary (US-07, US-08, US-09)

**Goal:** Guide creates/edits itinerary in Firestore; tourist sees it live.

### 5.1 Files to create/modify
```
lib/core/services/itinerary_service.dart
lib/features/tour_guide/screens/tour_guide_itinerary_screen.dart  (connect stream)
lib/features/tourist/screens/tourist_itinerary_screen.dart        (connect stream)
```

### 5.2 Guide — CRUD
- [x] `ItineraryService.addStop(sessionId, stop)` → Firestore add
- [x] `ItineraryService.updateStop(sessionId, stopId, data)` → Firestore update
- [x] `ItineraryService.deleteStop(sessionId, stopId)` → Firestore delete
- [x] `ItineraryService.reorderStops(sessionId, orderedIds)` → batch update `order` field
- [x] Replace all `setState()` local list mutations with service calls

### 5.3 Tourist — Real-time read
- [x] `ItineraryService.watchItinerary(sessionId)` → `Stream<List<ItineraryItem>>`
- [x] Wrap tourist itinerary screen in `StreamBuilder`

### 5.4 Firestore: `/tour_sessions/{id}/itinerary/{stopId}`
```json
{
  "destinationName": "Intramuros",
  "date": Timestamp,
  "startTime": "10:00 AM",
  "endTime": "12:30 PM",
  "notes": "Historical walking tour",
  "order": 2,
  "updatedAt": Timestamp
}
```

---

## STEP 6 — Attendance Monitoring (US-10, US-26)

**Goal:** Guide marks attendance per stop; saved to Firestore with timestamps.

### 6.1 Files to create
```
lib/core/services/attendance_service.dart
```

### 6.2 Service methods
- [x] `AttendanceService.markAttendance(sessionId, stopId, touristId, status)`
  → writes to `/tour_sessions/{id}/attendance/{stopId}/records/{touristId}`
- [x] `AttendanceService.watchAttendance(sessionId, stopId)` → stream
- [x] `AttendanceService.watchRoster(sessionId)` → stream of all joined tourists
- [x] Replace all local `setState` attendance changes with service calls
- [x] Tourist itinerary shows own real-time attendance status per stop

### 6.3 Firestore: attendance record
```json
{
  "touristId": "TRV-A1B2C3",
  "touristName": "Maria Clara",
  "status": "present",  // present | absent | late
  "checkInTime": Timestamp,
  "stopId": "...",
  "sessionId": "..."
}
```

---

## STEP 7 — Group Chat (US-19, US-20)

**Goal:** Real-time Firestore chat; Firebase Storage for photos/videos.

### 7.1 Files to create
```
lib/core/services/chat_service.dart
```

### 7.2 Text messages
- [x] `ChatService.sendMessage(sessionId, message)` → Firestore add to `/chat/{messageId}`
- [x] `ChatService.watchMessages(sessionId)` → stream ordered by timestamp
- [x] Replace mock `_messages` list with `StreamBuilder`

### 7.3 Media (photos/videos)
- [x] `ChatService.uploadMedia(sessionId, file)` → upload to Firebase Storage at `/chat/{sessionId}/{filename}`
- [x] Get download URL → save to message doc with `isMedia: true, mediaUrl: url`
- [x] Add `image_picker` package for camera/gallery access

### 7.4 Firestore: `/tour_sessions/{id}/chat/{messageId}`
```json
{
  "senderId": "uid or code",
  "senderName": "Juan",
  "isGuide": true,
  "text": "Meet at the gate!",
  "isMedia": false,
  "mediaUrl": null,
  "timestamp": Timestamp
}
```

---

## STEP 8 — Live Location Tracking (US-11, US-12, US-13, US-14, US-15, US-16)

**Goal:** Real GPS updates → Firestore → guide sees all tourist markers.

### 8.1 Packages to add
```yaml
geolocator: ^13.x.x
mapbox_maps_flutter: ^2.x.x  # already in project
```

### 8.2 Files to create
```
lib/core/services/location_service.dart
```

### 8.3 Location publishing (Tourist device)
- [ ] `LocationService.startPublishing(sessionId, touristId)` → periodic Firestore writes
- [ ] Writes to `/tour_sessions/{id}/locations/{touristId}` every 15 seconds
- [ ] Location doc: `{ lat, lng, accuracy, updatedAt }`

### 8.4 Location watching (Guide)
- [ ] `LocationService.watchAllLocations(sessionId)` → stream of all tourist locations
- [ ] Update `TourGuideMapScreen` to render real markers from stream

### 8.5 Boundary Check (1 km)
- [ ] Calculate distance from session center using `Geolocator.distanceBetween()`
- [ ] If `distance > 1000m` → trigger alert (Step 12 handles push notification)

### 8.6 Ring Tourist (US-15)
- [ ] Write `{ ringCommand: true }` to tourist's location doc
- [ ] Tourist device watches doc → plays sound when `ringCommand == true`

---

## STEP 9 — SOS Alerts (US-18)

**Goal:** One-tap SOS → Firestore alert → FCM push to all others.

### 9.1 Files to create
```
lib/core/services/sos_service.dart
```

### 9.2 Send SOS
- [ ] `SosService.sendAlert(sessionId, senderId, senderName, lat, lng)`
- [ ] Writes to `/tour_sessions/{id}/sos/{alertId}`
- [ ] Triggers a Cloud Function → sends FCM to all session members

### 9.3 Watch SOS (Recipients)
- [ ] `SosService.watchAlerts(sessionId)` → stream
- [ ] Guide and tourists see SOS log in real-time

### 9.4 Firestore: SOS alert doc
```json
{
  "senderId": "...",
  "senderName": "Maria Clara",
  "lat": 14.5995,
  "lng": 120.9842,
  "timestamp": Timestamp,
  "isResolved": false
}
```

---

## STEP 10 — Weather Integration (US-17)

**Goal:** Replace mock weather data with real OpenWeatherMap API.

### 10.1 Packages to add
```yaml
http: ^1.x.x
```

### 10.2 Files to create
```
lib/core/services/weather_service.dart
```

### 10.3 API Call
- [ ] `WeatherService.getCurrentWeather(lat, lng)` → GET `api.openweathermap.org/data/2.5/weather`
- [ ] `WeatherService.getForecast(lat, lng)` → GET `.../forecast` (5-day/3-hour)
- [ ] Map API response to weather model
- [ ] Replace hardcoded weather data in `weather_screen.dart` with real data
- [ ] Store API key securely using `flutter_dotenv` package

### 10.4 Weather model
```dart
class WeatherData {
  final String description;
  final double tempC;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final List<HourlyForecast> hourly;
}
```

---

## STEP 11 — AI Chatbot Integration (US-21)

**Goal:** Replace simulated bot responses with real OpenAI API calls.

### 11.1 Packages to add
```yaml
http: ^1.x.x
flutter_dotenv: ^5.x.x
```

### 11.2 Files to create
```
lib/core/services/chatbot_service.dart
```

### 11.3 API Integration
- [x] `ChatbotService.ask(userMessage)` → POST `https://api.openai.com/v1/chat/completions`
- [x] System prompt enforces Philippines-only scope:
  ```
  "You are a helpful assistant for Tourvia, a Philippine tourism app.
   Only answer questions about tourist destinations in the Philippines.
   If asked about anything else, politely decline and redirect."
  ```
- [x] Store API key in `.env` file (never commit to Git — added to .gitignore)
- [x] Replace `_getBotAnswer()` in `chatbot_screen.dart` with real `ChatbotService.ask()` call
- [x] `.env` registered as Flutter asset in `pubspec.yaml`
- [x] `flutter_dotenv` initialized in `main.dart` before `Firebase.initializeApp()`

---

## STEP 12 — Push Notifications via FCM (US-12, US-15, US-16, US-17, US-18, US-19)

**Goal:** Firebase Cloud Messaging for all alerts.

### 12.1 Setup
- [ ] Add `firebase_messaging` package
- [ ] Request notification permissions on app start
- [ ] Save FCM token to Firestore on login: `/users/{uid}.fcmToken`

### 12.2 Cloud Functions (Node.js)
Create Cloud Functions triggered by Firestore writes:

| Trigger | Function | Recipients |
|---------|----------|-----------|
| New SOS doc created | `onSosAlert` | All session members |
| Boundary breach detected | `onBoundaryBreach` | Tour guide |
| Ring command set | `onRingTourist` | Specific tourist |
| New chat message | `onNewChatMessage` | All session members |
| Severe weather detected | `onWeatherAlert` | All session members |

### 12.3 Foreground + Background handling
```dart
FirebaseMessaging.onMessage.listen((msg) { /* show in-app banner */ });
FirebaseMessaging.onBackgroundMessage(handleBackground);
```

---

## Recommended Execution Order

```
Step 1  →  Step 2  →  Step 3  →  Step 4
              ↓
           Step 5  →  Step 6
              ↓
           Step 7
              ↓
           Step 8  →  Step 9
              ↓
           Step 10  →  Step 11
              ↓
           Step 12
```

Start with **Step 1** (Firebase setup) before anything else since all other steps depend on it.

---

## Notes
- Each step can be done and tested independently before moving to the next.
- Never commit `.env`, `google-services.json`, or `firebase_options.dart` API keys to public repositories.
- Use Firestore Security Rules to protect data per session and per role.
- The `dataconnect_generated/` folder in the project is from a previous Firebase Data Connect attempt — it can be removed once we set up the standard Firestore approach.
