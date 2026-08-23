/// Centralised string constants for the Tourvia application.
class AppStrings {
  AppStrings._();

  // ── App ─────────────────────────────────────────────────
  static const String appName = 'Tourvia';
  static const String appTagline =
      'Tour Management & Assistance\nfor the Philippines';

  // ── Role Selection / Welcome ────────────────────────────
  static const String welcomeTitle = 'Welcome to Tourvia';
  static const String welcomeSubtitle =
      'Your smart companion for seamless tour\nmanagement across the Philippines.';
  static const String selectRole = 'How would you like to continue?';
  static const String tourGuideRole = 'Tour Guide';
  static const String tourGuideRoleDesc =
      'Manage tours, monitor tourists, and coordinate logistics.';
  static const String touristRole = 'Tourist';
  static const String touristRoleDesc =
      'Join a tour session using an access code from your guide.';

  // ── Registration ────────────────────────────────────────
  static const String registerTitle = 'Create Account';
  static const String registerSubtitle =
      'Register as a tour guide to get started';
  static const String firstName = 'First Name';
  static const String firstNameHint = 'e.g. Juan';
  static const String middleName = 'Middle Name';
  static const String middleNameHint = 'e.g. Santos';
  static const String lastName = 'Last Name';
  static const String lastNameHint = 'e.g. Dela Cruz';
  static const String fullName = 'Full Name';
  static const String fullNameHint = 'e.g. Juan Dela Cruz';
  static const String age = 'Age';
  static const String ageHint = 'e.g. 28';
  static const String email = 'Email Address';
  static const String emailHint = 'e.g. juan@tourvia.ph';
  static const String contactNumber = 'Contact Number';
  static const String contactNumberHint = 'e.g. +63 912 345 6789';
  static const String address = 'Address';
  static const String addressHint = 'e.g. 123 Session Rd, Baguio City';
  static const String tourGuideId = 'DOT Tour Guide ID';
  static const String tourGuideIdHint = 'e.g. TG-2026-0001';
  static const String username = 'Username';
  static const String usernameHint = 'Create a username';
  static const String password = 'Password';
  static const String passwordHint = 'Min. 8 characters';
  static const String confirmPassword = 'Confirm Password';
  static const String confirmPasswordHint = 'Re-enter your password';
  static const String registerButton = 'Submit Registration';
  static const String alreadyHaveAccount = 'Already have an account? ';
  static const String login = 'Log in';

  // ── Validation ──────────────────────────────────────────
  static const String fieldRequired = 'This field is required';
  static const String invalidEmail = 'Please enter a valid email address';
  static const String invalidAge = 'Please enter a valid age (18-100)';
  static const String invalidPhone =
      'Please enter a valid Philippine phone number';
  static const String passwordTooShort =
      'Password must be at least 8 characters';
  static const String passwordsDoNotMatch = 'Passwords do not match';

  // ── Registration Success ────────────────────────────────
  static const String successTitle = 'Registration Submitted!';
  static const String successSubtitle =
      'Your account is now pending review.\nYou will be notified once it is approved.';
  static const String successNote =
      'Our team will verify your tour guide credentials. '
      'This usually takes 1–2 business days.';
  static const String backToLogin = 'Back to Login';

  // ── Login ──────────────────────────────────────────────
  static const String loginTitle = 'Welcome Back';
  static const String loginSubtitle =
      'Sign in to access your tour management dashboard';
  static const String loginUsername = 'Username or Email';
  static const String loginUsernameHint = 'Enter your username or email';
  static const String loginButton = 'Sign In';
  static const String forgotPassword = 'Forgot Password?';
  static const String noAccount = "Don't have an account? ";
  static const String register = 'Register';
  static const String invalidCredentials =
      'Incorrect username or password. Please try again.';
  static const String accountPending =
      'Your account is still pending approval. '
      'Please wait for admin review before logging in.';
  static const String accountRejected =
      'Your account has been rejected. '
      'Please contact support for more information.';
  static const String loginSuccess = 'Login successful! Redirecting…';

