# E. Performance Test Result (iOS)

| Module | Action | Concurrent Users | Pacing Time | Response Time |
| :--- | :--- | :--- | :--- | :--- |
| Role Selection | Display the splash screen when the application is loaded. | 100 | 2.0s | 1.12s |
| | Display the role selection screen presenting options for Tour Guide and Tourist. | 100 | 2.0s | 0.24s |
| | Allows the user to tap the "Tour Guide" button. | 100 | 2.0s | 0.15s |
| | Display the Tour Guide authentication screen. | 100 | 2.0s | 0.28s |
| Registration | Tour guide inputs full name, age, email address, and contact number. | 100 | 2.0s | 0.85s |
| | Tour guide uploads the Department of Tourism (DOT) Tour Guide ID image. | 100 | 2.0s | 1.50s |
| | System initiates AI-powered verification to validate the DOT ID image. | 100 | 2.0s | 3.25s |
| | Upon successful verification, automatically approve and activate the account. | 100 | 2.0s | 0.65s |
| Login | Tour guide inputs registered email in the email field. | 100 | 2.0s | 0.45s |
| | Tour guide inputs password in the password field. | 100 | 2.0s | 0.45s |
| | Tour guide taps the login button. | 100 | 2.0s | 0.15s |
| | If credentials are invalid, display alert saying "Invalid Credentials" | 100 | 2.0s | 0.85s |
| | If credentials are correct, display the Tour Guide Dashboard. | 100 | 2.0s | 1.20s |
| | Display the login module. | 100 | 2.0s | 0.25s |
| Forgot Password | Tour guide inputs registered email address. | 100 | 2.0s | 0.65s |
| | System sends verify to the registered email. | 100 | 2.0s | 1.15s |
| | Tour guide inputs new password and confirms new password | 100 | 2.0s | 0.80s |
| | Tour guide taps the reset password button. | 100 | 2.0s | 0.15s |
| | Display message "Password Reset Success". | 100 | 2.0s | 0.75s |
| Dashboard | Display active tour status and quick feature access links upon system entry. | 100 | 2.0s | 0.85s |
| | Display summary statistics of active tours, registered tourists, and recent tour activities. | 100 | 2.0s | 0.65s |
| | Tour guide taps any quick access feature button to navigate to the selected module. | 100 | 2.0s | 0.20s |
| Generate Access Code | Tour guide taps the "Generate Code" button. | 100 | 2.0s | 0.15s |
| | System creates a unique access code assigned to the active tour instance. | 100 | 2.0s | 0.65s |
| | Display generated access code list. | 100 | 2.0s | 0.35s |
| | Tour guide taps the "Copy Code" button to copy code to clipboard. | 100 | 2.0s | 0.10s |
| | Tour guide taps the "Delete Code" button for unused codes. | 100 | 2.0s | 0.15s |
| | Display confirmation modal "Delete Access Code?". | 100 | 2.0s | 0.25s |
| | If tour guide taps confirm, remove code and display "Delete Success". | 100 | 2.0s | 0.55s |
| Itinerary Management | Tour guide views destination schedule and activity lists. | 100 | 2.0s | 0.75s |
| | Tour guide taps "Add Itinerary" button. | 100 | 2.0s | 0.15s |
| | Input destination name, scheduled time, meeting location, and activity details. | 100 | 2.0s | 1.10s |
| | Browse municipality-based recommended destination list. | 100 | 2.0s | 0.85s |
| | Select recommended spot to automatically populate destination details. | 100 | 2.0s | 0.35s |
| | Tour guide taps "Save Itinerary" button. | 100 | 2.0s | 0.15s |
| | Display "Itinerary Updated". | 100 | 2.0s | 0.65s |
| Attendance Monitoring | Display list of scheduled itinerary destinations. | 100 | 2.0s | 0.55s |
| | Tour guide selects a specific destination. | 100 | 2.0s | 0.20s |
| | Display list of enrolled tourists for the active tour. | 100 | 2.0s | 0.65s |
| | Tour guide marks tourist presence (Present / Absent) for the selected destination. | 100 | 2.0s | 0.35s |
| | System updates and saves attendance records in real-time. | 100 | 2.0s | 0.75s |
| Live Location Tracking & Navigation | Display interactive map rendering real-time locations of all active tourists. | 100 | 2.0s | 1.45s |
| | Tour guide selects a specific tourist pin on the map. | 100 | 2.0s | 0.30s |
| | Display tourist info card (Name, current status, distance). | 100 | 2.0s | 0.25s |
| | Tour guide taps "Ring Tourist" button to emit an audible alarm on the tourist's device. | 100 | 2.0s | 0.15s |
| | Tour guide taps "Navigate" button. | 100 | 2.0s | 0.15s |
| | Redirect to turn-by-turn GPS navigation toward the tourist's current location. | 100 | 2.0s | 1.15s |
| Group Chat | Display active tour group message thread. | 100 | 2.0s | 0.85s |
| | Tour guide inputs text message in the chat bar and taps send. | 100 | 2.0s | 0.45s |
| | Tour guide taps attachment icon to capture or upload an image. | 100 | 2.0s | 0.15s |
| | Display uploaded image in the message thread. | 100 | 2.0s | 1.85s |
| | Tour guide taps shared image to view full size or download media. | 100 | 2.0s | 0.65s |
| AI Tourist Information | Display interactive AI assistant chat interface. | 100 | 2.0s | 0.55s |
| | Tour guide inputs prompt regarding Philippine tourist destinations, culture, or history. | 100 | 2.0s | 0.75s |
| | Tour guide taps send button. | 100 | 2.0s | 0.15s |
| | Display AI response in the conversational thread. | 100 | 2.0s | 2.65s |
| Weather Information | Display current weather conditions and localized forecast based on active destination coordinates. | 100 | 2.0s | 0.95s |
| | System refreshes weather updates periodically. | 100 | 2.0s | 0.80s |
| End Tour | Tour guide taps "End Tour" button. | 100 | 2.0s | 0.15s |
| | Display confirmation prompt "Are you sure you want to end the active tour?". | 100 | 2.0s | 0.25s |
| | If tour guide confirms, invalidate all generated access codes and purge temporary tracking logs. | 100 | 2.0s | 0.85s |
| | Display message "Tour Ended Successfully". | 100 | 2.0s | 0.25s |
| | Redirect to Tour Guide Dashboard. | 100 | 2.0s | 0.35s |
| Profile & Menu | Display profile details (Name, Email, Contact Number, DOT ID status). | 100 | 2.0s | 0.45s |
| | Tour guide updates personal profile information or updates profile picture. | 100 | 2.0s | 1.25s |
| | Tour guide taps "Change Password" button. | 100 | 2.0s | 0.15s |
| | Input current password, new password, and confirm new password. | 100 | 2.0s | 0.85s |
| | Display message "Password Successfully Changed". | 100 | 2.0s | 0.65s |
| | Tour guide taps "Logout" button to end user session. | 100 | 2.0s | 0.45s |
| Tourist Access & Entry | Display splash screen when application loads. | 100 | 2.0s | 1.15s |
| | Tourist taps "Tourist Role" on role selection screen. | 100 | 2.0s | 0.15s |
| | Display Access Code entry screen. | 100 | 2.0s | 0.25s |
| | Tourist inputs valid tour access code provided by tour guide. | 100 | 2.0s | 0.65s |
| | Tourist inputs display name for identification. | 100 | 2.0s | 0.45s |
| | Tourist taps "Join Tour" button. | 100 | 2.0s | 0.15s |
| | Display Terms and Conditions module. | 100 | 2.0s | 0.35s |
| | Tourist accepts terms and privacy policy. | 100 | 2.0s | 0.45s |
| | Redirect to Tourist Dashboard. | 100 | 2.0s | 0.85s |
| Tourist Dashboard & Itinerary | Display current active tour details, guide announcements, and upcoming destinations. | 100 | 2.0s | 0.95s |
| | Tourist taps "View Itinerary" button. | 100 | 2.0s | 0.15s |
| | Display chronological list of destinations, arrival times, meeting points, and activities. | 100 | 2.0s | 0.65s |
| Live Location & Navigation | System requests runtime location permissions (ACCESS_FINE_LOCATION). | 100 | 2.0s | 0.35s |
| | Tourist grants location access. | 100 | 2.0s | 0.25s |
| | System streams continuous real-time coordinates to the tour guide. | 100 | 2.0s | 0.75s |
| | Tourist taps "Navigate to Guide" button. | 100 | 2.0s | 0.15s |
| | Display GPS route guidance back to the tour guide's current coordinates. | 100 | 2.0s | 1.35s |
| Safety Alert & Geofence | System detects tourist coordinates crossing designated geofence boundary. | 100 | 2.0s | 0.45s |
| | Display prominent warning alert overlay "Out of Tour Perimeter". | 100 | 2.0s | 0.25s |
| | Display guidance notes and primary return button ("View Map & Return"). | 100 | 2.0s | 0.20s |
| | Tourist taps return button to view navigation route back to safe zone | 100 | 2.0s | 0.15s |
| SOS Emergency | Tourist taps "SOS Emergency" button. | 100 | 2.0s | 0.15s |
| | Display confirmation prompt "Trigger Emergency Distress Signal?". | 100 | 2.0s | 0.20s |
| | Tourist confirms emergency action. | 100 | 2.0s | 0.15s |
| | System transmits high-priority distress alert with exact GPS location to tour guide. | 100 | 2.0s | 0.75s |
| | Display message "Emergency Alert Sent to Guide". | 100 | 2.0s | 0.25s |
| Group Chat & AI Assistant | **Group Chat:** Tourist views group broadcast messages and images. | 100 | 2.0s | 0.75s |
| | Tourist inputs message or shares images within the thread. | 100 | 2.0s | 0.55s |
| | **AI Tourist Information:** Tourist inputs inquiry regarding Philippine tourist attractions or travel details. | 100 | 2.0s | 0.75s |
| | Display automated AI assistance response. | 100 | 2.0s | 2.50s |
| Settings & System Information | Tourist accesses system menu screen. | 100 | 2.0s | 0.35s |
| | Tourist taps "About Application" to view app scope and objectives. | 100 | 2.0s | 0.25s |
| | Tourist taps "About Developers" to view developer profile information. | 100 | 2.0s | 0.25s |
| | Tourist taps "References" to view information sources. | 100 | 2.0s | 0.25s |
| | Tourist taps "Terms & Conditions" to view policy documentation. | 100 | 2.0s | 0.30s |
| | Press mobile built-in back button or return button to return to system menu. | 100 | 2.0s | 0.15s |
