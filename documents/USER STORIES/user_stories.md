# Tourvia – User Stories per Module

> **Project:** Tourvia: A Mobile-Based Tour Management & Assistance for Tourists & Tourist Guides in the Philippines
> **Document Type:** User Stories
> **Based on:** Scope and Limitations (Section 1.2 & 1.3)

---

## Roles

| Role | Description |
|---|---|
| **Tour Guide** | A registered and approved professional who manages the tour, monitors tourists, and coordinates logistics. |
| **Tourist** | A participant who joins a tour session using an access code provided by the tour guide. |

---

## Module 1: Authentication & Onboarding

> Covers registration, login, password recovery, and terms and conditions for both user roles.

---

### US-00 | User Role Selection

**As a** user opening the application,
**I want to** select whether I am a Tour Guide or a Tourist,
**so that** I am directed to the correct login and onboarding flow for my role.

#### Acceptance Criteria
- [ ] A welcome screen is presented as the first interaction with the application.
- [ ] The screen provides a clear choice between the "Tour Guide" and "Tourist" roles.
- [ ] Selecting "Tour Guide" routes the user to the Tour Guide Login screen.
- [ ] Selecting "Tourist" routes the user to the Tourist Access Code Login screen.

---

### US-01 | Tour Guide Registration

**As a** tour guide,
**I want to** register by submitting my personal and professional information,
**so that** my account can be reviewed and approved before I can access the system.

#### Acceptance Criteria
- [ ] Registration form collects: full name, age, email, contact number, and tour guide ID.
- [ ] All fields are required; incomplete submissions display inline validation errors.
- [ ] On successful submission, a pending status message is displayed.
- [ ] The tour guide cannot log in until the account is approved.
- [ ] A confirmation notification (email or in-app) is sent after submission.

---

### US-02 | Tour Guide Login

**As an** approved tour guide,
**I want to** log in using my username and password,
**so that** I can access the tour management dashboard and its features.

#### Acceptance Criteria
- [ ] Login form contains fields for username and password.
- [ ] Incorrect credentials display an appropriate error message.
- [ ] Only approved tour guides can successfully log in.
- [ ] Pending or rejected accounts are denied access with a descriptive message.
- [ ] Successful login redirects the user to the tour guide dashboard.

---

### US-03 | Tour Guide Forgot Password

**As a** tour guide,
**I want to** reset my password via email verification,
**so that** I can regain access to my account if I forget my credentials.

#### Acceptance Criteria
- [ ] A "Forgot Password" option is available on the login screen.
- [ ] User submits their registered email address.
- [ ] A verification email with a reset link is sent to the provided address.
- [ ] The reset link allows the user to create and confirm a new password.
- [ ] The user is redirected to the login screen after a successful reset.

---

### US-04 | Tourist Login via Access Code

**As a** tourist,
**I want to** log in using an access code provided by my tour guide,
**so that** I can access the tour features without creating a personal account.

#### Acceptance Criteria
- [ ] A dedicated login screen for tourists accepts only an access code.
- [ ] A valid access code grants entry to the tourist's tour session view.
- [ ] An invalid or expired code displays a clear error message.
- [ ] Tourists do not have the option to register or manage personal accounts.

---

### US-05 | Terms and Conditions Acceptance

**As a** new user (tour guide or tourist),
**I want to** read and accept the terms and conditions,
**so that** I understand the rules, guidelines, and scope of the application before using it.

#### Acceptance Criteria
- [ ] Terms and Conditions are displayed before the user gains access to the main features.
- [ ] The user must explicitly tap/check an "I Agree" option to proceed.
- [ ] Declining the terms prevents access to the application.
- [ ] Terms and Conditions are accessible again from the Settings module.

---

## Module 2: Tourist Access Code

> Enables tour guides to generate and manage unique session access codes for tourists.

---

### US-06 | Generate Tourist Access Code

**As a** tour guide,
**I want to** generate a unique access code for an active tour session,
**so that** only authorized tourists can join my tour on the system.

#### Acceptance Criteria
- [ ] The tour guide can generate a code from the dashboard when a tour is active.
- [ ] Each access code is unique per tour session.
- [ ] The generated code is clearly displayed and can be shared (e.g., copied, shown on-screen).
- [ ] The access code expires automatically when the tour session ends.
- [ ] Previously used codes cannot be reused for new sessions.

---

## Module 3: Tour Itinerary Management

> Enables tour guides to plan and manage itineraries, and tourists to view them.

---

### US-07 | Create Tour Itinerary

**As a** tour guide,
**I want to** create a detailed tour itinerary with destinations, schedules, and time allotments,
**so that** the tour is well-structured and all participants can follow the plan.