  // ── Forgot Password ─────────────────────────────────────
  static const String forgotPasswordTitle = 'Forgot Password';
  static const String forgotPasswordSubtitle =
      'Enter the email address linked to your account and we\'ll send you a reset link.';
  static const String emailLabel = 'Email Address';
  static const String emailHintForgot = 'Enter your registered email';
  static const String sendResetLink = 'Send Reset Link';
  static const String rememberPassword = 'Remember your password? ';
  static const String backToLoginLink = 'Back to Login';

  // ── Email Sent Confirmation ─────────────────────────────
  static const String emailSentTitle = 'Check Your Email';
  static const String emailSentSubtitle =
      'We\'ve sent a password reset link to your email address. '
      'Please check your inbox and follow the instructions.';
  static const String emailSentNote =
      'Didn\'t receive the email? Check your spam folder or '
      'wait a few minutes before requesting again.';
  static const String resendEmail = 'Resend Email';
  static const String openResetPassword = 'Continue to Reset';

  // ── Reset Password ─────────────────────────────────────
  static const String resetPasswordTitle = 'Reset Password';
  static const String resetPasswordSubtitle =
      'Create a new secure password for your account.';
  static const String newPassword = 'New Password';
  static const String newPasswordHint = 'Min. 8 characters';
  static const String confirmNewPassword = 'Confirm New Password';
  static const String confirmNewPasswordHint = 'Re-enter your new password';
  static const String resetPasswordButton = 'Reset Password';
  static const String passwordResetSuccess =
      'Password reset successful! You can now log in with your new password.';
  static const String passwordRequirements =
      'Password must be at least 8 characters long.';

  // ── Tourist Login ────────────────────────────────────────
  static const String touristLoginTitle = 'Join a Tour';
  static const String touristLoginSubtitle =
      'Enter the access code provided by your tour guide to join the session.';
  static const String accessCodeLabel = 'Access Code';
  static const String accessCodeHint = 'e.g. TRV-123456';
  static const String joinTourButton = 'Join Tour';
  static const String touristLoginSuccess = 'Joining tour session...';

  // ── Terms and Conditions ────────────────────────────────
  static const String termsTitle = 'Terms and Conditions';
  static const String termsSubtitle =
      'Please read and accept our terms to continue using Tourvia.';
  static const String termsContent =
      'Welcome to Tourvia. Please read and understand these Terms and Conditions carefully before using the application.\n\n'
      'By accessing, downloading, or using Tourvia, you agree to be legally bound by the terms of this system and the conditions governing all users. Tourvia is an auxiliary mobile platform designed to facilitate tour management, itinerary coordination, and tourist safety assistance exclusively within the Republic of the Philippines on an as-is and as-available basis.\n\n'
      'System Scope and Developer Disclaimer\n'
      'Tourvia provides digital tools including access code onboarding, itinerary planning, attendance logging, real-time GPS tracking, emergency SOS alerts, group messaging, and artificial intelligence travel assistance. The system and its developers assume no legal responsibility or liability for the authenticity, validity, or accuracy of credentials, identification documents, and personal details provided by any user. Users are solely responsible for all information they submit. Furthermore, the developers and the system shall not be held liable for any damages, personal injuries, losses, travel disruptions, or misconduct occurring during tour operations or arising from user actions.\n\n'
      'Terms and Conditions for Tour Guides\n'
      'Tour Guides must register with authentic personal details and verified credentials, such as Department of Tourism (DOT) accreditation. Tour Guides are responsible for maintaining the confidentiality of their login credentials and are solely accountable for the accuracy of their scheduled itineraries, group safety boundaries, and attendance logs. Tour Guides are granted authorization to monitor tourist GPS locations and trigger remote ring alerts strictly for participant safety and recovery. Tour Guides must officially conclude each tour session to ensure that temporary tracking and session data are properly purged.\n\n'
      'Terms and Conditions for Tourists\n'
      'Tourists join active tour sessions through unique access codes issued by their authorized Tour Guide and agree to provide an authentic, identifiable name for roll call and safety monitoring. As a condition of participation, tourists must grant continuous background location permissions to allow real-time proximity monitoring by their guide. Tourists are responsible for keeping their mobile devices sufficiently charged and connected to receive real-time updates and safety alerts, adhering to designated assembly schedules, and utilizing the emergency SOS and communication tools responsibly without abuse.\n\n'
      'Data Privacy and Transient Storage (RA 10173)\n'
      'In compliance with the Philippine Data Privacy Act of 2012, Tourvia collects only essential operational data. Real-time GPS location logs, session access codes, and in-session group chat messages are transient and are automatically deleted from active storage upon the formal conclusion of the tour session by the Tour Guide.\n\n'
      'By tapping "Accept & Continue", you confirm that you have read, understood, and agreed to these Terms and Conditions for both Tour Guides and Tourists.';
  static const String agreeToTerms =
      'I have read and agree to the Terms and Conditions';
  static const String acceptButton = 'Accept & Continue';
  static const String declineButton = 'Decline';
  static const String termsDeclinedMessage =
      'You must accept the terms to use the application.';

