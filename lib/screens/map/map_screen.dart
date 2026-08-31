import 'package:flutter/material.dart';
import '../../core/theme/pinori_colours.dart';
import 'widgets/pinori_nav_bar.dart';
import 'widgets/pinori_map.dart';
import '../../models/trip.dart';
import '../../services/trip_storage_service.dart';
import '../../models/place.dart';
import '../../services/place_storage_service.dart';
import 'package:latlong2/latlong.dart';
import '../../services/ai_service.dart';
import '../../services/geocoding_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../services/onboarding_storage_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool uiVisible = true;
  PinoriPanel activePanel = PinoriPanel.none;
  bool showAddContent = false;
  bool showPlacesContent = false;
  bool showTripsContent = false;

  String? selectedPlaceCategory;

  bool isProcessingScreenshot = false;

  bool heyGirlExpanded = false;
  bool heyGirlShowText = false;
  bool heyGirlHasUnread = true;
  String? lastHeyGirlSuggestion;
  String? heyGirlAiSuggestion;
  bool heyGirlIsThinking = false;
  String? lastHeyGirlPlaceSignature;

  final List<Trip> trips = [];
  Trip? selectedTrip;

  final List<Place> places = [];

  Place? selectedPlace;

  final MapController mapController = MapController();

  late StreamSubscription<List<SharedMediaFile>> _shareIntentSub;

  void _selectPanel(PinoriPanel panel) {
    // If tapping the panel that's already open, hide its content first,
    // then shrink the drawer.
    if (activePanel == panel) {
      setState(() {
        showAddContent = false;
        showPlacesContent = false;
        showTripsContent = false;
      });

      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) return;

        setState(() {
          activePanel = PinoriPanel.none;
        });
      });

      return;
    }

    // Opening a different panel
    setState(() {
      activePanel = panel;
      uiVisible = true;

      showAddContent = false;
      showPlacesContent = false;
      showTripsContent = false;
    });

    Future.delayed(const Duration(milliseconds: 170), () {
      if (!mounted) return;

      setState(() {
        if (activePanel == PinoriPanel.add) {
          showAddContent = true;
        }

        if (activePanel == PinoriPanel.places) {
          showPlacesContent = true;
        }

        if (activePanel == PinoriPanel.trips) {
          showTripsContent = true;
        }
      });
    });
  }

  String? _getNearbyClusterSuggestion() {
    if (places.length < 3) return null;

    final distance = Distance();

    for (final anchor in places) {
      final nearbyPlaces = <Place>[];
      double furthestDistance = 0;

      for (final other in places) {
        if (other.id == anchor.id) continue;

        final metres = distance(
          LatLng(anchor.latitude, anchor.longitude),
          LatLng(other.latitude, other.longitude),
        );

        if (metres <= 1000) {
          nearbyPlaces.add(other);

          if (metres > furthestDistance) {
            furthestDistance = metres;
          }
        }
      }

      if (nearbyPlaces.length >= 2) {
        final clusterPlaces = [anchor, ...nearbyPlaces];

        final visitedPlaces = clusterPlaces
            .where((place) => place.visited)
            .toList();

        final unvisitedPlaces = clusterPlaces
            .where((place) => !place.visited)
            .toList();

        final names = clusterPlaces.map((place) => place.name).join(', ');

        final visitedNames = visitedPlaces
            .map((place) => place.name)
            .join(', ');

        final unvisitedNames = unvisitedPlaces
            .map((place) => place.name)
            .join(', ');

        final area = anchor.neighbourhood.trim().isNotEmpty
            ? anchor.neighbourhood
            : anchor.name;

        final roundedDistance = (furthestDistance / 50).round() * 50;

        return 'Nearby cluster: $names are all within roughly '
            '${roundedDistance}m of ${anchor.name}, around $area. '
            'There are ${clusterPlaces.length} saved places in this cluster. '
            '${visitedPlaces.length} are VISITED'
            '${visitedNames.isNotEmpty ? ' ($visitedNames)' : ''}. '
            '${unvisitedPlaces.length} are NOT VISITED'
            '${unvisitedNames.isNotEmpty ? ' ($unvisitedNames)' : ''}.';
      }
    }

    return null;
  }

  String _getHeyGirlSuggestion() {
    if (selectedTrip == null) {
      return 'Create or select a trip first and then I can snoop through your pins 👀';
    }

    if (places.isEmpty) {
      return 'You haven’t pinned anything yet! Add a few places and I’ll start noticing things 👀';
    }

    final nearbyClusterSuggestion = _getNearbyClusterSuggestion();

    if (nearbyClusterSuggestion != null) {
      return nearbyClusterSuggestion;
    }

    // Count neighbourhoods
    final neighbourhoodCounts = <String, int>{};

    for (final place in places) {
      final neighbourhood = place.neighbourhood.trim();

      if (neighbourhood.isEmpty) continue;

      neighbourhoodCounts[neighbourhood] =
          (neighbourhoodCounts[neighbourhood] ?? 0) + 1;
    }

    String? busiestNeighbourhood;
    int busiestCount = 0;

    neighbourhoodCounts.forEach((neighbourhood, count) {
      if (count > busiestCount) {
        busiestNeighbourhood = neighbourhood;
        busiestCount = count;
      }
    });

    // Count categories
    final cafeCount = places
        .where((place) => place.category.toLowerCase() == 'cafe')
        .length;

    final restaurantCount = places
        .where((place) => place.category.toLowerCase() == 'restaurant')
        .length;

    if (busiestCount >= 3) {
      final greeting = OnboardingStorageService.getPreferredGreeting();

      return '$greeting… you’ve got $busiestCount places around '
          '$busiestNeighbourhood 👀 That could definitely be its own little day.';
    }

    if (cafeCount >= 3) {
      return 'You’ve already saved $cafeCount cafés ☕ I see what kind of trip this is becoming.';
    }

    if (restaurantCount >= 4) {
      return 'You’ve got $restaurantCount restaurants saved already 😭 Food itinerary loading...';
    }

    return 'You’ve got ${places.length} places pinned for ${selectedTrip!.name} so far ♡ Keep going and I’ll start spotting little clusters for you.';
  }

  Future<void> _refreshHeyGirlInsight() async {
    if (selectedTrip == null || heyGirlIsThinking) {
      return;
    }

    final localInsight = _getHeyGirlSuggestion();

    setState(() {
      heyGirlIsThinking = true;
    });

    try {
      final suggestion = await AiService.getHeyGirlSuggestion(
        localInsight: localInsight,
        destination: selectedTrip?.destination ?? '',
        tripName: selectedTrip?.name ?? '',
        places: places.map((place) {
          return {
            'name': place.name,
            'category': place.category,
            'neighbourhood': place.neighbourhood,
            'visited': place.visited,
          };
        }).toList(),
        preferredGreeting: OnboardingStorageService.getPreferredGreeting(),
      );

      if (!mounted) return;

      setState(() {
        heyGirlAiSuggestion = suggestion.trim().isEmpty
            ? localInsight
            : suggestion.trim();

        heyGirlHasUnread = true;
        heyGirlIsThinking = false;
      });
    } catch (error) {
      debugPrint('HEY GIRL ERROR: $error');

      if (!mounted) return;

      setState(() {
        // If AI fails, Pinori still has our local insight.
        heyGirlAiSuggestion = localInsight;
        heyGirlHasUnread = true;
        heyGirlIsThinking = false;
      });
    }
  }

  List<String> _getAvailablePlaceCategories() {
    const categoryOrder = [
      'Cafe',
      'Restaurant',
      'Shopping',
      'Beauty',
      'Attraction',
      'Museum',
      'Park',
      'Nightlife',
      'Hotel',
      'Transport',
      'Other',
    ];

    final availableCategories = categoryOrder.where((category) {
      return places.any((place) => place.category == category);
    }).toList();

    return ['All Places', ...availableCategories];
  }

  Place? _findDuplicatePlace({
    required String name,
    required double latitude,
    required double longitude,
  }) {
    String cleanName(String value) {
      return value
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9가-힣]+'), '')
          .trim();
    }

    final newName = cleanName(name);

    if (newName.isEmpty) {
      return null;
    }

    final distance = Distance();

    for (final place in places) {
      final existingName = cleanName(place.name);

      if (existingName.isEmpty) {
        continue;
      }

      final metres = distance(
        LatLng(latitude, longitude),
        LatLng(place.latitude, place.longitude),
      );

      final exactSameName = newName == existingName;

      final similarName =
          newName.length >= 4 &&
          existingName.length >= 4 &&
          (newName.contains(existingName) || existingName.contains(newName));

      // A matching name still needs to be geographically close.
      //
      // This avoids:
      // - different nearby businesses being treated as duplicates
      // - different branches of the same chain being treated as duplicates
      final exactNameAndNearby = exactSameName && metres <= 150;

      final similarNameAndVeryNearby = similarName && metres <= 100;

      debugPrint(
        'DUPLICATE CHECK: '
        'new="$name" | '
        'existing="${place.name}" | '
        'distance=${metres.toStringAsFixed(1)}m | '
        'exactName=$exactSameName | '
        'similarName=$similarName',
      );

      if (exactNameAndNearby || similarNameAndVeryNearby) {
        return place;
      }
    }

    return null;
  }

  String _getCategoryEmoji(String category) {
    switch (category) {
      case 'Cafe':
        return '☕';
      case 'Restaurant':
        return '🍽️';
      case 'Shopping':
        return '🛍️';
      case 'Beauty':
        return '💅';
      case 'Attraction':
        return '🎡';
      case 'Museum':
        return '🏛️';
      case 'Park':
        return '🌳';
      case 'Nightlife':
        return '🍸';
      case 'Hotel':
        return '🏨';
      case 'Transport':
        return '🚆';
      case 'Other':
        return '✨';
      default:
        return '✨';
    }
  }

  void _toggleFocusMode(LatLng point) {
    setState(() {
      uiVisible = !uiVisible;

      if (!uiVisible) {
        activePanel = PinoriPanel.none;
        showAddContent = false;
        showPlacesContent = false;
        showTripsContent = false;
      }
    });
  }

  void _showTripActions(Trip trip, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PinoriColours.ivoryMist,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trip.name,
                  style: const TextStyle(
                    color: PinoriColours.richMahogany,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                ListTile(
                  leading: const Icon(
                    Icons.edit_outlined,
                    color: PinoriColours.richMahogany,
                  ),
                  title: const Text(
                    'Edit trip',
                    style: TextStyle(color: PinoriColours.richMahogany),
                  ),
                  onTap: () {
                    Navigator.pop(context);

                    _editTrip(trip, index);
                  },
                ),

                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: PinoriColours.tomatoJam,
                  ),
                  title: const Text(
                    'Delete trip',
                    style: TextStyle(color: PinoriColours.tomatoJam),
                  ),
                  onTap: () {
                    Navigator.pop(context);

                    _confirmDeleteTrip(trip, index);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPlaceCard(Place place) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PinoriColours.ivoryMist,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: const TextStyle(
                    color: PinoriColours.richMahogany,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  place.category,
                  style: const TextStyle(
                    color: PinoriColours.darkCyan,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  place.neighbourhood,
                  style: const TextStyle(color: PinoriColours.richMahogany),
                ),

                if (place.address != null && place.address!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    place.address!,
                    style: const TextStyle(color: PinoriColours.richMahogany),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPlaceActions(Place place) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PinoriColours.ivoryMist,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  place.name,
                  style: const TextStyle(
                    color: PinoriColours.richMahogany,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                ListTile(
                  leading: const Icon(
                    Icons.edit_outlined,
                    color: PinoriColours.richMahogany,
                  ),
                  title: const Text(
                    'Edit place',
                    style: TextStyle(color: PinoriColours.richMahogany),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _editPlace(place);
                  },
                ),

                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: PinoriColours.tomatoJam,
                  ),
                  title: const Text(
                    'Delete place',
                    style: TextStyle(color: PinoriColours.tomatoJam),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeletePlace(place);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeletePlace(Place place) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: PinoriColours.ivoryMist,
          title: const Text(
            'Delete place?',
            style: TextStyle(
              color: PinoriColours.richMahogany,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Delete "${place.name}"?',
            style: const TextStyle(color: PinoriColours.richMahogany),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: PinoriColours.tomatoJam),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    await PlaceStorageService.deletePlace(place.id);

    _loadPlacesForSelectedTrip();
  }

  Future<void> _editPlace(Place place) async {
    final nameController = TextEditingController(text: place.name);

    const categories = [
      'Cafe',
      'Restaurant',
      'Shopping',
      'Beauty',
      'Attraction',
      'Museum',
      'Park',
      'Nightlife',
      'Hotel',
      'Transport',
      'Other',
    ];

    String selectedCategory = categories.contains(place.category)
        ? place.category
        : 'Other';

    final neighbourhoodController = TextEditingController(
      text: place.neighbourhood,
    );

    final addressController = TextEditingController(text: place.address ?? '');
    final notesController = TextEditingController(text: place.notes ?? '');
    String? customImageBase64 = place.customImageBase64;
    bool visited = place.visited;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: PinoriColours.ivoryMist,
              title: const Text(
                'Edit place',
                style: TextStyle(
                  color: PinoriColours.richMahogany,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Place name',
                      ),
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: const [
                        DropdownMenuItem(value: 'Cafe', child: Text('Cafe')),
                        DropdownMenuItem(
                          value: 'Restaurant',
                          child: Text('Restaurant'),
                        ),
                        DropdownMenuItem(
                          value: 'Shopping',
                          child: Text('Shopping'),
                        ),
                        DropdownMenuItem(
                          value: 'Beauty',
                          child: Text('Beauty'),
                        ),
                        DropdownMenuItem(
                          value: 'Attraction',
                          child: Text('Attraction'),
                        ),
                        DropdownMenuItem(
                          value: 'Museum',
                          child: Text('Museum'),
                        ),
                        DropdownMenuItem(value: 'Park', child: Text('Park')),
                        DropdownMenuItem(
                          value: 'Nightlife',
                          child: Text('Nightlife'),
                        ),
                        DropdownMenuItem(value: 'Hotel', child: Text('Hotel')),
                        DropdownMenuItem(
                          value: 'Transport',
                          child: Text('Transport'),
                        ),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          selectedCategory = value;
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: neighbourhoodController,
                      decoration: const InputDecoration(
                        labelText: 'Neighbourhood',
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: 'Address'),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: notesController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Anything you want to remember ♡',
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: PinoriColours.richMahogany,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: PinoriColours.darkCyan,
                          ),

                          const SizedBox(width: 10),

                          const Expanded(
                            child: Text(
                              'Visited this place',
                              style: TextStyle(
                                color: PinoriColours.richMahogany,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          Switch(
                            value: visited,
                            activeTrackColor: PinoriColours.darkCyan,
                            activeThumbColor: PinoriColours.ivoryMist,
                            onChanged: (value) {
                              setDialogState(() {
                                visited = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picker = ImagePicker();

                          final image = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 80,
                          );

                          if (image == null) return;

                          final bytes = await image.readAsBytes();

                          customImageBase64 = base64Encode(bytes);
                        },
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          customImageBase64 != null
                              ? 'Change photo'
                              : 'Upload photo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();

                    final neighbourhood = neighbourhoodController.text.trim();

                    if (name.isEmpty ||
                        selectedCategory.isEmpty ||
                        neighbourhood.isEmpty) {
                      return;
                    }

                    final updatedPlace = Place(
                      id: place.id,
                      tripId: place.tripId,
                      name: name,
                      category: selectedCategory,
                      neighbourhood: neighbourhood,
                      latitude: place.latitude,
                      longitude: place.longitude,
                      address: addressController.text.trim().isEmpty
                          ? null
                          : addressController.text.trim(),
                      nearestStation: place.nearestStation,
                      sourceUrl: place.sourceUrl,
                      sourceType: place.sourceType,
                      confidence: place.confidence,
                      notes: notesController.text.trim().isEmpty
                          ? null
                          : notesController.text.trim(),
                      aiMetadata: place.aiMetadata,
                      createdAt: place.createdAt,
                      imageUrl: place.imageUrl,
                      localImagePath: place.localImagePath,
                      customImageBase64: customImageBase64,
                      visited: visited,
                    );

                    await PlaceStorageService.savePlace(updatedPlace);

                    _loadPlacesForSelectedTrip();

                    if (!mounted) return;

                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAddPlaceDialog() async {
    final nameController = TextEditingController();
    final neighbourhoodController = TextEditingController();
    final addressController = TextEditingController();

    const categories = [
      'Cafe',
      'Restaurant',
      'Shopping',
      'Beauty',
      'Attraction',
      'Museum',
      'Park',
      'Nightlife',
      'Hotel',
      'Transport',
      'Other',
    ];

    String selectedCategory = 'Cafe';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: PinoriColours.ivoryMist,

              title: const Text(
                'Add a place',
                style: TextStyle(
                  color: PinoriColours.richMahogany,
                  fontWeight: FontWeight.bold,
                ),
              ),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofillHints: const [],
                      decoration: const InputDecoration(
                        labelText: 'Place name',
                      ),
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          selectedCategory = value;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: neighbourhoodController,
                      autofillHints: const [],
                      decoration: const InputDecoration(
                        labelText: 'Neighbourhood',
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: addressController,
                      autofillHints: const [],
                      decoration: const InputDecoration(labelText: 'Address'),
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: () {
                    // Saving comes next!
                    debugPrint(
                      'Add: ${nameController.text} / $selectedCategory',
                    );
                  },
                  child: const Text('Add place'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showLinkImportDialog() async {
    final screenContext = context;

    final linkController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Paste a link ♡',
            style: TextStyle(
              color: PinoriColours.richMahogany,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: linkController,
            autofillHints: const [],
            decoration: const InputDecoration(
              labelText: 'Instagram, TikTok, etc.',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final link = linkController.text.trim();

                if (link.isEmpty) return;

                Navigator.pop(context);

                // Show loading
                showDialog(
                  context: screenContext,
                  barrierDismissible: false,
                  builder: (context) {
                    return const AlertDialog(
                      content: Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: PinoriColours.tomatoJam,
                            ),

                            SizedBox(height: 18),

                            Text(
                              'Checking the link... ♡',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: PinoriColours.richMahogany,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            SizedBox(height: 6),

                            Text(
                              'Finding and verifying the place',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: PinoriColours.richMahogany,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );

                try {
                  final result = await AiService.extractPlaceFromText('''
This is a social media/travel link:
$link

The place should be relevant to this trip destination:
${selectedTrip?.destination ?? ''}

Identify the specific place being recommended or shown.
Use web search to verify the place and its address.
Do not return a place from a different country or city unless there is very strong evidence that the post itself is about that place.
''');

                  if (!mounted) return;

                  // Close loading popup
                  Navigator.pop(screenContext);

                  if (result.name.isEmpty || result.confidence < 0.75) {
                    if (!mounted) return;

                    ScaffoldMessenger.of(screenContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'I couldn\'t confidently find this one ♡ Try a screenshot instead!',
                        ),
                      ),
                    );

                    return;
                  }

                  final confirmed = await _showFoundPlaceDialog(
                    name: result.name,
                    category: result.category,
                    neighbourhood: result.neighbourhood ?? '',
                    nearestStation: result.nearestStation ?? '',
                    address: result.address ?? '',
                    confidence: result.confidence,
                  );

                  if (!confirmed) return;

                  final searchQuery =
                      result.address != null && result.address!.isNotEmpty
                      ? result.address!
                      : [result.name, result.city, selectedTrip?.destination]
                            .where((part) => part != null && part.isNotEmpty)
                            .join(' ');

                  debugPrint('GEOCODING LINK: $searchQuery');

                  final coordinates = await GeocodingService.findCoordinates(
                    searchQuery,
                    destination: selectedTrip?.destination,
                  );

                  if (coordinates == null) {
                    if (!mounted) return;

                    ScaffoldMessenger.of(screenContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'I found the place, but couldn\'t locate it on the map ♡',
                        ),
                      ),
                    );

                    return;
                  }

                  final duplicatePlace = _findDuplicatePlace(
                    name: result.name,
                    latitude: coordinates.latitude,
                    longitude: coordinates.longitude,
                  );

                  if (duplicatePlace != null) {
                    if (!mounted) return;

                    ScaffoldMessenger.of(screenContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${duplicatePlace.name} is already pinned ♡',
                        ),
                      ),
                    );

                    return;
                  }

                  final newPlace = Place(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    tripId: selectedTrip!.id,
                    name: result.name,
                    category: result.category,
                    neighbourhood: result.neighbourhood ?? '',
                    latitude: coordinates.latitude,
                    longitude: coordinates.longitude,
                    address: result.address,
                    nearestStation: result.nearestStation,
                    sourceType: 'link',
                    sourceUrl: link,
                    confidence: result.confidence,
                    imageUrl: result.imageUrl,
                    aiMetadata: {'source': 'link', 'searchQuery': searchQuery},
                    createdAt: DateTime.now(),
                  );

                  await PlaceStorageService.savePlace(newPlace);

                  _loadPlacesForSelectedTrip();

                  if (!mounted) return;

                  ScaffoldMessenger.of(screenContext).showSnackBar(
                    SnackBar(content: Text('${newPlace.name} pinned ♡')),
                  );
                } catch (error) {
                  if (!mounted) return;

                  // Close loading popup
                  Navigator.pop(screenContext);

                  ScaffoldMessenger.of(screenContext).showSnackBar(
                    const SnackBar(
                      content: Text('I couldn’t find a place from that link ♡'),
                    ),
                  );

                  debugPrint('LINK IMPORT ERROR: $error');
                }
              },
              child: const Text('Find place'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _showFoundPlaceDialog({
    required String name,
    required String category,
    required String neighbourhood,
    required String nearestStation,
    required String address,
    required num? confidence,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: PinoriColours.ivoryMist,
          title: const Text(
            'Found the place! ♡',
            style: TextStyle(
              color: PinoriColours.richMahogany,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: PinoriColours.richMahogany,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Text('Category: $category'),
              const SizedBox(height: 8),
              Text('Neighbourhood: $neighbourhood'),
              const SizedBox(height: 8),
              Text('Nearest station: $nearestStation'),
              const SizedBox(height: 8),
              Text('Address: $address'),
              const SizedBox(height: 12),
              Text(
                'Confidence: ${((confidence ?? 0) * 100).round()}%',
                style: const TextStyle(
                  color: PinoriColours.darkCyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not this one'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Pin it ♡'),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  Future<void> _showAIImportDialog() async {
    if (selectedTrip == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create or select a trip first ♡')),
      );

      return;
    }

    final inputController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: PinoriColours.ivoryMist,

          title: const Text(
            'Import with AI',
            style: TextStyle(
              color: PinoriColours.richMahogany,
              fontWeight: FontWeight.bold,
            ),
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Paste a post, caption, link, or place recommendation and I’ll try to find it for you.',
                style: TextStyle(color: PinoriColours.richMahogany),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: inputController,
                minLines: 3,
                maxLines: 6,
                autofillHints: const [],
                decoration: const InputDecoration(
                  labelText: 'Paste here',
                  hintText: 'e.g. this cafe in Seongsu looks amazing...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),

            ElevatedButton(
              onPressed: () async {
                final input = inputController.text.trim();

                if (input.isEmpty) return;

                // Close the AI input dialog
                Navigator.pop(context);

                // Show loading popup
                showDialog(
                  context: this.context,
                  barrierDismissible: false,
                  builder: (context) {
                    return const AlertDialog(
                      backgroundColor: PinoriColours.ivoryMist,
                      content: Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: PinoriColours.tomatoJam,
                            ),

                            SizedBox(height: 18),

                            Text(
                              'Finding something cute... ♡',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: PinoriColours.richMahogany,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            SizedBox(height: 6),

                            Text(
                              'Searching and checking the best match',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: PinoriColours.richMahogany,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );

                // 1. AI extracts the place information
                final result = await AiService.extractPlaceFromText('''
This is an AI travel recommendation request.

User request:
$input

Trip destination:
${selectedTrip?.destination ?? ''}

If the user names a specific place, identify and verify that place.

If the user is asking for a recommendation instead, search the web and recommend ONE real place that closely matches what they asked for.

For recommendation requests:
- respect the requested neighbourhood or area
- respect the trip destination
- use reliable evidence that the place matches the request
- preferences like "cute", "pretty", "aesthetic", "quiet", or "romantic" should be treated as recommendation criteria
- verify that the place currently exists
- find a real address
- do not return somewhere in a different city just because it is popular

Return the single best verified match.
''');

                if (!mounted) return;

                // Close loading popup
                Navigator.pop(this.context);

                if (result.name.isEmpty || result.confidence < 0.75) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'I couldn\'t confidently find a good match ♡ Try wording it differently!',
                      ),
                    ),
                  );

                  return;
                }

                final confirmed = await _showFoundPlaceDialog(
                  name: result.name,
                  category: result.category,
                  neighbourhood: result.neighbourhood ?? '',
                  nearestStation: result.nearestStation ?? '',
                  address: result.address ?? '',
                  confidence: result.confidence,
                );

                if (!confirmed) return;

                // 2. Build a useful search query
                final destination = selectedTrip?.destination ?? '';
                final city = result.city ?? '';

                final destinationAlreadyHasCity =
                    city.isNotEmpty &&
                    destination.toLowerCase().contains(city.toLowerCase());

                final searchQuery =
                    result.address != null && result.address!.isNotEmpty
                    ? result.address!
                    : [
                        result.name,
                        if (!destinationAlreadyHasCity) city,
                        destination,
                      ].where((part) => part.isNotEmpty).join(' ');

                debugPrint('SEARCHING FOR: $searchQuery');

                // 3. Find the real coordinates

                final coordinates = await GeocodingService.findCoordinates(
                  searchQuery,
                  destination: selectedTrip?.destination,
                );

                if (coordinates == null) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'I found the place name, but not its location ♡',
                      ),
                    ),
                  );

                  return;
                }

                debugPrint(
                  'AI DUPLICATE CHECK STARTING: '
                  '${result.name} | '
                  '${coordinates.latitude}, ${coordinates.longitude} | '
                  '${result.address}',
                );

                final duplicatePlace = _findDuplicatePlace(
                  name: result.name,
                  latitude: coordinates.latitude,
                  longitude: coordinates.longitude,
                );

                if (duplicatePlace != null) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${duplicatePlace.name} is already pinned ♡',
                      ),
                    ),
                  );

                  return;
                }

                // 4. Turn it into a real Pinori place
                final newPlace = Place(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  tripId: selectedTrip!.id,
                  name: result.name,
                  category: result.category,
                  neighbourhood: result.neighbourhood ?? '',
                  latitude: coordinates.latitude,
                  longitude: coordinates.longitude,
                  address: result.address,
                  nearestStation: result.nearestStation,
                  sourceType: 'ai',
                  confidence: result.confidence,
                  imageUrl: result.imageUrl,
                  aiMetadata: {
                    'originalInput': input,
                    'city': result.city,
                    'searchQuery': searchQuery,
                  },
                  createdAt: DateTime.now(),
                );

                // 5. Save it permanently
                await PlaceStorageService.savePlace(newPlace);

                // 6. Reload Places → this also updates the map
                _loadPlacesForSelectedTrip();

                if (!mounted) return;

                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('${result.name} pinned ♡')),
                );
              },
              child: const Text('Find place'),
            ),
          ],
        );
      },
    );
  }

  Future<Trip?> _chooseTripForSharedImport() async {
    if (trips.isEmpty) {
      if (!mounted) return null;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a trip before sharing places to Pinori ♡'),
        ),
      );

      return null;
    }

    return showDialog<Trip>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: PinoriColours.ivoryMist,
          title: const Text(
            'Which trip? ♡',
            style: TextStyle(
              color: PinoriColours.richMahogany,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: trips.length,
              separatorBuilder: (context, index) {
                return const SizedBox(height: 8);
              },
              itemBuilder: (context, index) {
                final trip = trips[index];

                return InkWell(
                  onTap: () {
                    Navigator.pop(context, trip);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: PinoriColours.richMahogany,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text('✈️', style: TextStyle(fontSize: 24)),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trip.name,
                                style: const TextStyle(
                                  color: PinoriColours.richMahogany,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                trip.destination,
                                style: const TextStyle(
                                  color: PinoriColours.richMahogany,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Icon(
                          Icons.chevron_right,
                          color: PinoriColours.richMahogany,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSharedMedia(List<SharedMediaFile> sharedFiles) async {
    if (sharedFiles.isEmpty || !mounted) return;

    final trip = await _chooseTripForSharedImport();

    if (trip == null || !mounted) return;

    setState(() {
      selectedTrip = trip;
    });

    await TripStorageService.setSelectedTrip(trip.id);

    _loadPlacesForSelectedTrip();

    final images = sharedFiles
        .where((file) => file.type == SharedMediaType.image)
        .toList();

    final textItems = sharedFiles
        .where(
          (file) =>
              file.type == SharedMediaType.text ||
              file.type == SharedMediaType.url,
        )
        .toList();

    // Shared screenshots/images
    if (images.isNotEmpty) {
      for (var i = 0; i < images.length; i++) {
        final image = XFile(images[i].path);

        await _processScreenshot(image, i + 1, images.length);
      }

      return;
    }

    // Shared links / text
    if (textItems.isNotEmpty) {
      final sharedText = textItems.map((file) => file.path).join('\n').trim();

      await _importSharedText(sharedText);
    }
  }

  Future<void> _importSharedText(String sharedText) async {
    if (sharedText.trim().isEmpty || selectedTrip == null || !mounted) {
      return;
    }

    // Grab a source URL if the shared content contains one.
    final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(sharedText);

    final sourceUrl = urlMatch?.group(0);

    // Loading popup
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          backgroundColor: PinoriColours.ivoryMist,
          content: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: PinoriColours.tomatoJam,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Checking your share... ♡',
                  style: TextStyle(
                    color: PinoriColours.richMahogany,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    try {
      final result = await AiService.extractPlaceFromText('''
This content was shared into Pinori from another app:

$sharedText

Trip destination:
${selectedTrip!.destination}

Identify the specific real-world place being shown or recommended.

If the shared content itself contains enough information to identify the place,
use that information.

If the content is only a link or does not contain enough information,
do not guess.
''');

      if (!mounted) return;

      // Close loading popup
      Navigator.pop(context);

      if (result.name.isEmpty || result.confidence < 0.75) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'I couldn\'t confidently find this one ♡ Try a screenshot instead!',
            ),
          ),
        );

        return;
      }

      final confirmed = await _showFoundPlaceDialog(
        name: result.name,
        category: result.category,
        neighbourhood: result.neighbourhood ?? '',
        nearestStation: result.nearestStation ?? '',
        address: result.address ?? '',
        confidence: result.confidence,
      );

      if (!confirmed || !mounted) return;

      final searchQuery = result.address != null && result.address!.isNotEmpty
          ? result.address!
          : [
              result.name,
              result.city,
              selectedTrip!.destination,
            ].where((part) => part != null && part.isNotEmpty).join(' ');

      debugPrint('GEOCODING SHARED PLACE: $searchQuery');

      final coordinates = await GeocodingService.findCoordinates(
        searchQuery,
        destination: selectedTrip?.destination,
      );

      if (coordinates == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'I found the place, but couldn\'t locate it on the map ♡',
            ),
          ),
        );

        return;
      }

      final duplicatePlace = _findDuplicatePlace(
        name: result.name,
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
      );

      if (duplicatePlace != null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${duplicatePlace.name} is already pinned ♡')),
        );

        return;
      }

      final newPlace = Place(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        tripId: selectedTrip!.id,
        name: result.name,
        category: result.category,
        neighbourhood: result.neighbourhood ?? '',
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
        address: result.address,
        nearestStation: result.nearestStation,
        sourceType: 'share',
        sourceUrl: sourceUrl,
        confidence: result.confidence,
        imageUrl: result.imageUrl,
        aiMetadata: {
          'source': 'share',
          'sharedText': sharedText,
          'searchQuery': searchQuery,
        },
        createdAt: DateTime.now(),
      );

      await PlaceStorageService.savePlace(newPlace);

      _loadPlacesForSelectedTrip();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${newPlace.name} pinned ♡')));
    } catch (error) {
      debugPrint('SHARED TEXT IMPORT ERROR: $error');

      if (!mounted) return;

      // Close loading popup if an error happened
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong with that share ♡')),
      );
    }
  }

  Future<void> _pickScreenshot() async {
    if (selectedTrip == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create or select a trip first ♡')),
      );

      return;
    }

    if (isProcessingScreenshot) return;

    final picker = ImagePicker();

    final images = await picker.pickMultiImage();

    if (images.isEmpty) return;
    var pinnedCount = 0;
    var skippedCount = 0;

    for (var i = 0; i < images.length; i++) {
      final placesBefore = places.length;

      await _processScreenshot(images[i], i + 1, images.length);

      final placesAfter = places.length;

      if (placesAfter > placesBefore) {
        pinnedCount++;
      } else {
        skippedCount++;
      }
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          images.length == 1
              ? (pinnedCount == 1 ? 'Place pinned ♡' : 'Screenshot skipped ♡')
              : 'All done ♡  $pinnedCount pinned · $skippedCount skipped',
        ),
      ),
    );
  }

  Future<void> _processScreenshot(
    XFile image,
    int currentNumber,
    int totalImages,
  ) async {
    if (isProcessingScreenshot) return;

    isProcessingScreenshot = true;

    final bytes = await image.readAsBytes();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: PinoriColours.ivoryMist,
          content: Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: PinoriColours.tomatoJam),

                SizedBox(height: 18),

                Text(
                  totalImages > 1
                      ? 'Finding places... $currentNumber of $totalImages ♡'
                      : 'Finding the place... ♡',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: PinoriColours.richMahogany,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 6),

                Text(
                  'Checking the screenshot and verifying the location',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: PinoriColours.richMahogany,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://pinori-backend.onrender.com/extract-place-image'),
    );

    request.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: image.name),
    );

    final response = await request.send();

    final responseBody = await response.stream.bytesToString();

    if (!mounted) return;

    Navigator.pop(context);

    final data = jsonDecode(responseBody) as Map<String, dynamic>;

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: PinoriColours.ivoryMist,

          title: const Text(
            'Found the place! ♡',
            style: TextStyle(
              color: PinoriColours.richMahogany,
              fontWeight: FontWeight.bold,
            ),
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['name'] ?? '',
                style: const TextStyle(
                  color: PinoriColours.richMahogany,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 14),

              Text('Category: ${data['category'] ?? ''}'),

              const SizedBox(height: 8),

              Text(
                'Neighbourhood: '
                '${data['neighbourhood'] ?? ''}',
              ),

              const SizedBox(height: 8),

              Text(
                'Nearest station: '
                '${data['nearestStation'] ?? ''}',
              ),

              const SizedBox(height: 8),

              Text(
                'Address: '
                '${data['address'] ?? ''}',
              ),

              const SizedBox(height: 12),

              Text(
                'Confidence: '
                '${((data['confidence'] ?? 0) * 100).round()}%',
                style: const TextStyle(
                  color: PinoriColours.darkCyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Not this one'),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Pin it ♡'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      isProcessingScreenshot = false;
      return;
    }

    // Use the verified address if we have one
    final address = data['address']?.toString() ?? '';

    final searchQuery = address.isNotEmpty
        ? address
        : [data['name'], data['city'], selectedTrip?.destination]
              .where((part) => part != null && part.toString().isNotEmpty)
              .join(' ');

    // Find coordinates

    var coordinates = await GeocodingService.findCoordinates(
      searchQuery,
      destination: selectedTrip?.destination,
    );

    final localAddress = data['localAddress']?.toString().trim() ?? '';

    final localName = data['localName']?.toString().trim() ?? '';

    debugPrint('LOCAL ADDRESS FROM AI: "$localAddress"');
    debugPrint('LOCAL NAME FROM AI: "$localName"');

    // Try the native-language address with Nominatim
    if (coordinates == null && localAddress.isNotEmpty) {
      debugPrint('English address failed. Trying local address: $localAddress');

      coordinates = await GeocodingService.findCoordinates(
        localAddress,
        destination: selectedTrip?.destination,
      );
    }

    // Final Korea fallback: Kakao
    if (coordinates == null &&
        (localAddress.isNotEmpty || localName.isNotEmpty)) {
      debugPrint('Nominatim failed. Trying Kakao Korea fallback...');

      coordinates = await GeocodingService.findCoordinatesKorea(
        name: localName,
        address: localAddress,
      );
    }

    if (coordinates == null) {
      if (!mounted) return;

      isProcessingScreenshot = false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('I found the place, but couldn’t pin the location ♡'),
        ),
      );

      return;
    }

    final duplicatePlace = _findDuplicatePlace(
      name: data['name'] ?? '',
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
    );

    if (duplicatePlace != null) {
      isProcessingScreenshot = false;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${duplicatePlace.name} is already pinned ♡')),
      );

      return;
    }

    // Create the real saved place
    final newPlace = Place(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tripId: selectedTrip!.id,
      name: data['name'] ?? '',
      category: data['category'] ?? 'Other',
      neighbourhood: data['neighbourhood'] ?? '',
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
      address: address.isEmpty ? null : address,
      nearestStation: data['nearestStation'],
      sourceType: 'screenshot',
      confidence: (data['confidence'] as num?)?.toDouble(),
      imageUrl: data['imageUrl'],
      localImagePath: image.path,
      aiMetadata: {'source': 'screenshot', 'searchQuery': searchQuery},
      createdAt: DateTime.now(),
    );

    // Save into Hive
    await PlaceStorageService.savePlace(newPlace);

    // Refresh list + map
    _loadPlacesForSelectedTrip();

    isProcessingScreenshot = false;

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${newPlace.name} pinned ♡')));
  }

  double get _drawerHeight {
    switch (activePanel) {
      case PinoriPanel.none:
        return 63;

      case PinoriPanel.add:
        return 263;

      case PinoriPanel.places:
        return 360;

      case PinoriPanel.trips:
        if (trips.isEmpty) return 240;

        final wantedHeight = 180.0 + (trips.length * 80.0);

        return wantedHeight.clamp(260.0, 430.0);
    }
  }

  double get _outerPanelHeight {
    return _drawerHeight + 45;
  }

  double get _panelWidth {
    switch (activePanel) {
      case PinoriPanel.none:
        return 192;

      case PinoriPanel.add:
        return 310;

      case PinoriPanel.places:
        return 330;

      case PinoriPanel.trips:
        return 310;
    }
  }

  void _closePanel() {
    setState(() {
      showAddContent = false;
      showPlacesContent = false;
      showTripsContent = false;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      setState(() {
        activePanel = PinoriPanel.none;
      });
    });
  }

  Future<void> _editTrip(Trip trip, int index) async {
    final nameController = TextEditingController(text: trip.name);

    final destinationController = TextEditingController(text: trip.destination);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: PinoriColours.ivoryMist,

          title: const Text(
            'Edit trip',
            style: TextStyle(
              color: PinoriColours.richMahogany,
              fontWeight: FontWeight.bold,
            ),
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofillHints: const [],
                decoration: const InputDecoration(labelText: 'Trip name'),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: destinationController,
                autofillHints: const [],
                decoration: const InputDecoration(labelText: 'Destination'),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),

            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();

                final destination = destinationController.text.trim();

                if (name.isEmpty || destination.isEmpty) {
                  return;
                }

                final updatedTrip = Trip(
                  id: trip.id,
                  name: name,
                  destination: destination,
                  startDate: trip.startDate,
                  endDate: trip.endDate,
                );

                setState(() {
                  trips[index] = updatedTrip;

                  if (selectedTrip?.id == trip.id) {
                    selectedTrip = updatedTrip;
                  }
                });

                await TripStorageService.saveTrip(updatedTrip);

                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteTrip(Trip trip, int index) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: PinoriColours.ivoryMist,

          title: const Text(
            'Delete trip?',
            style: TextStyle(
              color: PinoriColours.richMahogany,
              fontWeight: FontWeight.bold,
            ),
          ),

          content: Text(
            'Delete "${trip.name}"?',
            style: const TextStyle(color: PinoriColours.richMahogany),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: PinoriColours.tomatoJam),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    setState(() {
      trips.removeAt(index);

      if (selectedTrip?.id == trip.id) {
        selectedTrip = trips.isNotEmpty ? trips.first : null;
      }
    });
    await TripStorageService.deleteTrip(trip.id);

    await TripStorageService.setSelectedTrip(selectedTrip?.id);
  }

  Future<void> _showCreateTripDialog() async {
    final nameController = TextEditingController();
    final destinationController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: PinoriColours.ivoryMist,
          title: const Text(
            'New trip',
            style: TextStyle(
              color: PinoriColours.richMahogany,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofillHints: const [],
                decoration: const InputDecoration(labelText: 'Trip name'),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: destinationController,
                autofillHints: const [],
                decoration: const InputDecoration(labelText: 'Destination'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),

            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty ||
                    destinationController.text.trim().isEmpty) {
                  return;
                }

                final newTrip = Trip(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.trim(),
                  destination: destinationController.text.trim(),
                );

                setState(() {
                  trips.add(newTrip);
                  selectedTrip = newTrip;
                });

                await TripStorageService.saveTrip(newTrip);
                await TripStorageService.setSelectedTrip(newTrip.id);

                Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _loadTrips() {
    final loadedTrips = TripStorageService.getTrips();

    final selectedTripId = TripStorageService.getSelectedTripId();

    setState(() {
      trips
        ..clear()
        ..addAll(loadedTrips);

      if (selectedTripId != null) {
        for (final trip in trips) {
          if (trip.id == selectedTripId) {
            selectedTrip = trip;
            break;
          }
        }
      }

      selectedTrip ??= trips.isNotEmpty ? trips.first : null;
    });

    _loadPlacesForSelectedTrip();
  }

  void _loadPlacesForSelectedTrip() {
    if (selectedTrip == null) {
      setState(() {
        places.clear();
        heyGirlHasUnread = false;
        heyGirlAiSuggestion = null;
        lastHeyGirlSuggestion = null;
        lastHeyGirlPlaceSignature = null;
      });

      return;
    }

    final loadedPlaces = PlaceStorageService.getPlacesForTrip(selectedTrip!.id);

    // Build a fingerprint of the actual trip places.
    final signatureParts = loadedPlaces.map((place) {
      return '${place.id}|'
          '${place.category}|'
          '${place.neighbourhood}|'
          '${place.latitude.toStringAsFixed(5)}|'
          '${place.longitude.toStringAsFixed(5)}'
          '${place.visited}';
    }).toList()..sort();

    final newSignature = signatureParts.join('||');

    final placesChanged =
        lastHeyGirlPlaceSignature == null ||
        newSignature != lastHeyGirlPlaceSignature;

    setState(() {
      places
        ..clear()
        ..addAll(loadedPlaces);

      lastHeyGirlPlaceSignature = newSignature;
      lastHeyGirlSuggestion = _getHeyGirlSuggestion();
    });

    if (placesChanged) {
      _refreshHeyGirlInsight();
    }
  }

  Future<void> _addTestPlace() async {
    if (selectedTrip == null) {
      debugPrint('No trip selected!');
      return;
    }

    final testPlace = Place(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tripId: selectedTrip!.id,
      name: 'Test Seoul Pin',
      category: 'Cafe',
      neighbourhood: 'Seoul',
      latitude: 37.5665,
      longitude: 126.9780,
      address: 'Seoul, South Korea',
      sourceType: 'test',
      confidence: 1.0,
      createdAt: DateTime.now(),
    );

    await PlaceStorageService.savePlace(testPlace);

    _loadPlacesForSelectedTrip();

    debugPrint('Test place saved!');
  }

  Future<void> _setPlaceVisited(Place place, bool visited) async {
    final updatedPlace = Place(
      id: place.id,
      tripId: place.tripId,
      name: place.name,
      category: place.category,
      neighbourhood: place.neighbourhood,
      latitude: place.latitude,
      longitude: place.longitude,
      address: place.address,
      nearestStation: place.nearestStation,
      sourceUrl: place.sourceUrl,
      sourceType: place.sourceType,
      confidence: place.confidence,
      notes: place.notes,
      aiMetadata: place.aiMetadata,
      createdAt: place.createdAt,
      imageUrl: place.imageUrl,
      localImagePath: place.localImagePath,
      customImageBase64: place.customImageBase64,
      visited: visited,
    );

    await PlaceStorageService.savePlace(updatedPlace);

    if (!mounted) return;

    setState(() {
      selectedPlace = updatedPlace;
    });

    _loadPlacesForSelectedTrip();
  }

  void _focusOnPlace(Place place) {
    setState(() {
      selectedPlace = place;

      showPlacesContent = false;
      showAddContent = false;
      showTripsContent = false;
      activePanel = PinoriPanel.none;
    });

    mapController.move(LatLng(place.latitude, place.longitude), 15.5);
  }

  @override
  void initState() {
    super.initState();

    _loadTrips();

    _shareIntentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (sharedFiles) async {
        await _handleSharedMedia(sharedFiles);

        await ReceiveSharingIntent.instance.reset();
      },
      onError: (error) {
        debugPrint('SHARE INTENT ERROR: $error');
      },
    );

    ReceiveSharingIntent.instance.getInitialMedia().then((sharedFiles) {
      if (sharedFiles.isEmpty) return;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _handleSharedMedia(sharedFiles);

        await ReceiveSharingIntent.instance.reset();
      });
    });
  }

  @override
  void dispose() {
    _shareIntentSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: AspectRatio(
            aspectRatio: 402 / 874,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: PinoriMap(
                          mapController: mapController,
                          destination: selectedTrip?.destination ?? '',
                          onMapTap: _toggleFocusMode,
                          onPlaceTap: (place) {
                            setState(() {
                              if (selectedPlace?.id == place.id) {
                                selectedPlace = null;
                              } else {
                                selectedPlace = place;
                              }
                            });
                          },
                          onVisitedChanged: (place, visited) {
                            _setPlaceVisited(place, visited);
                          },
                          places: places,
                          selectedPlace: selectedPlace,
                        ),
                      ),

                      AnimatedOpacity(
                        opacity: uiVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: IgnorePointer(
                          ignoring: !uiVisible,
                          child: SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 20, top: 18),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: GestureDetector(
                                  onTap: () async {
                                    if (!heyGirlExpanded) {
                                      // Expand first
                                      setState(() {
                                        heyGirlExpanded = true;
                                        heyGirlHasUnread = false;
                                      });

                                      await Future.delayed(
                                        const Duration(milliseconds: 220),
                                      );

                                      if (!mounted) return;

                                      // Then reveal text
                                      setState(() {
                                        heyGirlShowText = true;
                                      });
                                    } else {
                                      // Hide text first
                                      setState(() {
                                        heyGirlShowText = false;
                                      });

                                      await Future.delayed(
                                        const Duration(milliseconds: 120),
                                      );

                                      if (!mounted) return;

                                      // Then shrink
                                      setState(() {
                                        heyGirlExpanded = false;
                                      });
                                    }
                                  },

                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        width: heyGirlExpanded ? 300 : 150,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: PinoriColours.ivoryMist,
                                          border: Border.all(
                                            color: PinoriColours.richMahogany,
                                            width: 3,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),

                                        child: AnimatedSize(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeInOutCubic,
                                          alignment: Alignment.topLeft,

                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                OnboardingStorageService.getPreferredGreeting()
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                  color: PinoriColours
                                                      .richMahogany,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w900,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),

                                              if (heyGirlShowText) ...[
                                                const SizedBox(height: 10),

                                                Text(
                                                  heyGirlIsThinking
                                                      ? 'Hmm… let me look at your pins 👀'
                                                      : (heyGirlAiSuggestion ??
                                                            _getHeyGirlSuggestion()),
                                                  style: const TextStyle(
                                                    color: PinoriColours
                                                        .richMahogany,
                                                    fontSize: 14,
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Unread insight badge
                                      if (heyGirlHasUnread)
                                        Positioned(
                                          top: -8,
                                          right: -8,
                                          child: Container(
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              color: PinoriColours.tomatoJam,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color:
                                                    PinoriColours.richMahogany,
                                                width: 2,
                                              ),
                                            ),
                                            child: const Center(
                                              child: Text(
                                                '!',
                                                style: TextStyle(
                                                  color:
                                                      PinoriColours.ivoryMist,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        left: 0,
                        right: 0,
                        bottom: uiVisible ? 26 : -400,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            width: _panelWidth,
                            height: _outerPanelHeight,
                            child: Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                // Cream nav / drawer
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 240),
                                    curve: Curves.easeOutCubic,
                                    height: _drawerHeight,
                                    decoration: BoxDecoration(
                                      color: PinoriColours.ivoryMist,
                                      border: Border.all(
                                        color: PinoriColours.richMahogany,
                                        width: 4,
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 120,
                                      ),
                                      child: _buildActivePanelContent(),
                                    ),
                                  ),
                                ),

                                // Pinori pin
                                Positioned(
                                  top: activePanel == PinoriPanel.add ? 2 : 0,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _selectPanel(PinoriPanel.add),
                                    child: SizedBox(
                                      width: 88,
                                      height: 92,
                                      child: Align(
                                        alignment: Alignment.topCenter,
                                        child: Image.asset(
                                          'assets/icons/pinori_pin.png',
                                          width: 70,
                                          height: 84,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClosedNav() {
    return Row(
      key: const ValueKey('closedNav'),
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        IconButton(
          onPressed: () => _selectPanel(PinoriPanel.places),
          icon: const Icon(
            Icons.format_list_bulleted,
            size: 34,
            color: PinoriColours.richMahogany,
          ),
        ),

        // Space for the centre Pinori pin
        const SizedBox(width: 52),

        IconButton(
          onPressed: () => _selectPanel(PinoriPanel.trips),
          icon: const Icon(
            Icons.work_outline,
            size: 34,
            color: PinoriColours.richMahogany,
          ),
        ),
      ],
    );
  }

  Widget _buildCloseButton() {
    return Align(
      alignment: Alignment.topLeft,
      child: GestureDetector(
        onTap: _closePanel,
        behavior: HitTestBehavior.opaque,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Icon(
              Icons.arrow_back,
              size: 22,
              color: PinoriColours.richMahogany,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivePanelContent() {
    switch (activePanel) {
      case PinoriPanel.none:
        return _buildClosedNav();

      case PinoriPanel.add:
        return showAddContent ? _buildAddContent() : const SizedBox.shrink();

      case PinoriPanel.places:
        return showPlacesContent
            ? _buildPlacesContent()
            : const SizedBox.shrink();

      case PinoriPanel.trips:
        return showTripsContent
            ? _buildTripsContent()
            : const SizedBox.shrink();
    }
  }

  Widget _buildAddContent() {
    return Padding(
      key: const ValueKey('addContent'),
      padding: const EdgeInsets.fromLTRB(18, 32, 18, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildCloseButton(),

              const Expanded(
                child: Text(
                  'What are we pinning?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: PinoriColours.richMahogany,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Balances the close button so the title stays centred
              const SizedBox(width: 44, height: 44),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AddOption(
                emoji: '🔗',
                label: 'Link',
                onTap: () {
                  _showLinkImportDialog();
                },
              ),
              _AddOption(
                emoji: '🖼️',
                label: 'Screenshot',
                onTap: () {
                  _pickScreenshot();
                },
              ),
            ],
          ),

          const SizedBox(height: 2),

          _AddOption(
            emoji: '✨',
            label: 'Import with AI',
            onTap: () {
              _showAIImportDialog();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesContent() {
    if (selectedPlaceCategory == null) {
      final categories = _getAvailablePlaceCategories();

      return Padding(
        key: const ValueKey('placeCategories'),
        padding: const EdgeInsets.fromLTRB(18, 32, 18, 12),
        child: Column(
          children: [
            Row(
              children: [
                // Goes all the way back to the main nav
                _buildCloseButton(),

                const Expanded(
                  child: Text(
                    'Places',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: PinoriColours.richMahogany,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),

                // Keeps title centred
                const SizedBox(width: 44, height: 44),
              ],
            ),

            const SizedBox(height: 10),

            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: categories.length,
                separatorBuilder: (context, index) {
                  return const SizedBox(height: 8);
                },
                itemBuilder: (context, index) {
                  final category = categories[index];

                  final count = category == 'All Places'
                      ? places.length
                      : places
                            .where((place) => place.category == category)
                            .length;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        selectedPlaceCategory = category;
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: PinoriColours.ivoryMist,
                        border: Border.all(
                          color: PinoriColours.richMahogany,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          category == 'All Places'
                              ? Image.asset(
                                  'assets/icons/pinori_pin.png',
                                  width: 24,
                                  height: 30,
                                  fit: BoxFit.contain,
                                )
                              : Text(
                                  _getCategoryEmoji(category),
                                  style: const TextStyle(fontSize: 22),
                                ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Text(
                              category,
                              style: const TextStyle(
                                color: PinoriColours.richMahogany,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: PinoriColours.tomatoJam,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: PinoriColours.richMahogany,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: PinoriColours.ivoryMist,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(width: 6),

                          const Icon(
                            Icons.chevron_right,
                            color: PinoriColours.richMahogany,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }
    final filteredPlaces = selectedPlaceCategory == 'All Places'
        ? places
        : places
              .where((place) => place.category == selectedPlaceCategory)
              .toList();
    return Padding(
      key: const ValueKey('placesContent'),
      padding: const EdgeInsets.fromLTRB(18, 32, 18, 12),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    selectedPlaceCategory = null;
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Icon(
                      Icons.arrow_back,
                      size: 22,
                      color: PinoriColours.richMahogany,
                    ),
                  ),
                ),
              ),

              Expanded(
                child: Text(
                  selectedPlaceCategory ?? 'Places',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: PinoriColours.richMahogany,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(width: 44, height: 44),
            ],
          ),
          const SizedBox(height: 8),

          Expanded(
            child: filteredPlaces.isEmpty
                ? const Center(
                    child: Text(
                      'No pins yet ♡',
                      style: TextStyle(
                        color: PinoriColours.richMahogany,
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: filteredPlaces.length,
                    separatorBuilder: (context, index) {
                      return const SizedBox(height: 8);
                    },
                    itemBuilder: (context, index) {
                      final place = filteredPlaces[index];

                      return _PlaceRow(
                        name: place.name,
                        detail: '${place.neighbourhood} · ${place.category}',

                        onTap: () {
                          _focusOnPlace(place);
                        },
                        onLongPress: () {
                          _showPlaceActions(place);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripsContent() {
    return Padding(
      key: const ValueKey('tripsContent'),
      padding: const EdgeInsets.fromLTRB(18, 32, 18, 12),
      child: Column(
        children: [
          Row(
            children: [
              _buildCloseButton(),

              const Expanded(
                child: Text(
                  'My trips',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: PinoriColours.richMahogany,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(width: 44, height: 44),
            ],
          ),

          const SizedBox(height: 8),

          Expanded(
            child: trips.isEmpty
                ? const Center(
                    child: Text(
                      'No trips yet ♡',
                      style: TextStyle(
                        color: PinoriColours.richMahogany,
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: trips.length,
                    separatorBuilder: (context, index) {
                      return const SizedBox(height: 10);
                    },
                    itemBuilder: (context, index) {
                      final trip = trips[index];

                      return GestureDetector(
                        onTap: () async {
                          setState(() {
                            selectedTrip = trip;
                          });

                          _loadPlacesForSelectedTrip();

                          await TripStorageService.setSelectedTrip(trip.id);
                        },

                        onLongPress: () {
                          _showTripActions(trip, index);
                        },

                        child: _TripCard(
                          emoji: '✈️',
                          name: trip.name,
                          detail: trip.destination,
                          selected: selectedTrip?.id == trip.id,
                        ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showCreateTripDialog,
              icon: const Icon(Icons.add),
              label: const Text('New trip'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddOption extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _AddOption({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(
                color: PinoriColours.richMahogany,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  final String name;
  final String detail;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const _PlaceRow({
    required this.name,
    required this.detail,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            Image.asset(
              'assets/icons/pinori_pin.png',
              width: 24,
              height: 30,
              fit: BoxFit.contain,
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: PinoriColours.richMahogany,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PinoriColours.richMahogany,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final String emoji;
  final String name;
  final String detail;
  final bool selected;

  const _TripCard({
    required this.emoji,
    required this.name,
    required this.detail,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected
            ? PinoriColours.darkCyan.withOpacity(0.15)
            : Colors.transparent,
        border: Border.all(
          color: selected ? PinoriColours.darkCyan : PinoriColours.richMahogany,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: PinoriColours.richMahogany,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Text(
                  detail,
                  style: const TextStyle(
                    color: PinoriColours.richMahogany,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          if (selected)
            const Icon(
              Icons.check_circle,
              color: PinoriColours.darkCyan,
              size: 20,
            ),
        ],
      ),
    );
  }
}

const _panelTitle = TextStyle(
  color: PinoriColours.richMahogany,
  fontSize: 20,
  fontWeight: FontWeight.w900,
);
