/// Curated dataset of popular Philippine tourist destinations
/// grouped by city/municipality for itinerary location suggestions.
class PhilippineLocationsData {
  PhilippineLocationsData._();

  /// Tourist attractions grouped by city/municipality.
  /// Each key is a city name, and the value is a list of attraction names.
  static const Map<String, List<String>> byCity = {
    // ── Cordillera Administrative Region ──────────────────
    'Baguio City': [
      'Burnham Park',
      'Session Road',
      'Mines View Park',
      'The Mansion',
      'Camp John Hay',
      'BenCab Museum',
      'Botanical Garden',
      'Tam-Awan Village',
      'Wright Park',
      'Our Lady of the Atonement Cathedral',
      'Baguio Night Market',
      'Lourdes Grotto',
    ],
    'Sagada, Mountain Province': [
      'Sumaguing Cave (Big Cave)',
      'Hanging Coffins of Sagada',
      'Bomod-ok Falls (Big Falls)',
      'Kiltepan Peak Viewpoint',
      'Lake Danum',
      'Lumiang Burial Cave',
      'Echo Valley',
      'Marlboro Hills (Maligcong Rice Terraces)',
    ],
    'Banaue, Ifugao': [
      'Banaue Rice Terraces',
      'Batad Rice Terraces',
      'Tappiya Falls',
      'Banaue Museum',
      'Tam-an Village',
    ],

    // ── Ilocos Region ────────────────────────────────────
    'Vigan City, Ilocos Sur': [
      'Calle Crisologo',
      'Bantay Bell Tower',
      'Plaza Salcedo (Dancing Fountain)',
      'Syquia Mansion',
      'Crisologo Museum',
      'Baluarte Zoo',
      'Hidden Garden',
      'Heritage Village',
    ],
    'Laoag City, Ilocos Norte': [
      'Paoay Church (St. Augustine Church)',
      'Fort Ilocandia',
      'Sinking Bell Tower',
      'La Paz Sand Dunes',
      'Malacañang of the North',
      'Kapurpurawan Rock Formation',
      'Bangui Windmills',
      'Pagudpud (Blue Lagoon)',
    ],

    // ── Metro Manila ─────────────────────────────────────
    'Manila': [
      'Intramuros (Walled City)',
      'Fort Santiago',
      'Rizal Park (Luneta Park)',
      'San Agustin Church',
      'Manila Ocean Park',
      'National Museum of Fine Arts',
      'National Museum of Natural History',
      'Manila Cathedral',
      'Chinatown (Binondo)',
      'Quiapo Church',
    ],
    'Makati City': [
      'Ayala Museum',
      'Greenbelt Park',
      'Poblacion Art District',
      'Legazpi Sunday Market',
    ],
    'Taguig City (BGC)': [
      'Bonifacio Global City',
      'Mind Museum',
      'Venice Grand Canal Mall',
      'High Street',
    ],

    // ── Central Visayas ──────────────────────────────────
    'Cebu City': [
      'Basilica del Santo Niño',
      'Magellan\'s Cross',
      'Fort San Pedro',
      'Temple of Leah',
      'Tops Lookout',
      'Carbon Market',
      'Taoist Temple',
      'Sirao Flower Garden',
    ],
    'Moalboal, Cebu': [
      'Sardine Run (Panagsama Beach)',
      'Pescador Island',
      'Kawasan Falls',
      'White Beach Moalboal',
    ],
    'Oslob, Cebu': [
      'Whale Shark Watching',
      'Tumalog Falls',
      'Oslob Church Ruins',
      'Sumilon Island',
    ],

    // ── Palawan ──────────────────────────────────────────
    'Puerto Princesa, Palawan': [
      'Puerto Princesa Underground River',
      'Honda Bay Island Hopping',
      'Baker\'s Hill',
      'Palawan Wildlife Rescue and Conservation Center',
      'Iwahig Firefly Watching',
      'Mitra\'s Ranch',
    ],
    'El Nido, Palawan': [
      'Big Lagoon',
      'Small Lagoon',
      'Secret Lagoon',
      'Nacpan Beach',
      'Seven Commandos Beach',
      'Shimizu Island',
      'Matinloc Shrine',
      'Hidden Beach',
    ],
    'Coron, Palawan': [
      'Kayangan Lake',
      'Twin Lagoon',
      'Barracuda Lake',
      'Coron Island',
      'Malcapuya Island',
      'Skeleton Wreck Dive Site',
      'Mt. Tapyas Viewpoint',
    ],

    // ── Bohol ─────────────────────────────────────────────
    'Bohol': [
      'Chocolate Hills',
      'Philippine Tarsier Sanctuary',
      'Loboc River Cruise',
      'Baclayon Church',
      'Panglao Beach (Alona Beach)',
      'Hinagdanan Cave',
      'Balicasag Island',
      'Blood Compact Shrine',
      'Man-Made Forest',
    ],

    // ── Siargao ──────────────────────────────────────────
    'Siargao Island, Surigao del Norte': [
      'Cloud 9 Surfing Spot',
      'Sugba Lagoon',
      'Magpupungko Rock Pools',
      'Naked Island',
      'Daku Island',
      'Guyam Island',
      'Sohoton Cove',
      'Tayangban Cave Pool',
    ],

    // ── Boracay ──────────────────────────────────────────
    'Boracay Island, Aklan': [
      'White Beach (Station 1-3)',
      'Puka Shell Beach',
      'Mt. Luho Viewpoint',
      'Crystal Cove Island',
      'Ariel\'s Point Cliff Diving',
      'D\'Mall Shopping Area',
      'Bulabog Beach (Kite Surfing)',
      'Willy\'s Rock',
    ],

    // ── Albay / Bicol ────────────────────────────────────
    'Legazpi City, Albay': [
      'Mayon Volcano',
      'Cagsawa Ruins',
      'Lignon Hill Nature Park',
      'Daraga Church',
      'Sumlang Lake',
      'Quitinday Green Hills',
    ],

    // ── Davao ─────────────────────────────────────────────
    'Davao City': [
      'Philippine Eagle Center',
      'Eden Nature Park',
      'People\'s Park',
      'D\' Bone Collector Museum',
      'Jack\'s Ridge',
      'Malagos Chocolate Museum',
      'Mt. Apo (trailhead)',
      'Samal Island (Island Garden City)',
    ],

    // ── Zamboanga ─────────────────────────────────────────
    'Zamboanga City': [
      'Fort Pilar Shrine',
      'Great Santa Cruz Island (Pink Beach)',
      'Paseo del Mar',
      'Merloquet Falls',
      'Yakan Weaving Village',
    ],

    // ── Camiguin ─────────────────────────────────────────
    'Camiguin Island': [
      'White Island',
      'Katibawasan Falls',
      'Sunken Cemetery',
      'Ardent Hot Springs',
      'Old Church Ruins',
      'Mantigue Island',
    ],

    // ── Batanes ──────────────────────────────────────────
    'Batanes': [
      'Basco Lighthouse (Naidi Hills)',
      'Valugan Boulder Beach',
      'Fundacion Pacita',
      'Sabtang Island',
      'Marlboro Country (Racuh a Payaman)',
      'Honesty Coffee Shop',
      'Chawa Viewdeck',
    ],
  };

  /// Flat list of all attraction names (for quick search).
  static List<String> get allAttractions {
    return byCity.values.expand((list) => list).toList();
  }

  /// Returns all city names.
  static List<String> get allCities => byCity.keys.toList();

  /// Searches both city names and attraction names.
  /// Returns a filtered map with only matching entries.
  static Map<String, List<String>> search(String query) {
    if (query.trim().isEmpty) return byCity;

    final lowerQuery = query.toLowerCase();
    final result = <String, List<String>>{};

    for (final entry in byCity.entries) {
      final cityMatches = entry.key.toLowerCase().contains(lowerQuery);
      final matchingAttractions = entry.value
          .where((a) => a.toLowerCase().contains(lowerQuery))
          .toList();

      if (cityMatches) {
        // City name matches — show all its attractions
        result[entry.key] = entry.value;
      } else if (matchingAttractions.isNotEmpty) {
        // Only specific attractions match
        result[entry.key] = matchingAttractions;
      }
    }

    return result;
  }
}