#### Acceptance Criteria
- [ ] Tour guide can create a new itinerary from the dashboard.
- [ ] Each itinerary entry includes: destination name, date, start time, end time, and optional notes.
- [ ] Multiple stops/destinations can be added to a single itinerary.
- [ ] The itinerary can be saved as a draft or published to tourists.
- [ ] Published itineraries are immediately visible to logged-in tourists.

---

### US-08 | Edit or Update Tour Itinerary

**As a** tour guide,
**I want to** edit or update an existing tour itinerary,
**so that** changes in the tour plan are reflected in real time for the tourists.

#### Acceptance Criteria
- [ ] Tour guide can modify destination names, times, and notes for any itinerary entry.
- [ ] Stops can be reordered, added, or removed.
- [ ] Tourists see the updated itinerary after the guide publishes changes.
- [ ] A timestamp of the last update is shown.

---

### US-09 | View Tour Itinerary (Tourist)

**As a** tourist,
**I want to** view the tour itinerary set by my tour guide,
**so that** I know the plan, destinations, and schedule for the tour.

#### Acceptance Criteria
- [ ] Itinerary is visible to the tourist after logging in with the access code.
- [ ] Itinerary displays all stops with destination name, scheduled time, and notes.
- [ ] The tourist view is read-only; tourists cannot edit the itinerary.
- [ ] Itinerary updates from the tour guide are reflected without requiring a manual refresh.

---

## Module 4: Tourist Attendance Monitoring

> Allows tour guides to track and record tourist presence during the tour.

---

### US-10 | Monitor Tourist Attendance

**As a** tour guide,
**I want to** view and track the attendance of all tourists in my tour,
**so that** I can ensure every participant is accounted for at all times.

#### Acceptance Criteria
- [ ] A list of all tourists linked to the active tour session is displayed.
- [ ] The guide can mark each tourist as present or absent.
- [ ] The system timestamps each attendance entry.
- [ ] Visual indicators (e.g., icons or color codes) distinguish present from absent tourists.
- [ ] The guide can export or review the attendance list during or after the tour.

---

### US-26 | Check Attendance per Destination in Itinerary

**As a** tour guide,
**I want to** check and record tourist attendance at each destination stop within the tour itinerary,
**so that** I can confirm which tourists are present at each specific location before the group moves on.

#### Acceptance Criteria
- [ ] Each destination/stop in the itinerary has a dedicated attendance checklist accessible to the tour guide.
- [ ] The checklist displays all tourists enrolled in the current tour session.
- [ ] The tour guide can mark each tourist as present or absent per destination stop.
- [ ] Each attendance check entry is timestamped and associated with the specific destination.
- [ ] The guide can view a summary of attendance per destination after completing the check.
- [ ] A visual badge or indicator on the itinerary shows whether attendance has been taken for each stop (e.g., "Checked" / "Pending").

---

## Module 5: Live Location Tracking & Safety Alerts

> Real-time GPS monitoring, boundary alerts, missing tourist identification, and navigation features.

> **Note:** The reliability of this module depends on GPS accuracy and network signal availability. Poor signal or GPS error may result in delayed or inaccurate location data.

---

### US-11 | View Tourist Real-Time Locations (Tour Guide)

**As a** tour guide,
**I want to** see the real-time GPS location of all tourists on a map,
**so that** I can monitor the group and confirm everyone is within the designated tour area.

#### Acceptance Criteria
- [ ] A live map displays the current location of each tourist with a labeled marker.
- [ ] Locations refresh at regular intervals (e.g., every 10–30 seconds).
- [ ] The designated 1 km tour boundary is visually shown on the map.
- [ ] Each tourist marker shows the tourist's name or identifier.
- [ ] The tour guide's own location is also shown on the map.

---

### US-12 | Boundary Breach Alert (Tour Guide)

**As a** tour guide,
**I want to** receive an alert notification when a tourist moves outside the 1 km tour boundary,
**so that** I can immediately respond and take action to locate them.

#### Acceptance Criteria
- [ ] A push notification is sent to the tour guide when a tourist exits the 1 km boundary.
- [ ] The notification includes the tourist's name and their distance from the boundary.
- [ ] An in-app alert is also displayed on the tour guide's dashboard.
- [ ] The alert provides a quick-access link to the map showing the tourist's last known location.

---

### US-13 | Identify and Locate Missing Tourists

**As a** tour guide,
**I want to** identify missing tourists and view their last known location, distance from the boundary, and time since last seen,
**so that** I can take swift and informed action to locate them.

