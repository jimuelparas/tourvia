## 4.3 Design

### 4.3.1 Output and User-Interface Design

TourVia prioritizes simplicity, clarity, and accessibility by providing a modern, intuitive mobile interface designed for both tour guides and tourists. The user-interface design focuses on delivering an organized and frictionless user experience (UX), especially during dynamic real-time activities such as live GPS tracking, emergency SOS alerting, in-app group communication, attendance verification, and itinerary navigation.

The application adopts the **"Ocean Breeze"** design theme, utilizing a harmonious color palette dominated by Sky Blue and Crisp White. Sky Blue is employed as the primary brand color to symbolize trust, safety, tranquility, and reliability—vital psychological factors in tourism and travel safety management. Crisp white and cool off-white surfaces provide a clean, distraction-free canvas that maximizes content contrast, enhances legibility under varying outdoor lighting conditions, and minimizes cognitive load.

Consistent layout hierarchies are maintained across all application screens through structured card containers, elevated interactive buttons, standardized input fields, and distinct bottom navigation bars:
* **Primary Color (`#2196F3` / `#1976D2`):** Applied to primary call-to-action (CTA) buttons, active navigation indicators, app bars, and highlighted interactive elements.
* **Surface & Canvas (`#FFFFFF` / `#F8FAFC`):** Applied to screen backgrounds, modular content cards, dialogs, and modal bottom sheets to establish visual separation.
* **Neutral & Typography Colors (`#0F172A` / `#64748B`):** Deep Slate and muted slate tones are utilized for headings, body copy, and secondary descriptions to ensure high readability and aesthetic balance without the harshness of pure black.
* **Semantic Accent Colors (`#10B981`, `#EF4444`, `#F59E0B`):** Emerald green, red, and amber are reserved for contextual feedback such as attendance check-in confirmation, emergency SOS alerts, and boundary warnings.

---

**HEX: #2196F3** | **HEX: #FFFFFF** | **HEX: #0F172A** | **HEX: #64748B**

**Figure 29: Main Theme Colors**

---

### 4.3.2 Typography Design

Typography plays a crucial role in ensuring that critical travel information—such as schedules, alerts, and navigation directions—can be quickly scanned and understood on mobile screens. TourVia implements modern geometric sans-serif typefaces (**Poppins** / **DM Sans** for prominent headers and **Inter** for detailed body text) through Google Fonts.

The geometric structure of these typefaces offers high legibility, consistent kerning, and clear character distinction across varying mobile screen densities. Furthermore, these font families offer comprehensive Latin character support, ensuring broad compatibility for domestic and international travelers navigating tourist destinations across the Philippines.

**Figure 30: Typography Hierarchy and Font Family**

---

### 4.3.3 Iconography and Visual Elements Design

Iconography in TourVia plays an essential role in visual navigation, rapid information recognition, and reducing cognitive strain during fast-paced tour activities. The system adopts Google Material Symbols (Rounded style), ensuring a friendly, cohesive, and modern visual language across all modules.

Icons are structured with standardized bounding boxes (20dp to 28dp optical sizing) and distinct semantic color associations to provide immediate visual feedback:

1. **Navigation and Module Icons:**
   * **Home (`home_rounded`):** Represents the primary tour session overview and active access code controls.
   * **Itinerary (`calendar_month_rounded` / `route_rounded`):** Signifies scheduled destination stops, timeline sequences, and travel durations.
   * **Tourists & Attendance (`groups_rounded` / `how_to_reg_rounded`):** Depicts participant rosters, check-in verification, and roll-call logs.
   * **Live Map Tracking (`map_rounded` / `near_me_rounded`):** Highlights real-time GPS locations, route lines, and proximity boundaries.
   * **Group Chat (`chat_bubble_rounded` / `forum_rounded`):** Indicates collaborative messaging and photo sharing.
   * **AI Travel Assistant (`auto_awesome_rounded` / `smart_toy_rounded`):** Denotes the intelligent Gemini-powered tourism chatbot and vision landmark scanner.

2. **Status and Safety Action Icons:**
   * **Emergency SOS (`warning_amber_rounded` / `emergency_rounded`):** High-visibility red emblem for immediate distress broadcasting.
   * **Remote Ring Alert (`notifications_active_rounded` / `vibration_rounded`):** Used by tour guides to sound an audible alarm on lost or separated tourist devices.
   * **Attendance Status Icons:** Green checkmarks (`check_circle_rounded`) for present tourists, red cancel icons (`cancel_rounded`) for absent members, and amber clocks (`hourglass_top_rounded`) for pending check-ins.
   * **Weather Conditions:** Dynamic meteorology icons (`wb_sunny_rounded`, `cloud_rounded`, `thunderstorm_rounded`) providing live destination weather advisories.

**Figure 31: System Iconography and Semantic Icons**
