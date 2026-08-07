# TOURVIA: Screen-by-Screen User Workflow & Navigation Manual

This manual provides a detailed walkthrough of the **TOURVIA** application, following the exact chronological journey of a user from the moment they launch the app to the final teardown of a tour session. It outlines what is displayed on every screen, the interactive buttons/menus available, and the resulting actions and screen transitions.

---

## 1. App Startup & Entry Phase

### 1.1 Splash Screen (Initial Boot)
*   **What is Displayed:**
    *   A clean, modern background with the central TOURVIA brand icon (a compass rose/exploration icon inside an HSL gradient square).
    *   A subtle loading spinner or entry transition.
*   **Interactive Controls:** None (automated boot transition).
*   **Navigation & Transition:**
    *   The app initializes Firebase, loads `.env` API keys, and checks local auth state.
    *   Upon completion, it executes a logo scale-in animation and redirects to the **Welcome & Role Selection Screen**.

### 1.2 Welcome & Role Selection Screen (`RoleSelectionScreen`)
*   **What is Displayed:**
    *   A centered TOURVIA logo with a subtle glow animation.
    *   Title: *"Welcome to Tourvia"*
    *   Subtitle: *"Your digital tour management and safety companion in the Philippines."*
    *   Section label: *"SELECT YOUR ROLE TO START"*
    *   Two prominent interactive cards:
        1.  **Tour Guide Card:** Featuring a badge icon and description (*"Register or log in to manage your tours, plan itineraries, and track tourists."*).
        2.  **Tourist Card:** Featuring a hiking icon and description (*"Enter an access code provided by your guide to join a tour."*).
*   **Interactive Controls & Button Actions:**
    *   **Tap "Tour Guide" Card:** Executes a scale-down press animation and transitions to the **Tour Guide Login Screen**.
    *   **Tap "Tourist" Card:** Executes a scale-down press animation and transitions to the **Tourist Login Screen**.

---

## 2. Authentication & Onboarding Phase

### 2.1 Tour Guide Login Screen (`TourGuideLoginScreen`)
*   **What is Displayed:**
    *   Back Navigation Button (left-aligned at top).
    *   Title: *"Tour Guide Login"*
    *   Subtitle: *"Log in to access your dashboard and manage active tour sessions."*
    *   Text Input Form:
        *   *Email Address Field* (with prefix icon).
        *   *Password Field* (with suffix hide/show visibility eye icon).
    *   Text Link: *"Forgot Password?"*
    *   Link Text: *"Don't have an account? Register here."*
*   **Interactive Controls & Button Actions:**
    *   **Back Button:** Navigates back to the **Welcome Screen**.
    *   **Password Eye Icon:** Toggles the input text obscure state (revealing/hiding the password characters).
    *   **Click "Forgot Password?":** Opens the **Forgot Password Screen**.
    *   **Click "Register here":** Transitions the screen to the **Tour Guide Registration Screen**.
    *   **Click "Log In" Button:**
        *   Triggers form validation.
        *   Sends credentials to Firebase Auth.
        *   Checks Firestore profile status.
        *   *Success transition:* Goes to the **Tour Guide Dashboard Screen** (if status is `approved`).
        *   *Error state:* Displays alert dialog showing error message (e.g. *"Account pending approval"*).

### 2.2 Tour Guide Registration Screen (`TourGuideRegistrationScreen`)
*   **What is Displayed:**
    *   Back Navigation Button.
    *   Title: *"Guide Registration"*
    *   Form Fields:
        *   *Full Name Field* (Text)
        *   *Age Field* (Number, must be >= 18)
        *   *Email Address Field* (validated format)
        *   *Contact Number Field* (Philippine number validation)
        *   *Tour Guide ID Field* (Accreditation number input)
        *   *Password Field* (obscurable, min 8 chars)
        *   *Confirm Password Field* (obscurable, must match password)
    *   Image Selection Box: *"Upload Photo of DOT Tour Guide ID"* (displays preview thumbnail if an image is selected).
    *   Link Text: *"Already have an account? Log in."*
