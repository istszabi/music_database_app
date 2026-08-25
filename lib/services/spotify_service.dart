import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/music_data_models.dart';

class SpotifyService {
  static const String clientId = '98b06104ffda45d394a923135c48b372';
  static const String clientSecret = 'be2214625c6040db9ecfba9f8e8a73e2';

  static String? _accessToken;
  static DateTime? _tokenExpiry;

  // ---------------------------------------------------------------------------
  // AUTHENTICATION (Client Credentials Flow)
  // ---------------------------------------------------------------------------
  static Future<String?> _getAccessToken({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken;
    }

    debugPrint('[Spotify Auth] Requesting fresh access token from Spotify...');
    try {
      final String basicAuth = base64Encode(
        utf8.encode('${clientId.trim()}:${clientSecret.trim()}'),
      );

      final response = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {
          'Authorization': 'Basic $basicAuth',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'grant_type': 'client_credentials'},
      );

      debugPrint('[Spotify Auth] Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token']?.toString().trim();
        final int expiresIn = data['expires_in'] ?? 3600;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
        return _accessToken;
      } else {
        debugPrint('[Spotify Auth Error] ${response.body}');
        _accessToken = null;
        _tokenExpiry = null;
      }
    } catch (e) {
      debugPrint('[Spotify Auth Exception] $e');
      _accessToken = null;
      _tokenExpiry = null;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // TRENDING / NEW RELEASES SEED
  // ---------------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> getTrendingAlbums({
    String filter = 'tag:new',
  }) async {
    return searchAlbums(filter);
  }

  // ---------------------------------------------------------------------------
  // SEARCH ARTISTS (GET /v1/search?type=artist)
  // ---------------------------------------------------------------------------
  static Future<List<Artist>> searchArtists(String query) async {
    final cleanQuery = query
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F\u00A0]'), ' ')
        .trim();

    if (cleanQuery.isEmpty) return [];

    String? token = await _getAccessToken();
    if (token == null) return [];

    final searchUri = Uri.https('api.spotify.com', '/v1/search', {
      'q': cleanQuery,
      'type': 'artist',
      'limit': '10',
    });

    try {
      var response = await http.get(
        searchUri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 401) {
        token = await _getAccessToken(forceRefresh: true);
        if (token != null) {
          response = await http.get(
            searchUri,
            headers: {'Authorization': 'Bearer $token'},
          );
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['artists']?['items'] ?? [];
        return items.map<Artist>((item) => _parseArtist(item)).toList();
      } else {
        debugPrint('[Spotify Artist Search Error] ${response.body}');
      }
    } catch (e) {
      debugPrint('[Spotify Artist Search Exception] $e');
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // SEARCH ALBUMS (GET /v1/search?type=album)
  // ---------------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> searchAlbums(String query) async {
    final cleanQuery = query
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F\u00A0]'), ' ')
        .trim();

    if (cleanQuery.isEmpty) return [];

    String? token = await _getAccessToken();
    if (token == null) {
      debugPrint('[Spotify API Error] Could not retrieve access token');
      return [];
    }

    final searchUri = Uri.https('api.spotify.com', '/v1/search', {
      'q': cleanQuery,
      'type': 'album',
    });

    try {
      var response = await http.get(
        searchUri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 401) {
        token = await _getAccessToken(forceRefresh: true);
        if (token != null) {
          response = await http.get(
            searchUri,
            headers: {'Authorization': 'Bearer $token'},
          );
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['albums']?['items'] ?? [];

        return items.map<Map<String, dynamic>>((item) {
          final album = _parseAlbum(item);
          final artistName = (item['artists'] as List).isNotEmpty
              ? item['artists'][0]['name']
              : 'Unknown Artist';
          final artistId = (item['artists'] as List).isNotEmpty
              ? item['artists'][0]['id']
              : '';

          final artistImages = (item['artists'] as List).isNotEmpty
              ? item['artists'][0]['images'] as List?
              : null;
          final artistImageUrl =
              (artistImages != null && artistImages.isNotEmpty)
              ? artistImages[0]['url'] as String?
              : null;

          final artist = Artist(
            id: artistId,
            name: artistName,
            genre: 'Music',
            biography: '$artistName on Spotify.',
            wikipediaUrl:
                'https://en.wikipedia.org/wiki/${Uri.encodeComponent(artistName.replaceAll(' ', '_'))}',
            albums: [album],
            upcomingConcerts: const [],
            imageUrl: artistImageUrl,
          );

          return {'album': album, 'artist': artist};
        }).toList();
      } else {
        debugPrint('[Spotify Search Error Body] ${response.body}');
      }
    } catch (e) {
      debugPrint('[Spotify Search Exception] $e');
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // GET AN ARTIST (GET /v1/artists/{id})
  // ---------------------------------------------------------------------------
  static Future<Artist?> getArtist(String artistId) async {
    final cleanId = artistId
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F\u00A0]'), '')
        .trim();

    if (cleanId.isEmpty) return null;

    String? token = await _getAccessToken();
    if (token == null) return null;

    final artistUri = Uri.https('api.spotify.com', '/v1/artists/$cleanId');

    try {
      var response = await http.get(
        artistUri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 401) {
        token = await _getAccessToken(forceRefresh: true);
        if (token != null) {
          response = await http.get(
            artistUri,
            headers: {'Authorization': 'Bearer $token'},
          );
        }
      }

      if (response.statusCode == 200) {
        final item = jsonDecode(response.body);
        return _parseArtist(item);
      }
    } catch (e) {
      debugPrint('[Spotify Artist Exception] $e');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // GET AN ARTIST'S ALBUMS (GET /v1/artists/{id}/albums)
  // ---------------------------------------------------------------------------
  static Future<List<Album>> getArtistAlbums(
    String artistId, {
    String? artistName,
  }) async {
    debugPrint(
      '\n--- [Spotify getArtistAlbums] artistId="$artistId", artistName="$artistName" ---',
    );

    final token = await _getAccessToken();
    if (token == null) {
      debugPrint('[Spotify Discography] ❌ No access token — returning []');
      return [];
    }

    String resolvedId = artistId.trim();
    debugPrint(
      '[Spotify Discography] Initial id="$resolvedId" (length=${resolvedId.length})',
    );

    // 1. Resolve true Spotify Artist ID if artistId is from mock data
    if (resolvedId.length < 15 && artistName != null && artistName.isNotEmpty) {
      debugPrint(
        '[Spotify Discography] id looks like a mock id, resolving via name search...',
      );
      try {
        final searchUri = Uri.parse(
          'https://api.spotify.com/v1/search?q=${Uri.encodeComponent(artistName)}&type=artist&limit=1',
        );
        final searchRes = await http.get(
          searchUri,
          headers: {'Authorization': 'Bearer $token'},
        );
        if (searchRes.statusCode == 200) {
          final data = jsonDecode(searchRes.body);
          final items = data['artists']?['items'] as List?;
          if (items != null && items.isNotEmpty) {
            resolvedId = items.first['id'];
            debugPrint(
              '[Spotify Discography] Resolved id="$resolvedId" via name search',
            );
          } else {
            debugPrint(
              '[Spotify Discography] Name search returned 0 artists for "$artistName"',
            );
          }
        } else {
          debugPrint(
            '[Spotify Discography] Name search HTTP ${searchRes.statusCode}: ${searchRes.body}',
          );
        }
      } catch (e) {
        debugPrint('[Spotify Discography] Name search exception: $e');
      }
    }

    // 2. Query official artist albums
    if (resolvedId.length >= 15) {
      try {
        final uri = Uri.parse(
          'https://api.spotify.com/v1/artists/$resolvedId/albums'
          '?include_groups=album,single&limit=20',
        );
        debugPrint('[Spotify Discography] Requesting: $uri');

        final response = await http.get(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        debugPrint(
          '[Spotify Discography] Response status: ${response.statusCode}',
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final List items = data['items'] ?? [];
          final total = data['total'];
          debugPrint(
            '[Spotify Discography] Raw items returned: ${items.length} '
            '(API reports total=$total available)',
          );

          if (items.isNotEmpty) {
            final parsed = items
                .map<Album>((item) => _parseAlbum(item))
                .toList();

            final seen = <String>{};
            final List<Album> unique = [];
            for (final a in parsed) {
              final cleanTitle = a.title
                  .toLowerCase()
                  .split('(')
                  .first
                  .split('[')
                  .first
                  .replaceAll(
                    RegExp(r'\b(deluxe|remastered|edition|version)\b'),
                    '',
                  )
                  .trim();
              if (cleanTitle.isNotEmpty && seen.add(cleanTitle)) {
                unique.add(a);
              } else {
                debugPrint(
                  '[Spotify Discography] Deduped out: "${a.title}" '
                  '(normalized to "$cleanTitle", already seen)',
                );
              }
            }
            debugPrint(
              '[Spotify Discography] ✅ After dedup: ${unique.length} unique albums '
              '(started from ${parsed.length} raw items)',
            );
            return unique;
          } else {
            debugPrint(
              '[Spotify Discography] items array was empty despite 200 response',
            );
          }
        } else {
          debugPrint('[Spotify Discography] Non-200 body: ${response.body}');
        }
      } catch (e) {
        debugPrint('[Spotify Discography Exception] $e');
      }
    } else {
      debugPrint(
        '[Spotify Discography] ❌ Could not resolve a real Spotify id '
        '(still "$resolvedId", length ${resolvedId.length}) — skipping direct query.',
      );
    }

    // 3. Fallback: Search albums by artist name
    if (artistName != null && artistName.isNotEmpty) {
      debugPrint(
        '[Spotify Discography] Falling back to album search by name...',
      );
      try {
        final searchUri = Uri.parse(
          'https://api.spotify.com/v1/search?q=artist:${Uri.encodeComponent(artistName)}&type=album&limit=20',
        );
        final response = await http.get(
          searchUri,
          headers: {'Authorization': 'Bearer $token'},
        );
        debugPrint(
          '[Spotify Discography] Fallback search status: ${response.statusCode}',
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final List items = data['albums']?['items'] ?? [];
          debugPrint(
            '[Spotify Discography] Fallback raw items: ${items.length}',
          );
          final parsed = items.map<Album>((item) => _parseAlbum(item)).toList();
          final seen = <String>{};
          final result = parsed
              .where((a) => seen.add(a.title.toLowerCase().trim()))
              .toList();
          debugPrint(
            '[Spotify Discography] Fallback after dedup: ${result.length}',
          );
          return result;
        }
      } catch (e) {
        debugPrint('[Spotify Discography] Fallback exception: $e');
      }
    }

    debugPrint('[Spotify Discography] ❌ All paths exhausted, returning []');
    return [];
  }

  // ---------------------------------------------------------------------------
  // GET AN ALBUM'S TRACKS (GET /v1/albums/{id}/tracks)
  // ---------------------------------------------------------------------------
  static Future<List<Song>> getAlbumTracks(String albumId) async {
    final cleanId = albumId
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F\u00A0]'), '')
        .trim();

    if (cleanId.isEmpty) return [];

    String? token = await _getAccessToken();
    if (token == null) return [];

    final tracksUri = Uri.https(
      'api.spotify.com',
      '/v1/albums/$cleanId/tracks',
    );

    try {
      var response = await http.get(
        tracksUri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 401) {
        token = await _getAccessToken(forceRefresh: true);
        if (token != null) {
          response = await http.get(
            tracksUri,
            headers: {'Authorization': 'Bearer $token'},
          );
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['items'] ?? [];
        return items.map<Song>((t) => _parseSong(t)).toList();
      }
    } catch (e) {
      debugPrint('[Spotify Tracks Exception] $e');
    }
    return [];
  }

  static Future<List<Song>> fetchAlbumTracks(String albumId) =>
      getAlbumTracks(albumId);

  // ---------------------------------------------------------------------------
  // PARSER HELPERS
  // ---------------------------------------------------------------------------
  static Album _parseAlbum(Map<String, dynamic> json) {
    final images = json['images'] as List? ?? [];
    final coverUrl = images.isNotEmpty ? images[0]['url'] : '';

    final releaseDate = json['release_date'] ?? '';
    final releaseYear = releaseDate.isNotEmpty
        ? releaseDate.split('-').first
        : 'N/A';

    List<Song> parsedTracks = [];
    if (json['tracks'] != null && json['tracks']['items'] != null) {
      parsedTracks = (json['tracks']['items'] as List)
          .map<Song>((t) => _parseSong(t))
          .toList();
    }

    final label = json['label'] != null ? 'Label: ${json['label']}. ' : '';
    final totalTracks = json['total_tracks'] != null
        ? '${json['total_tracks']} tracks.'
        : '';

    return Album(
      id: json['id'] ?? '',
      title: json['name'] ?? '',
      releaseYear: releaseYear,
      coverUrl: coverUrl,
      description:
          '$label$totalTracks Official Spotify release. Tap "Play on Spotify" to stream.',
      spotifyUrl: json['external_urls']?['spotify'] ?? '',
      tracks: parsedTracks,
    );
  }

  static Artist _parseArtist(Map<String, dynamic> json) {
    final name = json['name'] ?? 'Unknown Artist';
    final genresList = json['genres'] as List? ?? [];
    final genre = genresList.isNotEmpty
        ? genresList.take(2).map((g) => g.toString().toUpperCase()).join(' / ')
        : 'MUSIC';

    final followers = json['followers']?['total'];
    final followersText = followers != null
        ? ' (${followers.toString()} followers on Spotify)'
        : '';

    final images = json['images'] as List? ?? [];
    final imageUrl = images.isNotEmpty ? images[0]['url'] as String? : null;

    return Artist(
      id: json['id'] ?? '',
      name: name,
      genre: genre,
      biography: '$name is a verified artist on Spotify$followersText.',
      wikipediaUrl:
          'https://en.wikipedia.org/wiki/${Uri.encodeComponent(name.replaceAll(' ', '_'))}',
      albums: const [],
      upcomingConcerts: const [],
      imageUrl: imageUrl,
    );
  }

  static Song _parseSong(Map<String, dynamic> json) {
    final int durationMs = json['duration_ms'] ?? 0;
    final int minutes = (durationMs / 60000).floor();
    final int seconds = ((durationMs % 60000) / 1000).floor();
    final formattedDuration = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Song(title: json['name'] ?? 'Untitled', duration: formattedDuration);
  }

  static Future<Map<String, dynamic>?> getArtistProfile(
    String artistId,
    String artistName,
  ) async {
    final token = await _getAccessToken();
    if (token == null) return null;

    if (artistId.length > 15) {
      final idUrl = 'https://api.spotify.com/v1/artists/$artistId';
      try {
        final response = await http.get(
          Uri.parse(idUrl),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        }
      } catch (_) {}
    }

    final searchUrl =
        'https://api.spotify.com/v1/search?q=${Uri.encodeComponent(artistName)}&type=artist&limit=1';

    try {
      final response = await http.get(
        Uri.parse(searchUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['artists']?['items'] as List?;
        if (items != null && items.isNotEmpty) {
          return items.first as Map<String, dynamic>;
        }
      }
    } catch (_) {}

    return null;
  }
}
