import 'package:url_launcher/url_launcher.dart';

/// Utility to launch external navigation apps.
class NavigationUtils {
  NavigationUtils._();

  /// Launches Google Maps, Waze, or Apple Maps based on what is available,
  /// passing the destination latitude and longitude.
  static Future<void> launchNavigation({
    required double latitude,
    required double longitude,
    required String name,
  }) async {
    // google.navigation:q=latitude,longitude is the intent for Android Google Maps
    final googleMapsUrl = Uri.parse('google.navigation:q=$latitude,$longitude');
    
    // Waze
    final wazeUrl = Uri.parse('waze://?ll=$latitude,$longitude&navigate=yes');

    // Generic geo intent (works for OsmAnd, Maps.me, Organic Maps)
    final geoUrl = Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude(${Uri.encodeComponent(name)})');
    
    // Apple Maps fallback
    final appleUrl = Uri.parse('https://maps.apple.com/?daddr=$latitude,$longitude');

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl);
    } else if (await canLaunchUrl(wazeUrl)) {
      await launchUrl(wazeUrl);
    } else if (await canLaunchUrl(geoUrl)) {
      await launchUrl(geoUrl);
    } else if (await canLaunchUrl(appleUrl)) {
      await launchUrl(appleUrl);
    } else {
      // If nothing works, just launch the web google maps
      final webUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude');
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }
}
