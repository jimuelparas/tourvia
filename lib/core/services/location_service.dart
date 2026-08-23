import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';

/// Model representing a user's live location record in Firestore (Step 8 / US-11 to US-16).
class UserLocation {
  final String userId;
  final String userName;
  final double latitude;
  final double longitude;
  final double accuracy;
  final bool isGuide;
  final bool ringCommand;
  final DateTime updatedAt;

  const UserLocation({
    required this.userId,
    required this.userName,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.isGuide,
    required this.ringCommand,
    required this.updatedAt,
  });

  factory UserLocation.fromFirestore(String id, Map<String, dynamic> data) {
    final ts = (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return UserLocation(
      userId: id,
      userName: data['userName'] as String? ?? 'User',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      accuracy: (data['accuracy'] as num?)?.toDouble() ?? 0.0,
      isGuide: data['isGuide'] as bool? ?? false,
      ringCommand: data['ringCommand'] as bool? ?? false,
      updatedAt: ts,
    );
  }
}

/// Service that coordinates device GPS tracking and Firestore synchronization.
class LocationService {
  LocationService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _locCol(String sessionId) {
    return _db
        .collection('tour_sessions')
        .doc(sessionId)
        .collection('locations');
  }

  /// Request permissions and verify if location services are enabled on the device.
  static Future<bool> checkAndRequestPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Subscribes to the device's location stream and pushes coordinates to Firestore.
  /// Pushes coordinates when location changes by 5+ meters or every 15 seconds.
  static StreamSubscription<Position>? startPublishingLocation({
    required String sessionId,
    required String userId,
    required String userName,
    required bool isGuide,
  }) {
    // Configure location settings
    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
      intervalDuration: const Duration(seconds: 3),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: "Tourvia is tracking your location for safety monitoring.",
        notificationTitle: "Live Location Sharing Active",
        enableWakeLock: true,
      ),
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) async {
      try {
        await _locCol(sessionId).doc(userId).set({
          'userId': userId,
          'userName': userName,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'isGuide': isGuide,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {
        // Silent – stream must remain stable
      }
    });
  }

  /// Retrieves a real-time stream of all user locations in a tour session.
  static Stream<List<UserLocation>> watchAllLocations(String sessionId) {
    return _locCol(sessionId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => UserLocation.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  /// Set the ring command status for a specific tourist to true.
  /// Also writes a server-side [ringCommandAt] timestamp so the tourist
  /// can ignore stale rings that pre-date their current tracking session.
  static Future<void> triggerRing(String sessionId, String touristId) async {
    await _locCol(sessionId).doc(touristId).update({
      'ringCommand': true,
      'ringCommandAt': FieldValue.serverTimestamp(),
    });
  }

  /// Listens to a tourist's specific location doc for remote alerts (Ring command).
  ///
  /// When [ringCommand] is true AND [ringCommandAt] is after [screenOpenedAt],
  /// triggers a device vibration pattern and automatically resets the flag to
  /// false in Firestore.
  ///
  /// The [screenOpenedAt] guard prevents stale Firestore snapshots (cached by
  /// the SDK) from triggering a ring every time the tourist re-enters the
  /// Live Location Tracking screen.
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? listenToRingCommand({
    required String sessionId,
    required String touristId,
    required VoidCallback onRingTriggered,
    required DateTime screenOpenedAt,
  }) {
    return _locCol(sessionId).doc(touristId).snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data();
      if (data == null) return;

      final shouldRing = data['ringCommand'] as bool? ?? false;
      if (!shouldRing) return;

      // Guard: only react to rings issued AFTER this screen session started.
      // This prevents stale cached Firestore snapshots from firing spuriously.
      final ringTs = (data['ringCommandAt'] as Timestamp?)?.toDate();
      if (ringTs != null && ringTs.isBefore(screenOpenedAt)) return;

      // Trigger local callback (vibration/sound)
      onRingTriggered();

      // Reset command immediately in Firestore
      await _locCol(sessionId).doc(touristId).update({
        'ringCommand': false,
      });
    });
  }

  static AudioPlayer? _emergencyPlayer;
  static Timer? _emergencyVibrationTimer;
  static int _ringSequence = 0;

  /// Starts repeating emergency sound and vibration
  static Future<void> startEmergencyRing() async {
    // Only start if not already active
    if (_emergencyPlayer != null) return;

    final seq = ++_ringSequence;
    final player = AudioPlayer();
    _emergencyPlayer = player;
    try {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(1.0);
      
      // If stop was called while we were awaiting, abort
      if (_ringSequence != seq || _emergencyPlayer != player) {
        try { await player.dispose(); } catch (_) {}
        return;
      }

      if (kIsWeb) {
        // On Flutter web, assets are served at assets/assets/...
        await player.play(UrlSource('assets/assets/audio/alarm.wav'));
      } else {
        await player.play(AssetSource('audio/alarm.wav'));
      }
    } catch (e) {
      debugPrint('startEmergencyRing audio error: $e');
    }

    // Repeatedly trigger vibration since pattern vibration may stop or not loop infinitely
    if (!kIsWeb) {
      // Trigger immediately
      _triggerEmergencyVibration();
      // Repeat vibration every 4 seconds (approx duration of vibration pattern)
      _emergencyVibrationTimer?.cancel();
      _emergencyVibrationTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        _triggerEmergencyVibration();
      });
    }
  }

  static Future<void> _triggerEmergencyVibration() async {
    try {
      final hasVibrator = (await Vibration.hasVibrator()) == true;
      if (hasVibrator) {
        await Vibration.vibrate(
          pattern: <int>[0, 500, 150, 500, 150, 500, 150, 700],
          intensities: <int>[0, 255, 0, 255, 0, 255, 0, 255],
        );
      }
    } catch (_) {}
  }

  /// Stops the active emergency sound and vibration
  static Future<void> stopEmergencyRing() async {
    _ringSequence++; // invalidate any pending start requests
    if (_emergencyPlayer != null) {
      final player = _emergencyPlayer!;
      _emergencyPlayer = null; // detach immediately
      try {
        await player.stop();
      } catch (e) {
        debugPrint('stopEmergencyRing stop error: $e');
      }
      try {
        await player.dispose();
      } catch (e) {
        debugPrint('stopEmergencyRing dispose error: $e');
      }
    }
    if (_emergencyVibrationTimer != null) {
      _emergencyVibrationTimer!.cancel();
      _emergencyVibrationTimer = null;
    }
    if (!kIsWeb) {
      try {
        await Vibration.cancel();
      } catch (_) {}
    }
  }

  /// Triggers a loud alarm on the device:
  /// - Plays the bundled alarm.wav sound (4 beeps).
  /// - Vibrates in a repeating pattern simultaneously.
  static Future<void> buzzDevice() async {
    // 1. Play alarm sound
    try {
      final player = AudioPlayer();
      // Don't await — must stay in the synchronous user-gesture call stack
      // for Chrome's autoplay policy to allow audio.
      player.setVolume(1.0);

      if (kIsWeb) {
        // On Flutter web, assets are served at assets/assets/...
        player.play(UrlSource('assets/assets/audio/alarm.wav'));
      } else {
        player.play(AssetSource('audio/alarm.wav'));
      }

      // Dispose after the sound finishes (~3 s)
      Future.delayed(const Duration(seconds: 4), () => player.dispose());
    } catch (e) {
      // Audio not available — fall back to haptic
      debugPrint('buzzDevice audio error: $e');
      try {
        await HapticFeedback.heavyImpact();
      } catch (_) {}
    }

    // 2. Vibrate concurrently (not supported on web, but harmless)
    if (!kIsWeb) {
      try {
        final hasVibrator = (await Vibration.hasVibrator()) == true;
        if (hasVibrator) {
          await Vibration.vibrate(
            pattern: <int>[0, 500, 150, 500, 150, 500, 150, 700],
            intensities: <int>[0, 255, 0, 255, 0, 255, 0, 255],
          );
        }
      } catch (_) {
        // Vibration not supported — silently ignore
      }
    }
  }
}
