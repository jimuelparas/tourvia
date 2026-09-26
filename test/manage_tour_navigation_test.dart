import 'package:flutter_test/flutter_test.dart';
import 'package:tourvia/features/tour_guide/screens/tour_management_screen.dart';

void main() {
  group('Manage Tour navigation and TourManagementScreen tab tests', () {
    testWidgets('TourManagementScreen defaults to tab 0 (Upcoming)', (tester) async {
      const screen = TourManagementScreen();
      expect(screen.initialTabIndex, 0);
    });

    testWidgets('TourManagementScreen accepts initialTabIndex: 0 for Upcoming tab', (tester) async {
      const screen = TourManagementScreen(initialTabIndex: 0);
      expect(screen.initialTabIndex, 0);
    });
  });
}
