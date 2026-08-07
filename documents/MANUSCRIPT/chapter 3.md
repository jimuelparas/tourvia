# <a id="_Toc134134067"></a>3\.0 Technical Background

## <a id="_Toc134134068"></a>3\.1 Development

### <a id="_Toc134134069"></a>3\.1\.1 Hardware

__3\.1\.1\.1 Laptop__

	A laptop is a personal computer in a portable form which is powered by a battery pack or an AC adaptor, used to perform various software development activities. It is the primary workstation where developers write code, manage assets, configure cloud infrastructure, and emulate mobile devices.

In the development stage, the proponents utilized a laptop to execute coding, database setup, UI design, API integration, and system testing. The hardware specification of the laptop includes an AMD Ryzen 5 8645HS processor (4.30 GHz), Radeon 760M Graphics, 16.0 GB RAM, and a 64-bit operating system based on an x64 processor. These system resources provided sufficient computing power to seamlessly handle mobile emulators, local server environments, and cross-platform builds.

__3\.1\.1\.2 Mobile Devices__

	Mobile devices are portable touchscreen computing devices capable of connecting to cellular networks or Wi-Fi. They are essential to test the behavior, performance, and responsiveness of an application in a physical, real-world environment as opposed to a software emulator. Android smartphones and iOS devices were utilized to test system functionality, user interface responsiveness, GPS tracking accuracy, battery efficiency, and hardware features (such as camera and location services) across various screen dimensions.

### <a id="_Toc134134070"></a>3\.1\.2 Software

__*3\.1\.2\.1 Android Studio & Visual Studio Code*__

	Android Studio and Visual Studio Code (VS Code) served as the primary Integrated Development Environments (IDEs) for developing, debugging, and building the TourVia mobile application. Android Studio provided Android SDK management, Gradle build controls, and device emulators. Visual Studio Code offered lightweight, high-performance code editing, Flutter and Dart extensions, integrated terminal controls, and rapid hot reload functionality.

__*3\.1\.2\.2 Flutter*__

	Flutter is an open-source UI software development kit (SDK) developed by Google for building natively compiled, cross-platform applications for mobile, web, and desktop from a single codebase. The proponents selected Flutter as the main development framework to build a responsive, modern, and high-performance user interface for both Android and iOS platforms efficiently.

__*3\.1\.2\.3 Dart*__

	Dart is an open-source, client-optimized programming language created by Google. Used natively with Flutter, Dart powers the complete application logic, state management, screen navigation, data parsing, and feature integration, including tour session management, attendance tracking, live map tracking, emergency SOS alerts, and chatbot communication.

__*3\.1\.2\.4 Firebase Platform*__

	Firebase is a comprehensive Backend-as-a-Service (BaaS) platform developed by Google. TourVia integrates several Firebase cloud services to power its backend infrastructure:
	• **Firebase Authentication**: Provides secure user registration, authentication, session management, and role-based access control for tour guides and tourists.
	• **Cloud Firestore**: Serves as the real-time NoSQL cloud database storing tour session details, itineraries, attendance logs, live chat messages, access codes, user profile records, and emergency SOS alerts.
	• **Firebase Storage**: Provides cloud object storage for user avatar images and uploaded Department of Tourism (DOT) Tour Guide accreditation photos.
	• **Firebase Cloud Messaging (FCM)**: Handles push notifications and real-time message broadcasting for safety warnings, SOS emergency alerts, and tour updates.

__*3\.1\.2\.5 OpenStreetMap & flutter_map*__

	OpenStreetMap (OSM) integrated via the `flutter_map` package provides interactive, open-source tile mapping for real-time map visualization and geolocation features. Combined with `geolocator` and `latlong2` packages, it renders live tourist and tour guide GPS marker locations, tour stop waypoints, and geofence radii without relying on proprietary paid map SDKs.

__*3\.1\.2\.6 Google Gemini 1.5 Flash Vision API*__

	Google Gemini 1.5 Flash Vision API is a multimodal artificial intelligence service capable of analyzing visual and textual data. In TourVia, Gemini Vision powers automated Department of Tourism (DOT) Tour Guide ID verification during guide registration. It inspects official DOT logos, headers, card layout compliance, checks accreditation expiry dates, evaluates image clarity/blur, and extracts guide details.

