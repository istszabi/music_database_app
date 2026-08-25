import 'dart:async';
import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/music_data_models.dart';
import '../services/spotify_service.dart';
import '../widgets/album_card.dart';
import 'album_detail_screen.dart';
import 'artist_profile_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;

  // True while showing search results (artists + albums sections).
  // False while showing the trending/mock browse grid (albums only).
  bool _isSearching = false;

  List<Map<String, dynamic>> _displayAlbums = [];
  List<Artist> _displayArtists = [];

  @override
  void initState() {
    super.initState();
    _loadTrendingAlbums();
  }

  Future<void> _loadTrendingAlbums() async {
    setState(() {
      _isLoading = true;
      _isSearching = false;
      _displayArtists = [];
    });

    debugPrint('[CatalogScreen] Fetching trending albums via Spotify...');
    final trending = await SpotifyService.getTrendingAlbums(filter: 'tag:new');

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (trending.isNotEmpty) {
        _displayAlbums = trending;
        debugPrint(
          '[CatalogScreen] Loaded ${trending.length} live trending albums.',
        );
      } else {
        debugPrint(
          '[CatalogScreen] Trending empty, falling back to mock dataset.',
        );
        _displayAlbums = mockArtists.expand((artist) {
          return artist.albums.map(
            (album) => {'artist': artist, 'album': album},
          );
        }).toList();
      }
    });
  }

  void _onSearchChanged(String query) {
    debugPrint('[CatalogScreen] Search input changed: "$query"');
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final trimmed = query.trim();
      if (trimmed.isEmpty) {
        debugPrint(
          '[CatalogScreen] Search query empty, loading trending feed.',
        );
        _loadTrendingAlbums();
        return;
      }

      setState(() {
        _isLoading = true;
        _isSearching = true;
      });

      debugPrint(
        '[CatalogScreen] Querying Spotify for "$trimmed" (artists + albums)...',
      );

      // Fetch both in parallel — one slow/failed request shouldn't block the other.
      final results = await Future.wait([
        SpotifyService.searchArtists(trimmed),
        SpotifyService.searchAlbums(trimmed),
      ]);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _displayArtists = results[0] as List<Artist>;
        _displayAlbums = results[1] as List<Map<String, dynamic>>;
        debugPrint(
          '[CatalogScreen] Search results: ${_displayArtists.length} artists, '
          '${_displayAlbums.length} albums.',
        );
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _openAlbum(
    BuildContext context,
    Artist artist,
    Album album,
    String heroTag,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AlbumDetailScreen(album: album, artist: artist, heroTag: heroTag),
      ),
    );
  }

  /// Opens the artist's full profile screen (bio, discography, concerts).
  void _onArtistTapped(Artist artist) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ArtistProfileScreen(artist: artist)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Discography',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
      ),
      body: Column(
        children: [
          // Live Spotify Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search Spotify albums, artists...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1DB954)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _loadTrendingAlbums();
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF181818),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          if (_isLoading)
            const LinearProgressIndicator(
              color: Color(0xFF1DB954),
              backgroundColor: Colors.transparent,
            ),

          Expanded(
            child:
                (_displayAlbums.isEmpty &&
                    _displayArtists.isEmpty &&
                    !_isLoading)
                ? Center(
                    child: Text(
                      'No results found',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                : CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // Artists section — only shown during search, and
                      // only when there are artist results to show.
                      if (_isSearching && _displayArtists.isNotEmpty) ...[
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Text(
                              'Artists',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 108,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: _displayArtists.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final artist = _displayArtists[index];
                                return GestureDetector(
                                  onTap: () => _onArtistTapped(artist),
                                  child: SizedBox(
                                    width: 76,
                                    child: Column(
                                      children: [
                                        CircleAvatar(
                                          radius: 32,
                                          backgroundColor: const Color(
                                            0xFF1DB954,
                                          ),
                                          backgroundImage:
                                              artist.imageUrl != null
                                              ? NetworkImage(artist.imageUrl!)
                                              : null,
                                          child: artist.imageUrl == null
                                              ? Text(
                                                  artist.name.isNotEmpty
                                                      ? artist.name[0]
                                                            .toUpperCase()
                                                      : '?',
                                                  style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          artist.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],

                      // Albums section header
                      if (_displayAlbums.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              _isSearching ? 'Albums' : 'Trending',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                      // Albums grid
                      if (_displayAlbums.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.75,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final item = _displayAlbums[index];
                              final Artist artist = item['artist'];
                              final Album album = item['album'];
                              final heroTag = 'catalog_${album.id}_$index';

                              return GestureDetector(
                                onTap: () {
                                  debugPrint(
                                    '[CatalogScreen] Tapped album: "${album.title}" by "${artist.name}"',
                                  );
                                  _openAlbum(context, artist, album, heroTag);
                                },
                                child: AlbumCard(
                                  heroTag: heroTag,
                                  title: album.title,
                                  artist: artist.name,
                                  coverUrl: album.coverUrl,
                                ),
                              );
                            }, childCount: _displayAlbums.length),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
