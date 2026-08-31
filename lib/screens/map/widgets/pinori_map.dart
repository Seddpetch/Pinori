import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/place.dart';

import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

class PinoriMap extends StatelessWidget {
  final MapController mapController;
  final void Function(LatLng point)? onMapTap;
  final void Function(Place place)? onPlaceTap;
  final List<Place> places;
  final Place? selectedPlace;
  final String destination;
  final void Function(Place place, bool visited)? onVisitedChanged;

  const PinoriMap({
    super.key,
    required this.mapController,
    this.onMapTap,
    this.onPlaceTap,
    required this.places,
    this.selectedPlace,
    required this.destination,
    this.onVisitedChanged,
  });

  bool _isKoreaDestination(String value) {
    final text = value.toLowerCase();

    const koreaTerms = [
      'korea',
      'seoul',
      'busan',
      'jeju',
      'incheon',
      'daegu',
      'daejeon',
      'gwangju',
      'ulsan',
      'suwon',
      'yongin',
      'gyeonggi',
    ];

    return koreaTerms.any((term) => text.contains(term));
  }

  Future<void> _openDirections(Place place) async {
    final address = place.address ?? '';

    final hasKoreanText = RegExp(r'[가-힣]').hasMatch(address);

    final isKorea =
        _isKoreaDestination(destination) ||
        _isKoreaDestination(address) ||
        hasKoreanText;

    debugPrint('DIRECTIONS DEBUG:');
    debugPrint('Trip destination: "$destination"');
    debugPrint('Place address: "${place.address}"');
    debugPrint('isKorea: $isKorea');

    if (isKorea) {
      final naverUri = Uri.parse(
        'nmap://navigation'
        '?dlat=${place.latitude}'
        '&dlng=${place.longitude}'
        '&dname=${Uri.encodeComponent(place.name)}'
        '&appname=com.pinori.app',
      );

      final naverWebFallback = Uri.parse(
        'https://map.naver.com/p/directions/'
        '${place.longitude},${place.latitude},'
        '${Uri.encodeComponent(place.name)}',
      );

      if (await canLaunchUrl(naverUri)) {
        await launchUrl(naverUri);
      } else {
        await launchUrl(naverWebFallback, mode: LaunchMode.externalApplication);
      }

      return;
    }

    // Everywhere else → Google Maps
    final googleMapsUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${place.latitude},${place.longitude}',
    );

    await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        initialCenter: const LatLng(37.5665, 126.9780),
        initialZoom: 12.5,
        onTap: (_, point) {
          onMapTap?.call(point);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.pinori.app',
        ),

        MarkerLayer(
          markers:
              [
                ...places.where((place) => selectedPlace?.id != place.id),
                ...places.where((place) => selectedPlace?.id == place.id),
              ].map((place) {
                final isSelected = selectedPlace?.id == place.id;
                final pinAsset = place.visited
                    ? 'assets/icons/pin_visited.png'
                    : 'assets/icons/pin_confirmed.png';

                return Marker(
                  point: LatLng(place.latitude, place.longitude),
                  width: isSelected ? 480 : 34,
                  height: isSelected ? 960 : 42,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      onPlaceTap?.call(place);
                    },
                    child: isSelected
                        ? Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Card grows out from the EXISTING pin
                              Positioned(
                                left: 234,
                                top: 477,
                                width: 240,
                                height: 480,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBE9),
                                    border: Border.all(
                                      color: const Color(0xFF280000),
                                      width: 4,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      18,
                                      22,
                                      18,
                                      18,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: double.infinity,
                                          child: Text(
                                            place.name,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Color(0xFF280000),
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 12),

                                        if (place.customImageBase64 != null &&
                                            place
                                                .customImageBase64!
                                                .isNotEmpty) ...[
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: SizedBox(
                                              width: double.infinity,
                                              height: 130,
                                              child: Image.memory(
                                                base64Decode(
                                                  place.customImageBase64!,
                                                ),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),

                                          const SizedBox(height: 16),
                                        ] else if (place.localImagePath !=
                                                null &&
                                            place
                                                .localImagePath!
                                                .isNotEmpty) ...[
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: SizedBox(
                                              width: double.infinity,
                                              height: 130,
                                              child: Image.network(
                                                place.localImagePath!,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),

                                          const SizedBox(height: 16),
                                        ] else
                                          const SizedBox(height: 20),

                                        Text(
                                          place.category,
                                          style: const TextStyle(
                                            color: Color(0xFF280000),
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),

                                        if (place.neighbourhood.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            place.neighbourhood,
                                            style: const TextStyle(
                                              color: Color(0xFF280000),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],

                                        if (place.nearestStation != null &&
                                            place
                                                .nearestStation!
                                                .isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            'Near ${place.nearestStation}',
                                            style: const TextStyle(
                                              color: Color(0xFF280000),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                        if (place.address != null &&
                                            place.address!.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            place.address!,
                                            style: const TextStyle(
                                              color: Color(0xFF280000),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 10),

                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.check_circle_outline,
                                              color: Color(0xFF588B8B),
                                              size: 18,
                                            ),

                                            const SizedBox(width: 6),

                                            const Expanded(
                                              child: Text(
                                                'Visited this place',
                                                style: TextStyle(
                                                  color: Color(0xFF280000),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),

                                            Transform.scale(
                                              scale: 0.8,
                                              child: Switch(
                                                value: place.visited,
                                                activeTrackColor: const Color(
                                                  0xFF588B8B,
                                                ),
                                                activeThumbColor: const Color(
                                                  0xFFFFFBE9,
                                                ),
                                                onChanged: (value) {
                                                  onVisitedChanged?.call(
                                                    place,
                                                    value,
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),

                                        if (place.notes != null &&
                                            place.notes!.isNotEmpty) ...[
                                          const SizedBox(height: 14),

                                          const Text(
                                            'Notes',
                                            style: TextStyle(
                                              color: Color(0xFF280000),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),

                                          const SizedBox(height: 4),

                                          Text(
                                            place.notes!,
                                            style: const TextStyle(
                                              color: Color(0xFF280000),
                                              fontSize: 12,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                        const Spacer(),

                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              _openDirections(place);
                                            },
                                            icon: const Icon(Icons.directions),
                                            label: const Text('Get directions'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFFB92D2D,
                                              ),
                                              foregroundColor: const Color(
                                                0xFFFFFBE9,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // SAME pin, SAME original position
                              Positioned(
                                left: 223,
                                top: 459,
                                width: 34,
                                height: 42,
                                child: Image.asset(
                                  pinAsset,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ],
                          )
                        : Image.asset(pinAsset, fit: BoxFit.contain),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }
}