*   **Interactive Controls & Button Actions:**
    *   **Click "Upload Photo of DOT Tour Guide ID":** Opens a bottom sheet menu offering:
        1.  *Take a Photo* (launches device camera).
        2.  *Choose from Gallery* (opens photo library).
    *   **Selecting Source (Camera/Gallery):** Triggers image picking. On success, updates the image box with the selected photo preview.
    *   **Click "Register & Verify" Button:**
        *   Runs all form field validations.
        *   If validations pass and an ID image is present, displays the **AI Verification Progress Overlay**.

### 2.3 AI Verification Progress Overlay
*   **What is Displayed:**
    *   A full-screen modal barrier with a loading indicator.
    *   Title: *"Verifying Accreditation ID"*
    *   Subtitle: *"Google Gemini is analyzing the card formatting, logos, and checking expiration details..."*
*   **Interactive Controls:** Locked (user must wait for API resolution).
*   **Transitions:**
    *   **On Success:** Moves to the **Registration Success Screen**.
    *   **On Failure:** Dismisses the overlay and shows a rejection alert dialog:
        *   *Alert Title:* *"Verification Failed"*
        *   *Alert Body:* Lists the detailed failure reason returned by Gemini (e.g., *"Rejection Reason: Expiry date on card shows 2025-12-31, which is expired. Photo must be a valid, unexpired DOT Accreditation Card."*).
        *   *Action Button:* *"OK"* (returns user to the registration form to fix details or capture a clearer image).

### 2.4 Registration Success Screen (`RegistrationSuccessScreen`)
*   **What is Displayed:**
    *   A large checkmark graphic.
    *   Title: *"Verification Successful!"*
    *   Subtitle: *"Your Department of Tourism Tour Guide ID has been verified by our AI system. Your account is auto-approved and active."*
*   **Interactive Controls & Button Actions:**
    *   **Click "Go to Dashboard" Button:** Transitions to the **Tour Guide Dashboard Screen** and automatically signs in the user.

### 2.5 Forgot Password / Password Reset Screen (`ForgotPasswordScreen`)
*   **What is Displayed:**
    *   Back Navigation Button.
    *   Title: *"Reset Password"*
    *   Subtitle: *"Enter your email address and we will send you instructions to reset your password."*
    *   Text Input Form: *Email Address Field*.
*   **Interactive Controls & Button Actions:**
    *   **Click "Send Instructions" Button:**
        *   Validates email format.
        *   Dispatches password reset request via Firebase Auth.
        *   Shows a success dialog: *"Reset email sent. Check your inbox for further instructions."* Clicking *"Close"* returns the user to the **Tour Guide Login Screen**.

### 2.6 Tourist Login Screen (`TouristLoginScreen`)
*   **What is Displayed:**
    *   Back Navigation Button.
    *   Title: *"Join a Tour"*
    *   Subtitle: *"Enter the access code provided by your tour guide to access the tour map, itinerary, and group chat."*
    *   Text Input Form:
        *   *Access Code Field* (formatted input mask, auto-capitalizes alphanumeric characters).
        *   *Your Name Field* (Tourist name entry).
*   **Interactive Controls & Button Actions:**
    *   **Click "Join Tour" Button:**
        *   Validates that both fields are filled.
        *   Checks the code against active Firestore codes.
        *   *Success state:* Saves the user session details and navigates to the **Terms & Conditions Screen**.
        *   *Error state:* Displays error message (e.g., *"Invalid access code. Please check the code and try again."*).

### 2.7 Terms & Conditions Screen (`TermsAndConditionsScreen`)
*   **What is Displayed:**
    *   Title: *"Terms and Conditions"*
    *   Scrollable document detailing user responsibilities.
    *   A highlighted safety warning regarding the **Geofencing Location Disclosure**: *"TOURVIA collects real-time location data to enable live tracking by your guide and generate safety boundary alerts even when the app is in the background."*
    *   Two buttons at the bottom: *"Decline"* and *"Accept & Proceed"*.
*   **Interactive Controls & Button Actions:**
    *   **Click "Decline":** Returns the tourist to the **Tourist Login Screen** (wiping the pending session).
    *   **Click "Accept & Proceed":** Prompts the device for Location Permissions. On approval, saves the tourist's token and routes to the **Tourist Dashboard Screen**.