#### Acceptance Criteria
- [ ] Tourists who have not been detected within a threshold period are flagged as "missing."
- [ ] The missing tourist's last known location is displayed on the map.
- [ ] Information shown includes: distance from the designated boundary, and elapsed time since last seen.
- [ ] A navigation feature directs the tour guide toward the missing tourist's last known location.

---

### US-14 | Navigate to Missing Tourist

**As a** tour guide,
**I want to** use in-app navigation to find the route to a missing tourist's last known location,
**so that** I can reach them as quickly as possible.

#### Acceptance Criteria
- [ ] A "Navigate" button is accessible from the missing tourist's profile or map pin.
- [ ] The navigation provides a route from the guide's current location to the tourist's last known position.
- [ ] Turn-by-turn or directional guidance is displayed.

---

### US-15 | Remotely Ring a Tourist's Device

**As a** tour guide,
**I want to** remotely trigger a ringtone on a tourist's phone,
**so that** I can alert the tourist or help identify their physical location by sound.

#### Acceptance Criteria
- [ ] A "Ring Phone" button is available for each tourist in the tracking view.
- [ ] Triggering the ring sends an alert to the tourist's device that activates a sound/vibration.
- [ ] The tour guide receives a confirmation that the ring command was sent.
- [ ] The tourist receives a visible notification indicating the guide is trying to reach them.

---

### US-16 | Boundary Breach Alert and Guidance (Tourist)

**As a** tourist,
**I want to** receive an alert when I move outside the designated tour boundary and see directions back to the tour guide,
**so that** I know I am out of the safe zone and can quickly rejoin the group.

#### Acceptance Criteria
- [ ] A push notification and in-app alert are displayed when the tourist exits the 1 km boundary.
- [ ] The alert includes a warning message indicating the tourist is outside the safe zone.
- [ ] A map view shows the tour guide's current location and a direction route back to the group.
- [ ] A quick-contact option (e.g., call or chat) for the tour guide is accessible from the alert.

---

## Module 6: Weather Alert

> Provides real-time weather conditions during the tour to support safety decisions.

---

### US-17 | View Real-Time Weather Updates

**As a** user (tour guide or tourist),
**I want to** see real-time weather information during the tour,
**so that** I can make informed decisions about tour activities and stay safe in adverse weather conditions.

#### Acceptance Criteria
- [ ] A weather widget is displayed on the main dashboard for both user roles.
- [ ] Current weather conditions are shown: temperature, weather description (e.g., rain, storm, extreme heat).
- [ ] Weather data is refreshed at regular intervals.
- [ ] A dedicated weather alert notification is pushed to users when dangerous conditions (e.g., storm, heavy rain) are detected.
- [ ] Weather data is location-based and relevant to the current tour area.

---

## Module 7: SOS Button

> Emergency alert system for immediate assistance during the tour.

---

### US-18 | Send Emergency SOS Alert

**As a** user (tour guide or tourist),
**I want to** press an SOS button to send an immediate emergency alert,
**so that** the other party is notified right away and my current GPS location is shared for rapid response.

#### Acceptance Criteria
- [ ] A clearly visible SOS button is available on the main dashboard for all users.
- [ ] Pressing the SOS button triggers a confirmation prompt to prevent accidental activation.
- [ ] Upon confirmation, an emergency alert is sent to the other party (guide notifies tourists and vice versa).
- [ ] The alert includes the sender's current GPS coordinates.
- [ ] The recipient receives the SOS as a push notification with the sender's name and location.
- [ ] The SOS alert is logged with a timestamp for reference.

---

## Module 8: Group Chat

> Centralized communication channel for all tour participants.

---

### US-19 | Send Messages and Media (Tour Guide)

**As a** tour guide,
**I want to** send text messages, photos, and videos in the group chat,
**so that** I can relay announcements and share content with all tourists in real time.

#### Acceptance Criteria
- [ ] Tour guide has access to a group chat interface within the active tour session.
- [ ] Text messages can be composed and sent to all tourists.
- [ ] Photos and videos can be attached and sent from the device gallery or camera.
- [ ] Sent messages include sender name and timestamp.
- [ ] Tourists receive push notifications for new messages.

---

### US-20 | Participate in Group Chat and Download Media (Tourist)

**As a** tourist,
**I want to** read and send messages in the group chat, and download shared photos and videos,
**so that** I stay informed during the tour and can keep my favourite tour memories.

#### Acceptance Criteria
- [ ] Tourist can read all messages in the group chat.
- [ ] Tourist can send text messages visible to the entire group.
- [ ] Shared images and videos from the tour guide are viewable in the chat.
- [ ] A download button allows tourists to save photos and videos to their device.
- [ ] Push notifications alert tourists when new messages or media are posted.

---

## Module 9: Chatbot-Assisted Tourist Information

