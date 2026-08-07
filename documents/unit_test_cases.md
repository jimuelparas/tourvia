# TOURVIA - Formal Unit Test & QA Plan

This document contains formal QA test cases derived from the program specification.

## 1. Module: Role Selection
| Test ID | Test Scenario | Preconditions | Test Steps | Expected Result |
| :--- | :--- | :--- | :--- | :--- |
| TC-RS-01 | Verify Splash Screen | App is installed. | 1. Launch the application. | The splash screen is displayed. |
| TC-RS-02 | Verify Role Selection | Splash screen is finished. | 1. Observe the next screen. | The role selection screen presents options for "Tour Guide" and "Tourist". |
| TC-RS-03 | Verify Tour Guide Selection | Role selection screen is visible. | 1. Tap the "Tour Guide" button. | The Tour Guide authentication screen is displayed. |

## 2. Module: Registration
| Test ID | Test Scenario | Preconditions | Test Steps | Expected Result |
| :--- | :--- | :--- | :--- | :--- |
| TC-REG-01 | Verify Form Input | On Registration screen. | 1. Input full name, age, email, and contact number. | All fields accept the valid inputs. |
| TC-REG-02 | Verify DOT ID Upload | On Registration screen. | 1. Tap upload DOT ID. <br>2. Select image. | Image is uploaded and preview is shown. |
| TC-REG-03 | Verify AI Validation & Approval | Valid details and DOT ID image uploaded. | 1. Submit registration. | System initiates AI-powered verification. Upon success, account is automatically approved and activated. |

## 3. Module: Login
| Test ID | Test Scenario | Preconditions | Test Steps | Expected Result |
| :--- | :--- | :--- | :--- | :--- |
| TC-LOG-01 | Verify Invalid Login | On Login screen. | 1. Enter unregistered/wrong email or password. <br>2. Tap login. | Alert displays: "Invalid Credentials". |
| TC-LOG-02 | Verify Valid Login | On Login screen. Account is registered. | 1. Enter valid email and password. <br>2. Tap login. | The Tour Guide Dashboard is displayed. |

## 4. Module: Forgot Password
| Test ID | Test Scenario | Preconditions | Test Steps | Expected Result |
| :--- | :--- | :--- | :--- | :--- |
| TC-FP-01 | Request Reset Code | On Forgot Password screen. | 1. Input registered email. <br>2. Submit request. | System sends a verification code to the email. |
| TC-FP-02 | Verify Code & Reset | Verification code received. | 1. Input verification code. <br>2. Input new password & confirm. <br>3. Tap reset. | Display message “Password Reset Success”. |

## 5. Module: Dashboard
| Test ID | Test Scenario | Preconditions | Test Steps | Expected Result |
| :--- | :--- | :--- | :--- | :--- |
| TC-DB-01 | Verify Dashboard Content | Logged in as Tour Guide. | 1. View Dashboard. | Active tour status, quick links, and summary statistics (tours, tourists, activities) are displayed. |
| TC-DB-02 | Verify Quick Access Links | On Dashboard. | 1. Tap any quick access feature button. | Navigates to the appropriately selected module. |

## 6. Module: Generate Access Code
| Test ID | Test Scenario | Preconditions | Test Steps | Expected Result |
| :--- | :--- | :--- | :--- | :--- |
| TC-GAC-01 | Generate New Code | Logged in as Tour Guide. | 1. Tap "Generate Code" button. | System creates a unique access code assigned to the active tour. Code is displayed in the list. |
| TC-GAC-02 | Copy Access Code | Code exists in list. | 1. Tap "Copy Code" button. | Code is copied to the device clipboard. |
| TC-GAC-03 | Delete Unused Code | Unused code exists. | 1. Tap "Delete Code" button. | Confirmation modal "Delete Access Code?" appears. |
| TC-GAC-04 | Confirm Delete Code | Delete modal is visible. | 1. Tap Confirm. | Code is removed, message "Delete Success" is displayed. |