---

## 3. Tour Guide Core Modules & Navigation Flow

### 3.1 Tour Guide Dashboard (`TourGuideHomeScreen`)
*   **What is Displayed:**
    *   Header: Welcome greeting, guide's name, and a Profile Avatar shortcut.
    *   **Active Tour Banner:**
        *   Gradient card displaying Tour Name, status tag (*"Active"* or *"Ended"*), day indicator, and joined tourist count.
        *   *If Tour Active:* Displays a *"End Tour"* button inside the card.
    *   **Emergency SOS Banner:** Only appears if an active SOS alert exists (pulsing red, showing the names of tourists in distress).
    *   **Quick Modules Grid:** Contains 8 clickable cards:
        1.  *Itinerary*
        2.  *Attendance*
        3.  *Tracking*
        4.  *Messages*
        5.  *Weather*
        6.  *SOS Log*
        7.  *AI Assistant*
        8.  *Access Code*
*   **Interactive Controls & Button Actions:**
    *   **Click Profile Avatar:** Navigates to the **Settings & Profile Screen**.
    *   **Click "End Tour" Button:** Launches the **Tour End Confirmation Dialog**.
    *   **Click SOS Banner:** Navigates to the **SOS Screen**.
    *   **Click Grid Card (e.g., "Access Code"):** Routes to that specific module screen (detailed below).

### 3.2 Access Code Management Module (`TourGuideAccessLogScreen`)
*   **What is Displayed:**
    *   Back Button.
    *   Title: *"Tourist Access Codes"*
    *   **Summary Stats Bar:** Cards showing *Total Codes*, *Joined Codes* (claimed), and *Waiting Codes* (unclaimed).
    *   Information Banner explaining tourist names are set on login.
    *   **Codes List View:** Shows generated codes with a status color indicator (Green = Joined, Orange = Waiting). For claimed codes, displays the tourist's name and join timestamp.
    *   Floating Action Button (FAB): *"Generate Code"*.
*   **Interactive Controls & Button Actions:**
    *   **Click "Generate Code" FAB:** Opens the **Generate Access Codes Dialog**:
        *   *Dialog Content:* Stepper controls showing code quantity count (1 to 50), and quick-selection chips (*5*, *10*, *20*).
        *   *Click Minus/Plus:* Adjusts the count.
        *   *Click Quick Selection Chip:* Sets the counter to that specific quantity.
        *   *Click "Cancel":* Closes the dialog.
        *   *Click "Generate":* Dispatches batch creation, showing a success SnackBar.
    *   **Swipe Code Card to Left (or Click Trash Icon):** Triggers a delete confirmation dialog. Confirming permanently invalidates the code.
    *   **Click Copy Icon:** Copies the code string directly to the clipboard.
    *   **Click "Clear" Button (Claimed Codes Only):** Launches the *"Clear Name"* dialog. Confirming resets the code slot, allowing it to be used by a new tourist.

### 3.3 Itinerary Builder Module (`TourGuideItineraryScreen`)
*   **What is Displayed:**
    *   Back Button.
    *   Tour Title with an Edit Icon.
    *   **Dynamic Weather Widget:** Displays current temp, conditions, and rain probability for the tour city, with a click action.
    *   **Stops Timeline List:** Vertical timeline list showing stop order numbers, destination names, times, notes, and drag handles.
    *   Floating Action Button (FAB): *"Add Stop"*.
*   **Interactive Controls & Button Actions:**
    *   **Click Edit Icon (next to Tour Title):** Opens a dialog to edit the Tour Title, Current Day, and Total Days. Saving updates the Firebase metadata.
    *   **Click Weather Widget:** Navigates to the detailed **Weather Screen**.
    *   **Long-Press Drag Handle & Move Card:** Uses `ReorderableListView` to reorder stops. Releasing saves the new order sequence to Firestore.
    *   **Click Edit Stop Button (pencil icon):** Navigates to the **Add/Edit Stop Screen** pre-filled with data.
    *   **Click Delete Stop Button (trash icon):** Shows a confirmation dialog. Confirming removes the stop.
    *   **Click Attendance row (bottom of card):** Navigates to the **Stop Attendance Screen** for that stop.
    *   **Click "Add Stop" FAB:** Navigates to the **Add/Edit Stop Screen** (empty state).