> AI chatbot providing information about Philippine tourist destinations.

> **Note:** The chatbot is limited to information about tourist destinations within the Philippines only. Questions outside this scope will not be answered.

---

### US-21 | Ask Chatbot About Tourist Spots

**As a** user (tour guide or tourist),
**I want to** ask the chatbot questions about Philippine tourist destinations,
**so that** I can quickly access location details, descriptions, and photos without leaving the app.

#### Acceptance Criteria
- [ ] A chatbot interface is accessible from the main navigation for both user roles.
- [ ] The chatbot responds to natural language questions about Philippine tourist spots.
- [ ] Responses include: destination description, location details, and relevant photos.
- [ ] The chatbot clearly indicates when a question is outside its programmed knowledge (Philippine destinations only).
- [ ] Conversation history is visible within the current session.

---

## Module 10: Settings

> Application information and support resources accessible to all users.

---

### US-22 | View About the Application

**As a** user,
**I want to** view the purpose, features, and scope of the application,
**so that** I can better understand what the app offers and how it is intended to be used.

#### Acceptance Criteria
- [ ] An "About the Application" section is accessible from the Settings menu.
- [ ] The section includes the app's purpose, key features, and scope.
- [ ] Content is clearly formatted and easy to read.

---

### US-23 | View About the Developers

**As a** user,
**I want to** view basic information about the development team,
**so that** I can know who created the application and their roles.

#### Acceptance Criteria
- [ ] An "About the Developers" section is accessible from the Settings menu.
- [ ] Each developer's name, role, and contribution is displayed.

---

### US-24 | View References

**As a** user,
**I want to** view the sources and references used for tourist destination information in the app,
**so that** I can verify the credibility and origin of the information provided.

#### Acceptance Criteria
- [ ] A "References" section is accessible from the Settings menu.
- [ ] All sources for tourist spot data and chatbot information are listed.
- [ ] Sources are clearly cited with titles and links where applicable.

---

### US-25 | View Terms and Conditions (Settings)

**As a** user,
**I want to** access the Terms and Conditions from the Settings menu at any time,
**so that** I can review the usage rules and guidelines of the app whenever needed.

#### Acceptance Criteria
- [ ] Terms and Conditions are accessible from the Settings menu.
- [ ] The content is identical to what was shown during initial onboarding.
- [ ] The section is read-only; the user cannot modify the content.

---

## Summary Table

| Module | # | User Story Title | Role |
|---|---|---|---|
| Authentication & Onboarding | US-01 | Tour Guide Registration | Tour Guide |
| Authentication & Onboarding | US-02 | Tour Guide Login | Tour Guide |
| Authentication & Onboarding | US-03 | Tour Guide Forgot Password | Tour Guide |
| Authentication & Onboarding | US-04 | Tourist Login via Access Code | Tourist |
| Authentication & Onboarding | US-05 | Terms and Conditions Acceptance | Both |
| Tourist Access Code | US-06 | Generate Tourist Access Code | Tour Guide |
| Tour Itinerary Management | US-07 | Create Tour Itinerary | Tour Guide |
| Tour Itinerary Management | US-08 | Edit or Update Tour Itinerary | Tour Guide |
| Tour Itinerary Management | US-09 | View Tour Itinerary | Tourist |
| Attendance Monitoring | US-10 | Monitor Tourist Attendance | Tour Guide |
| Attendance Monitoring | US-26 | Check Attendance per Destination in Itinerary | Tour Guide |
| Live Location & Safety | US-11 | View Tourist Real-Time Locations | Tour Guide |
| Live Location & Safety | US-12 | Boundary Breach Alert | Tour Guide |
| Live Location & Safety | US-13 | Identify and Locate Missing Tourists | Tour Guide |
| Live Location & Safety | US-14 | Navigate to Missing Tourist | Tour Guide |
| Live Location & Safety | US-15 | Remotely Ring a Tourist's Device | Tour Guide |
| Live Location & Safety | US-16 | Boundary Breach Alert and Guidance | Tourist |
| Weather Alert | US-17 | View Real-Time Weather Updates | Both |
| SOS Button | US-18 | Send Emergency SOS Alert | Both |
| Group Chat | US-19 | Send Messages and Media | Tour Guide |
| Group Chat | US-20 | Participate in Chat and Download Media | Tourist |
| AI Chatbot | US-21 | Ask Chatbot About Tourist Spots | Both |
| Settings | US-22 | View About the Application | Both |
| Settings | US-23 | View About the Developers | Both |
| Settings | US-24 | View References | Both |
| Settings | US-25 | View Terms and Conditions | Both |

> **Total: 26 User Stories across 10 Modules**