## 7. Module: Tour Itinerary Management
| Test ID | Test Scenario | Preconditions | Test Steps | Expected Result |
| :--- | :--- | :--- | :--- | :--- |
| TC-TIM-01 | View Schedule & Add | On Itinerary screen. | 1. View lists. <br>2. Tap "Add Itinerary". | Displays destination schedule and activity list. Opens Add Itinerary form. |
| TC-TIM-02 | Add Custom Itinerary | On Add Itinerary screen. | 1. Input destination name, time, location, details. | Inputs are accepted. |
| TC-TIM-03 | Add Recommended Spot | On Add Itinerary screen. | 1. Browse municipality list. <br>2. Select recommended spot. | Spot is selected and destination details automatically populate. |
| TC-TIM-04 | Save Itinerary | Itinerary details populated. | 1. Tap "Save Itinerary". | Display message "Itinerary Updated". |

## 8. Module: Attendance Monitoring
| Test ID | Test Scenario | Preconditions | Test Steps | Expected Result |
| :--- | :--- | :--- | :--- | :--- |
| TC-AM-01 | View Enrolled Tourists | On Attendance screen. | 1. View scheduled destinations. <br>2. Select specific destination. | List of enrolled tourists for the active tour is displayed. |
| TC-AM-02 | Mark Tourist Attendance | Enrolled tourists list is visible. | 1. Mark a tourist as Present or Absent. | System updates and saves attendance records in real-time. |

## 9. Module: Live Location Tracking & Navigation
| Test ID | Test Scenario | Preconditions | Test Steps | Expected Result |
| :--- | :--- | :--- | :--- | :--- |
| TC-LL-01 | View Tourist Locations | On Tracking screen. | 1. Open the interactive map. | Map renders real-time locations of all active tourists as pins. |
| TC-LL-02 | View Tourist Info | Map is visible with pins. | 1. Select a specific tourist pin. | Tourist info card displays (Name, status, distance). |
| TC-LL-03 | Ring Tourist | Tourist info card is visible. | 1. Tap "Ring Tourist" button. | Emits an audible alarm on the selected tourist's device. |
| TC-LL-04 | Navigate to Tourist | Tourist info card is visible. | 1. Tap "Navigate" button. | Redirects to turn-by-turn GPS navigation toward the tourist. |

## 10. Module: Group Chat
| Test ID | Test Scenario | Preconditions | Test Steps | Expected Result |
| :--- | :--- | :--- | :--- | :--- |
| TC-GC-01 | Send Text Message | On Group Chat screen. | 1. Input text in chat bar. <br>2. Tap send. | Message appears in active tour group message thread. |
| TC-GC-02 | Send Image | On Group Chat screen. | 1. Tap attachment icon. <br>2. Capture/upload image. | Uploaded image is displayed in the thread. |
| TC-GC-03 | View/Download Image | Image exists in thread. | 1. Tap shared image. | Image opens in full size with option to download media. |

## 11. Module: AI Tourist Information
| Test ID | Test Scenario | Preconditions | Test Steps | Expected Result |
| :--- | :--- | :--- | :--- | :--- |
| TC-AI-01 | Send Prompt to AI | On AI Chat screen. | 1. Input prompt regarding PH tourist info. <br>2. Tap send. | AI response is displayed in the conversational thread. |

## 12. Module: Weather Information
| Test ID | Test Scenario | Preconditions | Test Steps | Expected Result |
| :--- | :--- | :--- | :--- | :--- |
| TC-WI-01 | View Local Weather | On Weather screen. | 1. View screen. | Current conditions and localized forecast based on active destination are displayed. Updates periodically. |

## 13. Module: End Tour
| Test ID | Test Scenario | Preconditions | Test Steps | Expected Result |
| :--- | :--- | :--- | :--- | :--- |
| TC-ET-01 | End Tour Prompt | On active tour. | 1. Tap "End Tour" button. | Confirmation prompt "Are you sure..." appears. |
| TC-ET-02 | Confirm End Tour | Confirmation prompt is visible. | 1. Tap Confirm. | Invalidate access codes, purge temporary tracking logs, display "Tour Ended Successfully", and redirect to Dashboard. |

## 14. Module: Profile & Menu
| Test ID | Test Scenario | Preconditions | Test Steps | Expected Result |
| :--- | :--- | :--- | :--- | :--- |
| TC-PM-01 | Update Profile Info | On Profile screen. | 1. Update personal info or profile picture. | Displayed profile details (Name, Email, Contact, DOT ID status) are updated. |
| TC-PM-02 | Change Password | On Profile screen. | 1. Tap "Change Password". <br>2. Input current password, new password, confirm. | Display "Password Successfully Changed". |
| TC-PM-03 | Logout | Logged in. | 1. Tap "Logout" button. | User session ends. |