#### 3.3.1 Add/Edit Stop Screen (`AddEditItineraryScreen`)
*   **What is Displayed:**
    *   Back Button.
    *   Title: *"Add Stop"* or *"Edit Stop"*.
    *   Form inputs:
        *   *Destination Name Field* (with search/suggestions list overlay).
        *   *Date Selection Field*.
        *   *Start Time & End Time Selection Fields*.
        *   *Notes Field* (multi-line).
*   **Interactive Controls & Button Actions:**
    *   **Type Destination Name:** Shows a suggestion overlay list of curated tourist spots. Clicking a suggestion fills the text field automatically.
    *   **Click Date/Time fields:** Launches native system Date and Time Picker dialogs. Selecting details updates the fields.
    *   **Click "Save Stop" Button:** Validates the inputs, writes the stop coordinates/details to Firestore, and returns to the Itinerary screen.

---

### 3.4 Tourist Attendance Module (`TourGuideAttendanceScreen`)
*   **What is Displayed:**
    *   Back Button.
    *   Map Icon button on AppBar.
    *   **Tabs Selector:** *"All Tourists"* and *"By Destination"*.
*   **Tab 1: All Tourists**
    *   Shows a roster list of all joined tourists in alphabetical order with their access code.
*   **Tab 2: By Destination**
    *   *Dropdown Field:* Select stop (shows stops list).
    *   *Mini Stats Board:* Counter grids for *Present*, *Absent*, and *Pending*.
    *   *Roster list:* Displays tourists showing check-in time and status.
    *   *Button:* *"Mark All Present"* (appears if pending tourists exist).
*   **Interactive Controls & Button Actions:**
    *   **Click Map Icon:** Opens the **Tour Guide Map Screen**.
    *   **Click Stop Dropdown:** Selects a stop, loading its attendance logs.
    *   **Click "Mark All Present":** Marks all pending tourists as *Present* for the stop.
    *   **Click Present Button (Checkmark Icon):** Marks the tourist as *Present*.
    *   **Click Absent Button (X Icon):** Marks the tourist as *Absent*.

---

### 3.5 SOS Logs & Emergency Panel (`SosScreen` - Guide View)
*   **What is Displayed:**
    *   Back Button.
    *   A large pulsing SOS button.
    *   **Tabs Selector:** *"SOS Logs"* and *"Safety Tips"*.
    *   **Logs list:** Lists active and resolved emergency alerts, showing user details, timestamp, and status.
*   **Interactive Controls & Button Actions:**
    *   **Click "View on Map" Button (Log Tile):** Launches external maps (native Maps or Google Maps browser) showing navigation to the alert's GPS coordinates.
    *   **Click "Resolve" Button (Log Tile):** Updates the alert status to resolved, changing the tile color to green and stopping FCM warnings.

---

## 4. Tourist Core Modules & Navigation Flow

### 4.1 Tourist Dashboard (`TouristHomeScreen`)
*   **What is Displayed:**
    *   Header greeting and Settings icon shortcut.
    *   **Active Tour Details Card:** Shows tour name, active day, participants count, and guide's name.
    *   **Quick Modules Grid:** Cards for: *Tracking*, *Group Chat*, *Weather*, *SOS/Help*, and *AI Assistant*.
*   **Interactive Controls & Button Actions:**
    *   **Click Settings Icon:** Navigates to the **Settings Screen**.
    *   **Click Dashboard Tour Card:** Navigates to the **Tourist Itinerary Screen**.
    *   **Click Grid Card (e.g., "Tracking"):** Opens the respective module.

### 4.2 Tourist Itinerary Screen (`TouristItineraryScreen`)
*   **What is Displayed:**
    *   Back Button.
    *   App Title: Active Tour Name.
    *   **Timeline List (Read-Only):**
        *   Shows stops with scheduled times, notes, and a status label showing the tourist's attendance status (*"Present"*, *"Absent"*, or *"Pending"*).
