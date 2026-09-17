# Tourvia — System Revisions Document

> **Document Version:** 3.2.0  
> **Date Updated:** September 13, 2026  
> **Status:** Active / Under Review  
> **Project:** Tourvia (Smart Tour Guide & Tourist Assistance System)

---

## 1. Overview & Purpose

This document serves as the central index and tracking log for all system revisions, enhancements, and architectural upgrades across the Tourvia application ecosystem.

---

## 2. Revision Summary Table

| Rev ID | Module / Feature | Change Type | Description / Goal | Priority | Status | Detailed Spec |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `REV-001` | **Registration & Authentication** | Enhancement & Security | Birthday + auto age, required address, Barangay ID & valid IDs, Google Sign-in flow with **strict prevention of Dashboard access for incomplete Google accounts** (`Google Sign-Up → Authenticate Google Account → Complete Credentials → Verify ID → Save Profile → Dashboard`), improved PH phone validation | High | `[x]` Completed | [register and login .md](file:///c:/flutter_project/TOURVIA/documents/REVISIONS/register%20and%20login%20.md) |
| `REV-002` | **Tour Management & Itinerary** | Major Architecture | Pre-planning module, schedule conflict validation, auto-generated access code (Copy only, no Share), Tourist Join Request Management (Pending/Approved/Rejected), Tour status lifecycle (`Upcoming → Active → Completed`), Dashboard "No Active Tour" state & automated current destination, tour-isolated group chat & notifications | High | `[x]` Completed | [tour_management_and_itinerary.md](file:///c:/flutter_project/TOURVIA/documents/REVISIONS/tour_management_and_itinerary.md) |
| `REV-003` | **In-App Navigation & Live Tracking** | Enhancement & UX | Eliminate external Google Maps redirection; keep navigation 100% inside Tourvia using OpenStreetMap (OSM) & OSRM polylines, floating HUD, and live multi-tourist sync | High | `[x]` Completed | [in_app_navigation_and_live_tracking.md](file:///c:/flutter_project/TOURVIA/documents/REVISIONS/in_app_navigation_and_live_tracking.md) |

*Status Legend:* `[ ] Proposed / Ready` · `[/] In Progress` · `[x] Completed` · `[!] Blocked`

---

## 3. Active Revisions Index

### REV-001: Registration and Authentication Updates
- **Summary**:
  1. Date of Birth picker + automatic age calculation (18+ check).
  2. Mandatory address validation.
  3. Expanded valid IDs (Barangay ID, government IDs) in Gemini AI verification.
  4. "Continue with Google" on Login and Registration screens.
  5. **Strict Prevention of Dashboard Access for Incomplete Google Accounts**:
     $$\text{Google Sign-Up} \rightarrow \text{Authenticate Google Account} \rightarrow \text{Complete Credentials} \rightarrow \text{Verify ID} \rightarrow \text{Save Profile} \rightarrow \text{Dashboard}$$
     Auth gatekeeper strictly blocks dashboard entry on initial signup, app reload, or restart until credentials and ID are fully verified and saved to Firestore.
  6. Granular Philippine contact number validator (+63 and 09 format checks).
- **Specification Document**: [register and login .md](file:///c:/flutter_project/TOURVIA/documents/REVISIONS/register%20and%20login%20.md)

---

### REV-002: Tour Management, Pre-Planning, Itinerary & Isolated Services
- **Summary**:
  1. **New Navigation Structure**: `Dashboard → Tours → Create Tour → Create Itinerary → Manage Tour`.
  2. **Tour Pre-Planning & Conflict Validation**: Guide can create multiple future tours; system cross-references date ranges and strictly blocks overlapping tours.
  3. **Auto Unique Access Code**: Instantly generates one unique access code per tour upon creation; provides a **"Copy Access Code"** button only (all references to "Share" removed).
  4. **Tourist Join Request Management**:
     $$\text{Tourist enters Code} \rightarrow \text{Submits info} \rightarrow \text{Guide reviews in 'Join Requests'} \rightarrow \text{Approve or Reject}$$
     Only approved tourists become members of that tour and gain access to chat, tracking, and attendance.
  5. **Clear Tour Status Lifecycle**: `Upcoming → Active → Completed`. Group chat becomes read-only upon completion.
  6. **Dashboard "No Active Tour" Empty State & Automated Current Destination**: If no tour is running today, displays clean "No Active Tour" state; when active, automatically transitions active destination based on the clock.
  7. **Strict Itinerary Scheduling Rules**: Date/time pickers, no backdating future tours, no overlapping slots, start before end time, chronological auto-sorting, multi-day auto-grouping (Day 1, Day 2...), starts as `Upcoming`.
  8. **Tour-Specific Group Chat & Notifications**: Isolated chat per tour (`/tours/{tourId}/chat`); only guide and approved tourists have access; notification links directly to that tour.
- **Specification Document**: [tour_management_and_itinerary.md](file:///c:/flutter_project/TOURVIA/documents/REVISIONS/tour_management_and_itinerary.md)

---

### REV-003: In-App Navigation and Live Tracking
- **Summary**:
  1. **Zero External Redirection:** Completely eliminate `launchUrl` calls that redirect to the external Google Maps application.
  2. **In-App OpenStreetMap Routing:** Render active walking/driving route polylines directly on Tourvia's built-in `flutter_map` (OpenStreetMap) using OSRM.
  3. **Floating Navigation HUD:** Display distance remaining, ETA, target label, recenter button, and cancel route button directly on the map screen.
  4. **Preserved Real-Time Synchronization:** Both guide and tourists remain in the application, ensuring continuous GPS updates, visible multi-tourist tracking pins, active geofence alerts, and SOS notifications without OS background throttling.
- **Specification Document**: [in_app_navigation_and_live_tracking.md](file:///c:/flutter_project/TOURVIA/documents/REVISIONS/in_app_navigation_and_live_tracking.md)

---

## 4. Revision Change Log

| Revision Date | Revision ID | Author | Summary of Changes Implemented |
| :--- | :--- | :--- | :--- |
| 2026-09-13 | `INIT` | Antigravity / Jimuel Paras | Initial revision tracking document created. |
| 2026-09-13 | `REV-001` | Antigravity / Jimuel Paras | Registration and Authentication updates (Google Auth, Birthday/Age, Barangay ID, PH Phone validation, strict Dashboard lock for incomplete Google users). |
| 2026-09-13 | `REV-002` | Antigravity / Jimuel Paras | Tour Management & Itinerary (Join Request Management, Schedule Conflict Validation, Remove Share, Tour Status Lifecycle, Dashboard "No Active Tour" state, Smart Scheduling, and Isolated Chat). |
| 2026-09-13 | `REV-003` | Antigravity / Jimuel Paras | In-App Navigation and Live Tracking using OpenStreetMap (OSM) without Google Maps redirection. |
