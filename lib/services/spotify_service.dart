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
  // NEWEST RELEASES (GET /v1/search?q=tag:new&type=album)
  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // NEWEST RELEASES (Aggregates multiple tag:new search queries in parallel)
  // ---------------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> getTrendingAlbums() async {
    final token = await _getAccessToken();
    if (token == null) return [];

    // Query multiple tag:new genre buckets to aggregate a full 40-60+ release feed
    final categories = [
      'tag:new',
      'tag:new pop',
      'tag:new hip-hop',
      'tag:new rock',
      'tag:new electronic',
      'tag:new indie',
      'tag:new rap',
      'tag:new dance',
    ];

    try {
      final responses = await Future.wait(
        categories.map((q) {
          final uri = Uri.https('api.spotify.com', '/v1/search', {
            'q': q,
            'type': 'album',
          });
          return http.get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );
        }),
      );

      final seenIds = <String>{};
      final seenTitles = <String>{};
      final List<Map<String, dynamic>> allAlbums = [];

      for (final response in responses) {
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final List items = data['albums']?['items'] ?? [];

          for (final item in items) {
            final String id = item['id'] ?? '';
            final String title = (item['name'] ?? '')
                .toString()
                .toLowerCase()
                .trim();

            if (id.isNotEmpty && seenIds.add(id) && seenTitles.add(title)) {
              final album = _parseAlbum(item);
              final artistList = item['artists'] as List? ?? [];
              final String artistName = artistList.isNotEmpty
                  ? artistList[0]['name']
                  : 'Unknown Artist';
              final String artistId = artistList.isNotEmpty
                  ? artistList[0]['id']
                  : '';

              final artist = Artist(
                id: artistId,
                name: artistName,
                genre: 'New Release',
                biography: '$artistName on Spotify.',
                wikipediaUrl:
                    'https://en.wikipedia.org/wiki/${Uri.encodeComponent(artistName.replaceAll(' ', '_'))}',
                albums: [album],
                upcomingConcerts: const [],
              );

              allAlbums.add({'album': album, 'artist': artist});
            }
          }
        }
      }

      if (allAlbums.isNotEmpty) {
        return allAlbums;
      }
    } catch (e) {
      debugPrint('[Spotify tag:new Aggregation Exception] $e');
    }

    return [];
  }

  // ---------------------------------------------------------------------------
  // UNIFIED CATALOG SEARCH (ARTISTS + ALBUMS)
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> searchCatalog(String query) async {
    final cleanQuery = query
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F\u00A0]'), ' ')
        .trim();

    if (cleanQuery.isEmpty) {
      return {
        'artists': <Map<String, dynamic>>[],
        'albums': <Map<String, dynamic>>[],
      };
    }

    final token = await _getAccessToken();
    if (token == null) {
      return {
        'artists': <Map<String, dynamic>>[],
        'albums': <Map<String, dynamic>>[],
      };
    }

    final uri = Uri.https('api.spotify.com', '/v1/search', {
      'q': cleanQuery,
      'type': 'album,artist',
    });

    try {
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final List rawArtists = data['artists']?['items'] ?? [];
        final List<Map<String, dynamic>>
        artists = rawArtists.map<Map<String, dynamic>>((item) {
          final images = item['images'] as List? ?? [];
          final photoUrl = images.isNotEmpty ? images[0]['url'] : '';
          final rawGenres = item['genres'] as List? ?? [];
          final genre = rawGenres.isNotEmpty
              ? rawGenres.first.toString().toUpperCase()
              : 'ARTIST';

          final artistModel = Artist(
            id: item['id'] ?? '',
            name: item['name'] ?? 'Unknown Artist',
            genre: genre,
            biography: '${item['name']} is on Spotify.',
            wikipediaUrl:
                'https://en.wikipedia.org/wiki/${Uri.encodeComponent((item['name'] ?? '').replaceAll(' ', '_'))}',
            albums: const [],
            upcomingConcerts: const [],
            imageUrl: photoUrl.isNotEmpty ? photoUrl : null,
          );

          return {
            'artist': artistModel,
            'photoUrl': photoUrl,
            'followers': item['followers']?['total'] ?? 0,
          };
        }).toList();

        final List rawAlbums = data['albums']?['items'] ?? [];
        final List<Map<String, dynamic>>
        albums = rawAlbums.map<Map<String, dynamic>>((item) {
          final album = _parseAlbum(item);
          final artistList = item['artists'] as List? ?? [];
          final artistName = artistList.isNotEmpty
              ? artistList[0]['name']
              : 'Unknown Artist';
          final artistId = artistList.isNotEmpty ? artistList[0]['id'] : '';

          final artist = Artist(
            id: artistId,
            name: artistName,
            genre: 'Music',
            biography: '$artistName on Spotify.',
            wikipediaUrl:
                'https://en.wikipedia.org/wiki/${Uri.encodeComponent(artistName.replaceAll(' ', '_'))}',
            albums: [album],
            upcomingConcerts: const [],
          );

          return {'album': album, 'artist': artist};
        }).toList();

        return {'artists': artists, 'albums': albums};
      }
    } catch (e) {
      debugPrint('[Spotify Search Catalog Exception] $e');
    }

    return {
      'artists': <Map<String, dynamic>>[],
      'albums': <Map<String, dynamic>>[],
    };
  }

  // ---------------------------------------------------------------------------
  // SEARCH ARTISTS (GET /v1/search?type=artist)
  // ---------------------------------------------------------------------------
  static Future<List<Artist>> searchArtists(String query) async {
    final cleanQuery = query
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F\u00A0]'), ' ')
        .trim();

    if (cleanQuery.isEmpty) return [];

    final token = await _getAccessToken();
    if (token == null) return [];

    final searchUri = Uri.https('api.spotify.com', '/v1/search', {
      'q': cleanQuery,
      'type': 'artist',
    });

    try {
      final response = await http.get(
        searchUri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['artists']?['items'] ?? [];
        return items.map<Artist>((item) => _parseArtist(item)).toList();
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

    final token = await _getAccessToken();
    if (token == null) return [];

    final searchUri = Uri.https('api.spotify.com', '/v1/search', {
      'q': cleanQuery,
      'type': 'album',
    });

    try {
      final response = await http.get(
        searchUri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['albums']?['items'] ?? [];

        return items.map<Map<String, dynamic>>((item) {
          final album = _parseAlbum(item);
          final artistList = item['artists'] as List? ?? [];
          final artistName = artistList.isNotEmpty
              ? artistList[0]['name']
              : 'Unknown Artist';
          final artistId = artistList.isNotEmpty ? artistList[0]['id'] : '';

          final artist = Artist(
            id: artistId,
            name: artistName,
            genre: 'Music',
            biography: '$artistName on Spotify.',
            wikipediaUrl:
                'https://en.wikipedia.org/wiki/${Uri.encodeComponent(artistName.replaceAll(' ', '_'))}',
            albums: [album],
            upcomingConcerts: const [],
          );

          return {'album': album, 'artist': artist};
        }).toList();
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

    final token = await _getAccessToken();
    if (token == null) return null;

    final artistUri = Uri.https('api.spotify.com', '/v1/artists/$cleanId');

    try {
      final response = await http.get(
        artistUri,
        headers: {'Authorization': 'Bearer $token'},
      );

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
  // ---------------------------------------------------------------------------
  // GET AN ARTIST'S ALBUMS (GET /v1/artists/{id}/albums)
  // ---------------------------------------------------------------------------
  static Future<List<Album>> getArtistAlbums(
    String artistId, {
    String? artistName,
  }) async {
    final token = await _getAccessToken();
    if (token == null) return [];

    String resolvedId = artistId
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F\u00A0]'), '')
        .trim();

    // 1. Resolve true Spotify Artist ID if artistId is from mock data
    if (resolvedId.length < 15 && artistName != null && artistName.isNotEmpty) {
      try {
        final cleanName = artistName
            .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F\u00A0]'), ' ')
            .trim();
        final searchUri = Uri.https('api.spotify.com', '/v1/search', {
          'q': cleanName,
          'type': 'artist',
          'limit': '1',
        });
        final searchRes = await http.get(
          searchUri,
          headers: {'Authorization': 'Bearer $token'},
        );
        if (searchRes.statusCode == 200) {
          final data = jsonDecode(searchRes.body);
          final items = data['artists']?['items'] as List?;
          if (items != null && items.isNotEmpty) {
            resolvedId = items.first['id'];
          }
        }
      } catch (e) {
        debugPrint('[Spotify Discography] ID resolution error: $e');
      }
    }

    // 2. Fetch full catalog across multiple pages (up to 100 releases)
    if (resolvedId.length >= 15) {
      try {
        final List<dynamic> allRawItems = [];

        // Page 1 (first 50 items: studio albums & singles)
        final uriPage1 = Uri.https(
          'api.spotify.com',
          '/v1/artists/$resolvedId/albums',
          {'include_groups': 'album,single', 'limit': '50', 'offset': '0'},
        );

        final res1 = await http.get(
          uriPage1,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (res1.statusCode == 200) {
          final data1 = jsonDecode(res1.body);
          final List items1 = data1['items'] ?? [];
          allRawItems.addAll(items1);

          final int total = data1['total'] ?? items1.length;

          // Page 2 (next 50 items if the artist has > 50 releases)
          if (total > 50) {
            final uriPage2 = Uri.https(
              'api.spotify.com',
              '/v1/artists/$resolvedId/albums',
              {'include_groups': 'album,single', 'limit': '50', 'offset': '50'},
            );
            final res2 = await http.get(
              uriPage2,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            );
            if (res2.statusCode == 200) {
              final data2 = jsonDecode(res2.body);
              final List items2 = data2['items'] ?? [];
              allRawItems.addAll(items2);
            }
          }
        } else {
          // Fallback without group filters if region restricted
          final fallbackUri = Uri.https(
            'api.spotify.com',
            '/v1/artists/$resolvedId/albums',
          );
          final fallbackRes = await http.get(
            fallbackUri,
            headers: {'Authorization': 'Bearer $token'},
          );
          if (fallbackRes.statusCode == 200) {
            final data = jsonDecode(fallbackRes.body);
            allRawItems.addAll(data['items'] ?? []);
          }
        }

        if (allRawItems.isNotEmpty) {
          final parsed = allRawItems
              .map<Album>((item) => _parseAlbum(item))
              .toList();

          // Deduplicate duplicate Deluxe/Remaster editions of the same album
          final seenTitles = <String>{};
          final List<Album> uniqueAlbums = [];

          for (final album in parsed) {
            final normalized = album.title
                .toLowerCase()
                .split('(')
                .first
                .split('[')
                .first
                .replaceAll(
                  RegExp(
                    r'\b(deluxe|remastered|expanded|edition|version|anniversary)\b',
                  ),
                  '',
                )
                .trim();

            final key = normalized.isNotEmpty
                ? normalized
                : album.title.toLowerCase().trim();
            if (seenTitles.add(key)) {
              uniqueAlbums.add(album);
            }
          }

          // Sort descending by release year (newest first)
          uniqueAlbums.sort((a, b) {
            final yearA = int.tryParse(a.releaseYear) ?? 0;
            final yearB = int.tryParse(b.releaseYear) ?? 0;
            return yearB.compareTo(yearA);
          });

          return uniqueAlbums;
        }
      } catch (e) {
        debugPrint('[Spotify Discography Exception] $e');
      }
    }

    // 3. Fallback: Search all albums by artist name
    if (artistName != null && artistName.isNotEmpty) {
      try {
        final cleanName = artistName
            .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F\u00A0]'), ' ')
            .trim();
        final searchUri = Uri.https('api.spotify.com', '/v1/search', {
          'q': 'artist:$cleanName',
          'type': 'album',
          'limit': '50',
        });
        final response = await http.get(
          searchUri,
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final List items = data['albums']?['items'] ?? [];
          final parsed = items.map<Album>((item) => _parseAlbum(item)).toList();
          final seen = <String>{};
          final unique = parsed.where((a) {
            final norm = a.title
                .toLowerCase()
                .split('(')
                .first
                .split('[')
                .first
                .trim();
            return norm.isNotEmpty && seen.add(norm);
          }).toList();

          unique.sort((a, b) {
            final yearA = int.tryParse(a.releaseYear) ?? 0;
            final yearB = int.tryParse(b.releaseYear) ?? 0;
            return yearB.compareTo(yearA);
          });

          return unique;
        }
      } catch (e) {
        debugPrint('[Spotify Discography Search Fallback Exception] $e');
      }
    }

    return [];
  }

  // ---------------------------------------------------------------------------
  // GET AN ARTIST'S PROFILE (GET /v1/artists/{id})
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>?> getArtistProfile(
    String artistId,
    String artistName,
  ) async {
    final token = await _getAccessToken();
    if (token == null) return null;

    final cleanId = artistId
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F\u00A0]'), '')
        .trim();

    if (cleanId.length > 15) {
      final idUri = Uri.https('api.spotify.com', '/v1/artists/$cleanId');
      try {
        final response = await http.get(
          idUri,
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        }
      } catch (_) {}
    }

    final cleanName = artistName
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F\u00A0]'), ' ')
        .trim();
    if (cleanName.isNotEmpty) {
      final searchUri = Uri.https('api.spotify.com', '/v1/search', {
        'q': cleanName,
        'type': 'artist',
      });

      try {
        final response = await http.get(
          searchUri,
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
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // GET AN ALBUM'S TRACKS (GET /v1/albums/{id}/tracks)
  // ---------------------------------------------------------------------------
  static Future<List<Song>> getAlbumTracks(String albumId) async {
    final cleanId = albumId
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F\u00A0]'), '')
        .trim();

    if (cleanId.isEmpty) return [];

    final token = await _getAccessToken();
    if (token == null) return [];

    final tracksUri = Uri.https(
      'api.spotify.com',
      '/v1/albums/$cleanId/tracks',
    );

    try {
      final response = await http.get(
        tracksUri,
        headers: {'Authorization': 'Bearer $token'},
      );

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
}
