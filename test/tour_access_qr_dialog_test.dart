import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tourvia/core/models/tour_model.dart';
import 'package:tourvia/features/tour_guide/widgets/tour_access_qr_dialog.dart';

void main() {
  group('TourAccessQrDialog Tests', () {
    final validTour = Tour(
      id: 'tour_123',
      name: 'qwe',
      startDate: DateTime(2026, 9, 25),
      endDate: DateTime(2026, 9, 25),
      totalDays: 1,
      guideId: 'guide_1',
      guideName: 'Guide One',
      accessCode: 'TRV-XFR',
      status: 'upcoming',
    );

    final invalidTour = Tour(
      id: 'tour_456',
      name: 'No Code Tour',
      startDate: DateTime(2026, 9, 25),
      endDate: DateTime(2026, 9, 25),
      totalDays: 1,
      guideId: 'guide_1',
      guideName: 'Guide One',
      accessCode: '',
      status: 'upcoming',
    );

    testWidgets('renders actual tour access code and matching dynamic QR code',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TourAccessQrDialog(tour: validTour),
          ),
        ),
      );

      // Verify Title & Subtitle
      expect(find.text('Tour Access Code'), findsOneWidget);
      expect(
        find.text(
            'Share this QR code or access code for tourists to join this tour.'),
        findsOneWidget,
      );

      // Verify Access code is displayed
      expect(find.text('Unique Tour Access Code'), findsOneWidget);
      expect(find.text('TRV-XFR'), findsOneWidget);

      // Verify QR Code is dynamically generated
      expect(find.byType(QrImageView), findsOneWidget);

      // Verify Copy and Close buttons exist
      expect(find.text('Copy Access Code'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('shows clear error when access code is missing or invalid',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TourAccessQrDialog(tour: invalidTour),
          ),
        ),
      );

      // Verify error view is shown
      expect(find.text('Invalid or Missing Access Code'), findsOneWidget);
      expect(
        find.text(
            'This tour does not have a valid access code to generate a QR code.'),
        findsOneWidget,
      );

      // Verify QR Image is NOT rendered
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Copy Access Code'), findsNothing);
    });

    testWidgets('dynamic QR code reflects different tour access codes',
        (tester) async {
      final anotherTour = validTour.copyWith(accessCode: 'TRV-999');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TourAccessQrDialog(tour: anotherTour),
          ),
        ),
      );

      expect(find.text('TRV-999'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
    });
  });
}
