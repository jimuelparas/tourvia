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
  static const String fullName = 'Full Name';
  static const String fullNameHint = 'e.g. Juan Dela Cruz';
  static const String age = 'Age';
  static const String ageHint = 'e.g. 28';
  static const String email = 'Email Address';
  static const String emailHint = 'e.g. juan@tourvia.ph';
  static const String contactNumber = 'Contact Number';
  static const String contactNumberHint = 'e.g. +63 912 345 6789';
  static const String tourGuideId = 'Tour Guide ID';
  static const String tourGuideIdHint = 'e.g. TG-2026-0001';
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
  static const String username = 'Username';
  static const String usernameHint = 'Enter your username';
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
      'Welcome to Tourvia.\n\nBy using this application, you agree to the following terms and conditions. The application provides tour management and assistance solely for locations within the Philippines. The reliability of live location tracking and safety alerts depends on your device\'s GPS accuracy and active internet connection.\n\nTour guides are responsible for the accuracy of their itineraries. Tourists must ensure their devices are sufficiently charged and connected to receive real-time updates and SOS alerts. Tourvia is not liable for issues arising from loss of connectivity or hardware malfunctions.\n\nPlease accept these terms to proceed.';
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