*   **Interactive Controls:** Read-only timeline scroll.

### 4.3 Tourist Live Map Screen (`TouristMapScreen`)
*   **What is Displayed:**
    *   Circular Back Button (AppBar overlay).
    *   **Interactive OpenStreetMap View:** Plots the location of the guide (blue flag) and tourist (green marker).
    *   **1 km Safety Circle:** Transparent red overlay circle centered on the guide.
    *   **Distance Details Card:** Displays distance in meters and safety status (*"Within safe zone"* or *"Outside boundary"*).
    *   **Boundary Warning Banner:** Appears only if the tourist goes beyond 1 km, displaying a warning: *"Boundary Alert: Return to safe area!"*.
    *   **Action Button:** *"Navigate to Guide"*.
*   **Interactive Controls & Button Actions:**
    *   **Click "Navigate to Guide":** Opens Google Maps walking navigation from the tourist's current coordinates to the guide's position.

### 4.4 SOS Panic Trigger Module (`SosScreen` - Tourist View)
*   **What is Displayed:**
    *   Back Button.
    *   **Large Pulsing Red SOS Button:** Occupies the upper half of the screen.
    *   Tabs: *"SOS Logs"* and *"Safety Tips"*.
    *   Log view showing only the tourist's own alerts.
*   **Interactive Controls & Button Actions:**
    *   **Tap SOS Button:** Launches the **SOS Confirmation Dialog**.
    *   **Confirm Alert:**
        *   Gets the device's current GPS coordinates.
        *   Triggers the device vibration buzzer.
        *   Sends the alert to Firestore and triggers FCM alerts for the guide.

---

## 5. Collaborative Features (Guides & Tourists)

### 5.1 Tour Group Chat Screen (`GroupChatScreen`)
*   **What is Displayed:**
    *   Back Button.
    *   App Title: *"Tour Group Chat"*, displaying participant count and online status.
    *   **Message Stream:** Scrollable thread showing messages labeled with the sender's name and role (e.g., *Guide* or *Tourist*).
        *   *If media:* Displays the shared image in a preview card.
    *   **Upload Progress Bar:** Appears only during file uploads, showing a progress percentage.
    *   **Input Dock:** Text input field with an attachment icon (plus/image icon) and a send button.
*   **Interactive Controls & Button Actions:**
    *   **Click Attachment Icon:** Opens a bottom sheet menu option:
        *   *Take a Photo* (camera).
        *   *Choose from Gallery* (media picker).
        *   Selecting an image uploads it to Storage, updates the progress bar, and sends the message.
    *   **Click Send Button:** Sends the typed text to the chat.
    *   **Tap Shared Chat Image:** Opens the image in full-screen view.

### 5.2 AI Assistant Screen (`ChatbotScreen`)
*   **What is Displayed:**
    *   Back Button.
    *   App Title showing: *"AI Assistant - Powered by GPT-4o mini"*.
    *   **Conversation Area:** Displays conversation bubbles between user and chatbot.
    *   **Quick Prompts Chips List:** Horizontal chips list showing popular destinations (e.g., *"🏰 Intramuros"*, *"🏖️ Boracay"*).
    *   **Input Dock:** Text entry field and send button.
*   **Interactive Controls & Button Actions:**
    *   **Click Quick Prompt Chip:** Submits the destination name as a query immediately.
    *   **Click Send Button:** Sends the entered question to the chatbot, displaying a pulsing typing dot indicator during processing.

### 5.3 Live Map & Tracking Screen (Guide View - `TourGuideMapScreen`)
*   **What is Displayed:**
    *   Back Button.
    *   Interactive OpenStreetMap view with:
        *   Guide position marker.
        *   1 km geofence boundary circle overlay.
        *   Tourist markers (color-coded: Green = Safe, Red = Out-of-bounds).
    *   **Status Counter Bar (top overlay):** Displays count statistics: *X Safe*, *Y Outside*.
    *   Recenter Button (lower right).
    *   **Selected Tourist Quick-Card:** Appears at the bottom when a tourist marker is tapped.