  // ── Dashboards & Navigation ──────────────────────────────
  static const String navHome = 'Home';
  static const String navItinerary = 'Itinerary';
  static const String navTourists = 'Tourists';
  static const String navMap = 'Map';
  static const String navChat = 'Chat';
  static const String navSettings = 'Settings';

  static const String tgDashboardTitle = 'Tour Guide Dashboard';
  static const String touristDashboardTitle = 'Tourist Dashboard';

  // ── Tour Guide Home / Access Code (US-06) ────────────────
  static const String activeTourStatus = 'Active Tour Session';
  static const String noActiveTourStatus = 'No Active Tour';
  static const String startTourButton = 'Start New Tour Session';
  static const String endTourButton = 'End Tour Session';
  static const String endTourConfirmation =
      'Are you sure you want to end the current tour? All tourists will be disconnected.';
  static const String accessCodeLabelTG = 'Tourist Access Code';
  static const String accessCodeDesc =
      'Share this code with your tourists so they can join the session.';
  static const String copyCodeButton = 'Copy Code';
  static const String codeCopiedMsg = 'Access code copied to clipboard!';
  static const String activeTourPrompt =
      'You currently have an ongoing tour. Tourists can join using the access code below.';
  static const String startTourPrompt =
      'Start a new tour session to generate a unique access code for your tourists.';

  // ── Itinerary (US-07, US-08, US-09) ────────────────────────
  static const String itineraryTitle = 'Tour Itinerary';
  static const String emptyItineraryTG =
      'No stops added yet. Tap + to build your itinerary.';
  static const String emptyItineraryTourist =
      'Your tour guide hasn\'t published the itinerary yet.';
  static const String addStopButton = 'Add Stop';
  static const String editStopTitle = 'Edit Stop';
  static const String addStopTitle = 'Add New Stop';
  static const String destNameLabel = 'Destination Name';
  static const String dateLabel = 'Date';
  static const String startTimeLabel = 'Start Time';
  static const String endTimeLabel = 'End Time';
  static const String notesLabel = 'Notes (Optional)';
  static const String saveStopButton = 'Save Stop';

  // ── Attendance (US-10, US-26) ────────────────────────────
  static const String attendanceTitle = 'Tourist Attendance';
  static const String tabAllTourists = 'All Tourists';
  static const String tabByDestination = 'By Destination';
  static const String statusPresent = 'Present';
  static const String statusAbsent = 'Absent';
  static const String statusPending = 'Pending';
  static const String selectDestinationHint = 'Select Destination Stop';
  static const String markAllPresentButton = 'Mark All Present';
  static const String exportAttendanceButton = 'Export';

  // ── Tracking & Safety (US-11 to US-16) ───────────────────
  static const String mapTitle = 'Live Location Tracking';
  static const String touristMapTitle = 'My Location';
  static const String missingAlert = 'Missing Tourist Alert!';
  static const String boundaryAlert = 'Out of Bounds Warning!';
  static const String navigateToTourist = 'Navigate';
  static const String ringPhone = 'Ring Phone';
  static const String routeToGuide = 'Route to Guide';
  static const String returnToBoundary =
      'Please return to the designated tour boundary immediately.';
}