__*3\.1\.2\.7 OpenAI (ChatGPT API - GPT-4o-mini)*__

	OpenAI Chat Completions API utilizing the `gpt-4o-mini` model powers the AI Travel Chatbot assistant in TourVia. Guided by a specialized system prompt restricting responses strictly to Philippine tourism, the assistant provides tourists with real-time destination recommendations, travel tips, local food advice, and cultural information in English and Tagalog.

__*3\.1\.2\.8 OpenWeatherMap API*__

	OpenWeatherMap API delivers real-time weather information, current temperature, weather conditions, humidity, precipitation probability, and multi-day weather forecasts for tour destinations, helping tour guides and tourists prepare for outdoor activities.

__*3\.1\.2\.9 Figma*__

	Figma is a cloud-based UI/UX design and prototyping tool. The proponents used Figma to craft screen wireframes, high-fidelity user interface layouts, color schemes, icon sets, and interactive app prototypes prior to development.

__*3\.1\.2\.10 Canva*__

	Canva is a graphics design platform used by the proponents to design visual assets, application logos, promotional banners, custom graphics, and manuscript illustrations.

__*3\.1\.2\.11 Lucidchart*__

	Lucidchart is a web-based diagramming tool used to construct system architecture and workflow diagrams, including Use Case Diagrams, Activity Diagrams, Sequence Diagrams, Fishbone Diagrams, and Functional Decomposition Diagrams for the TourVia platform.

__*3\.1\.2\.12 GitHub*__

	GitHub is a cloud-based Git repository hosting service used for source code version control, revision history, and collaboration, allowing the development team to push updates, manage code branches, and safeguard project files.

__*3\.1\.2\.13 Auxiliary Flutter Libraries & Utilities*__

	The application incorporates additional specialized Flutter packages to support system features:
	• **flutter_dotenv**: Securely loads environment variables and API keys (OpenAI, Gemini, OpenWeatherMap) from `.env` files.
	• **image_picker**: Handles device camera capture and photo gallery selection for ID and profile uploads.
	• **geolocator**: Provides device GPS coordinates, distance calculations, and real-time position updates.
	• **audioplayers & vibration**: Plays emergency alarm audio tones and triggers device haptic vibration during SOS alerts.
	• **url_launcher**: Launches native phone dialer applications for direct emergency contact calls.

### <a id="_Toc134134071"></a>3\.1\.3 Peopleware

__*3\.1\.3\.1 Proponents*__

	The proponents consist of a team of students who developed, tested, and documented the TourVia system. Each team member performed specific responsibilities including mobile programming, backend architecture, system design, quality assurance, and capstone documentation.

__*3\.1\.3\.2 Capstone Adviser*__

	Mr. Adrian Atienza served as the Capstone Adviser. He provided technical guidance, academic direction, project management advice, and structural feedback during project planning and manuscript development.

__*3\.1\.3\.3 Tour Guides and Tourists*__

	Tour guides and tourists serve as the primary target users of the TourVia application. Tour guides use the platform to conduct tours, track attendance, monitor safety, and coordinate schedules. Tourists utilize the app for tour participation, live map navigation, weather monitoring, AI travel assistance, and emergency signaling.

## 3\.2 Implementation

### 3\.2\.1 Hardware

__*3\.2\.1\.1 Android Mobile Devices*__

	Android smartphones equipped with hardware GPS sensors, cellular/Wi-Fi connectivity, and digital cameras are required for tour guides and tourists to run the TourVia application during live tour operations.

__*3\.2\.1\.2 iOS Mobile Devices*__

	iOS mobile devices with camera and location capabilities are also supported, allowing Apple users to access the full suit of TourVia features including location tracking, chat, weather monitoring, and safety alerts.

### 3\.2\.2 Software

__*3\.2\.2\.1 Android Operating System*__

	The mobile application targets Android OS version 10 (API level 29) or higher to ensure optimal performance, security patch compatibility, location permissions handling, and smooth UI rendering.

__*3\.2\.2\.2 iOS Operating System*__

	The mobile application is compatible with iOS version 14.0 or higher to deliver consistent cross-platform user experience across Apple mobile hardware.

### 3\.2\.3 Peopleware

__*3\.2\.3\.1 Tour Guide*__

	The Tour Guide acts as the tour administrator in the system. They oversee tour creation, access code generation, tourist attendance monitoring, real-time map location tracking, emergency alert response, and group messaging.

__*3\.2\.3\.2 Tourists*__

	Tourists are the end-users who join tours using access codes provided by their tour guide. They access live itineraries, receive safety alerts, view destination weather, interact with the AI chatbot, and trigger emergency SOS signals when assistance is required.