*   **Interactive Controls & Button Actions:**
    *   **Click Tourist Marker on Map:** Displays the **Selected Tourist Quick-Card**:
        *   *Card Details:* Name, distance, boundary status, and action buttons.
        *   *Click "Ring" Button:* Sends a ring signal to the tourist's device, triggering alarms.
        *   *Click "Navigate" Button:* Opens Google Maps walking navigation to the tourist's location.
        *   *Click Close (X icon):* Dismisses the card.
    *   **Click "Recenter" FAB:** Centers the map view on the guide's location.
    *   **Swipe Up Bottom Sheet Handle:** Opens the full **Tourist Management Panel**.

#### 5.3.1 Tourist Management Panel
*   **What is Displayed:**
    *   Scrollable bottom sheet list showing all tourists.
    *   Header actions: *"Ring All"* button.
    *   Filter tools: *"Outside Only"* checkbox chip, and a sorting dropdown (*Sort: Name*, *Sort: Distance*, *Sort: Status*).
*   **Interactive Controls & Button Actions:**
    *   **Click "Ring All" Button:** Sends a ring command to all tourists, displaying a confirmation message.
    *   **Toggle "Outside Only" Filter:** Filters the list to show only tourists outside the 1 km boundary.
    *   **Change Sort Dropdown:** Re-sorts the list based on selection.
    *   **Click a Tourist Card:** Closes the panel and centers the map view on that tourist.

---

## 6. Profile, Settings & Tour Teardown Phase

### 6.1 Settings & App Info Screen (`SettingsScreen`)
*   **What is Displayed:**
    *   Back Button.
    *   Title: *"Settings"*
    *   Menu Options:
        *   *View/Edit Profile* (guides only).
        *   *About Application*.
        *   *About Developers*.
        *   *References*.
        *   *Terms and Conditions*.
        *   *Log Out*.
*   **Interactive Controls & Button Actions:**
    *   **Click Menu Option:** Opens the corresponding information screen or dialog.
    *   **Click "Log Out":** Opens a logout confirmation dialog. Confirming returns the user to the **Welcome Screen** and clears local authentication states.

### 6.2 Guide Profile Management Screen (`ProfileScreen`)
*   **What is Displayed:**
    *   Back Button.
    *   Profile Picture Avatar (displays placeholder if empty).
    *   Form fields showing Full Name, Contact Number, Email Address, and Address. The Tour Guide ID is displayed as a read-only field.
    *   Buttons: *"Update Profile"* and *"Change Password"*.
*   **Interactive Controls & Button Actions:**
    *   **Tap Profile Avatar Image:** Opens a photo source dialog (Camera/Gallery) to update the picture.
    *   **Click "Update Profile":** Validates fields, updates the Firestore document, and returns to the Settings screen.
    *   **Click "Change Password":** Opens a secure change password modal:
        *   *Modal Fields:* Current Password, New Password, Confirm New Password.
        *   *Click Save:* Re-authenticates the current password and updates to the new password.

### 6.3 Tour Teardown: End Tour Workflow
*   **What is Displayed:**
    *   Warning dialog prompted when a guide ends an active tour.
    *   Lists the actions that will be performed:
        *   *Invalidate all access codes.*
        *   *Remove all participants & attendance records.*
        *   *Delete live tracking data & chat messages.*
        *   *Delete SOS alerts.*
    *   Confirmation input field: *"Type END to confirm"*.
*   **Interactive Controls & Button Actions:**
    *   **Type text in "Type END to confirm" Field:** Validates input. The *"End Tour"* action button remains disabled until "END" is entered.
    *   **Click "End Tour" Action Button (Active only after typing END):**
        *   Closes the dialog and shows a loading overlay.
        *   Executes Firestore batch deletes to clear temporary session data.
        *   Upon completion, displays a success snackbar: *"Tour ended successfully. All temporary data cleared."*
        *   Updates the dashboard banner to show the tour status as ended.

---

> **Workflow Document Version:** 1.0  
> **Documentation Target:** TOURVIA App Client Navigation Walkthrough