## 15. Module: Tourist Access & Entry
| Test ID | Test Scenario | Preconditions | Test Steps | Expected Result |
| :--- | :--- | :--- | :--- | :--- |
| TC-TAE-01 | Select Tourist Role | Splash screen is finished. | 1. Tap "Tourist Role". | Access Code entry screen is displayed. |
| TC-TAE-02 | Join Tour via Code | On Access Code screen. | 1. Input valid tour access code. <br>2. Input display name. <br>3. Tap "Join Tour". | Terms and Conditions module is displayed. |
| TC-TAE-03 | Accept Terms | Terms module is visible. | 1. Accept terms and privacy policy. | Redirects to Tourist Dashboard. |

## 16. Module: Tourist Dashboard & Itinerary
| Test ID | Test Scenario | Preconditions | Test Steps | Expected Result |
| :--- | :--- | :--- | :--- | :--- |
| TC-TDB-01 | View Tour Details | On Tourist Dashboard. | 1. View Dashboard. | Current active tour details, announcements, and upcoming destinations are displayed. |
| TC-TDB-02 | View Full Itinerary | On Tourist Dashboard. | 1. Tap "View Itinerary" button. | Chronological list of destinations, arrival times, meeting points, and activities is displayed. |

## 17. Module: Live Location & Navigation (Tourist)
| Test ID | Test Scenario | Preconditions | Test Steps | Expected Result |
| :--- | :--- | :--- | :--- | :--- |
| TC-TLL-01 | Grant Location Access | System requests location. | 1. Grant ACCESS_FINE_LOCATION. | System streams continuous real-time coordinates to tour guide. |
| TC-TLL-02 | Navigate to Guide | On Map screen. | 1. Tap "Navigate to Guide" button. | GPS route guidance back to the tour guide's current coordinates is displayed. |

## 18. Module: Safety Alert & Geofence
| Test ID | Test Scenario | Preconditions | Test Steps | Expected Result |
| :--- | :--- | :--- | :--- | :--- |
| TC-SAG-01 | Geofence Warning | Tourist crosses boundary. | 1. System detects out-of-bounds coordinates. | Displays prominent warning alert "Out of Tour Perimeter" with guidance notes and "View Map & Return" button. |
| TC-SAG-02 | Return to Safe Zone | Geofence warning is visible. | 1. Tap "View Map & Return" button. | Navigation route back to safe zone is displayed. |

## 19. Module: SOS Emergency
| Test ID | Test Scenario | Preconditions | Test Steps | Expected Result |
| :--- | :--- | :--- | :--- | :--- |
| TC-SOS-01 | Trigger SOS | On any screen. | 1. Tap "SOS Emergency" button. | Confirmation prompt "Trigger Emergency Distress Signal?" appears. |
| TC-SOS-02 | Confirm SOS | Confirmation prompt visible. | 1. Confirm emergency action. | High-priority distress alert with exact GPS sent to guide. Displays "Emergency Alert Sent to Guide". |

## 20. Module: Group Chat & AI Assistant (Tourist)
| Test ID | Test Scenario | Preconditions | Test Steps | Expected Result |
| :--- | :--- | :--- | :--- | :--- |
| TC-TGC-01 | Tourist Chat | On Group Chat. | 1. View messages. <br>2. Input text/image. | Messages/images are shared in thread. |
| TC-TAI-01 | Tourist AI Prompt | On AI Chat. | 1. Input inquiry. <br>2. Send. | Automated AI assistance response is displayed. |

## 21. Module: Settings & System Information
| Test ID | Test Scenario | Preconditions | Test Steps | Expected Result |
| :--- | :--- | :--- | :--- | :--- |
| TC-SET-01 | View App Info | On System Menu. | 1. Tap "About Application", "About Developers", "References", "Terms & Conditions". | Respective information is displayed. |
| TC-SET-02 | Return to Menu | Viewing app info. | 1. Press back button. | Returns to system menu. |
