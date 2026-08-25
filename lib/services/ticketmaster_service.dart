import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/music_data_models.dart';

/// Wraps calls to the Ticketmaster Discovery API.
///
/// Pass the API key in via --dart-define so it never ends up hardcoded
/// in source (and therefore never in your git history):
///   flutter run --dart-define=TICKETMASTER_API_KEY=your_key_here
class TicketmasterService {
  static const String _apiKey = String.fromEnvironment('TICKETMASTER_API_KEY');

  static const String _baseUrl =
      'https://app.ticketmaster.com/discovery/v2/events.json';

  /// Fetches upcoming events for [artistName] and maps them to
  /// [ConcertLocation]s. Returns an empty list (never throws) if the
  /// request fails, the key is missing, or there are no results —
  /// callers can fall back to mock data on an empty list.
  static Future<List<ConcertLocation>> fetchUpcomingConcerts(
    String artistName,
  ) async {
    debugPrint('\n--- [Ticketmaster] fetchUpcomingConcerts("$artistName") ---');

    if (_apiKey.isEmpty) {
      debugPrint(
        '[Ticketmaster] ❌ _apiKey is EMPTY. This means '
        'TICKETMASTER_API_KEY was not passed via --dart-define at launch '
        '(check your launch.json "args", or your run command). '
        'Every call will short-circuit to [] until this is fixed.',
      );
      return [];
    } else {
      debugPrint(
        '[Ticketmaster] ✅ API key loaded (${_apiKey.length} chars, '
        'starts with "${_apiKey.substring(0, _apiKey.length >= 4 ? 4 : _apiKey.length)}...")',
      );
    }

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'apikey': _apiKey,
        'keyword': artistName,
        'classificationName': 'music',
        'sort': 'date,asc',
      },
    );

    debugPrint('[Ticketmaster] Request URL: $uri');

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      debugPrint('[Ticketmaster] Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('[Ticketmaster] ❌ Non-200 response body:');
        debugPrint(response.body);
        return [];
      }

      final Map<String, dynamic> body = jsonDecode(response.body);

      // Ticketmaster's own reported total, regardless of what _embedded
      // contains — useful to confirm whether the API found anything at
      // all vs. our parsing dropping valid results.
      final totalElements = body['page']?['totalElements'];
      debugPrint('[Ticketmaster] page.totalElements: $totalElements');

      final List<dynamic>? events = body['_embedded']?['events'];

      if (events == null || events.isEmpty) {
        debugPrint(
          '[Ticketmaster] ⚠️ No "_embedded.events" in response — '
          'Ticketmaster found zero matching events for "$artistName". '
          'This is a real "no results" from their side, not a bug, '
          'unless totalElements above is > 0 (which would mean something '
          'else is wrong).',
        );
        return [];
      }

      debugPrint('[Ticketmaster] Raw events returned: ${events.length}');

      final List<ConcertLocation> results = [];
      int dropped = 0;

      for (final event in events) {
        final concert = _tryParseEvent(event);
        if (concert != null) {
          results.add(concert);
        } else {
          dropped++;
          debugPrint(
            '[Ticketmaster] ⚠️ Dropped event "${event['name']}" — '
            'missing venue/location/date fields (see _tryParseEvent debug above).',
          );
        }
      }

      debugPrint(
        '[Ticketmaster] ✅ Parsed ${results.length} concerts '
        '($dropped dropped due to missing fields) for "$artistName".',
      );

      return results;
    } catch (e, stack) {
      debugPrint('[Ticketmaster] ❌ Exception during fetch/parse: $e');
      debugPrint(stack.toString());
      return [];
    }
  }

  /// Returns null instead of throwing if any expected field is missing —
  /// the Discovery API doesn't guarantee _embedded/venues/location on
  /// every event (e.g. TBD venues, placeholder test events).
  static ConcertLocation? _tryParseEvent(Map<String, dynamic> event) {
    try {
      final List<dynamic>? venues = event['_embedded']?['venues'];
      if (venues == null || venues.isEmpty) {
        debugPrint(
          '[Ticketmaster]   -> "${event['name']}": no _embedded.venues',
        );
        return null;
      }
      final Map<String, dynamic> venue = venues[0];

      final String? venueName = venue['name'];
      final String? cityName = venue['city']?['name'];
      final dynamic lat = venue['location']?['latitude'];
      final dynamic lng = venue['location']?['longitude'];
      final String? localDate = event['dates']?['start']?['localDate'];

      if (venueName == null ||
          cityName == null ||
          lat == null ||
          lng == null ||
          localDate == null) {
        debugPrint(
          '[Ticketmaster]   -> "${event['name']}": missing field(s) — '
          'venueName=$venueName, city=$cityName, lat=$lat, lng=$lng, date=$localDate',
        );
        return null;
      }

      final double? latitude = double.tryParse(lat.toString());
      final double? longitude = double.tryParse(lng.toString());
      if (latitude == null || longitude == null) {
        debugPrint(
          '[Ticketmaster]   -> "${event['name']}": lat/lng not parseable '
          '(lat="$lat", lng="$lng")',
        );
        return null;
      }

      return ConcertLocation(
        venueName: venueName,
        city: cityName,
        latitude: latitude,
        longitude: longitude,
        date: localDate,
      );
    } catch (e) {
      debugPrint('[Ticketmaster]   -> "${event['name']}": parse exception $e');
      return null;
    }
  }
}
