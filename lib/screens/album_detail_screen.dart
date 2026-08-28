import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:music_database_app/services/ticketmaster_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/music_data_models.dart';
import '../services/favorites_service.dart';
import '../services/spotify_service.dart';
import '../widgets/glass_container.dart';
import 'map_screen.dart';

class AlbumDetailScreen extends StatefulWidget {
  final Album album;
  final Artist artist;
  final String? heroTag;

  const AlbumDetailScreen({
    super.key,
    required this.album,
    required this.artist,
    this.heroTag,
  });

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  late List<Song> _tracks;
  bool _isLoadingTracks = false;

  @override
  void initState() {
    super.initState();
    _tracks = widget.album.tracks;
    if (_tracks.isEmpty) {
      _loadTracksFromSpotify();
    }
  }

  Future<void> _loadTracksFromSpotify() async {
    setState(() => _isLoadingTracks = true);
    final fetched = await SpotifyService.getAlbumTracks(widget.album.id);
    if (mounted) {
      setState(() {
        _tracks = fetched;
        _isLoadingTracks = false;
      });
    }
  }

  Future<String> _fetchWikipediaBio(String artistName) async {
    try {
      final formattedName = Uri.encodeComponent(
        artistName.replaceAll(' ', '_'),
      );
      final response = await http.get(
        Uri.parse(
          'https://en.wikipedia.org/api/rest_v1/page/summary/$formattedName',
        ),
        headers: {'User-Agent': 'MusicDatabaseApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final extract = data['extract'] as String?;
        if (extract != null && extract.isNotEmpty) {
          return extract;
        }
      }
    } catch (_) {}
    return widget.artist.biography.isNotEmpty
        ? widget.artist.biography
        : '${widget.artist.name} is a verified artist on Spotify.';
  }

  Future<List<Album>> _fetchFullDiscography() async {
    final albums = await SpotifyService.getArtistAlbums(
      widget.artist.id,
      artistName: widget.artist.name,
    );

    if (albums.isNotEmpty) {
      return albums;
    }

    return widget.artist.albums;
  }

  String _formatFollowers(int total) {
    if (total >= 1000000) {
      return '${(total / 1000000).toStringAsFixed(1)}M';
    } else if (total >= 1000) {
      return '${(total / 1000).toStringAsFixed(1)}K';
    }
    return total.toString();
  }

  Widget _buildCoverImage() {
    if (widget.album.coverUrl.startsWith('http')) {
      return Image.network(
        widget.album.coverUrl,
        width: 230,
        height: 230,
        fit: BoxFit.cover,
        cacheWidth: 600,
        cacheHeight: 600,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 230,
          height: 230,
          color: const Color(0xFF222222),
          child: const Icon(Icons.album, size: 64, color: Colors.grey),
        ),
      );
    } else {
      return Image.asset(
        widget.album.coverUrl,
        width: 230,
        height: 230,
        fit: BoxFit.cover,
        cacheWidth: 600,
        cacheHeight: 600,
      );
    }
  }

  Future<void> _launchSpotify(BuildContext context, String urlString) async {
    final Uri uri = Uri.parse(urlString);
    try {
      final bool nativeLaunched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!nativeLaunched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open Spotify')));
      }
    }
  }

  Future<void> _launchUrl(BuildContext context, String urlString) async {
    final Uri uri = Uri.parse(urlString);
    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open link')));
      }
    }
  }

  Future<void> _shareAlbum(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text:
            '${widget.album.title} by ${widget.artist.name} — ${widget.album.spotifyUrl}',
        subject: widget.album.title,
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      ),
    );
  }

  void _showArtistDetails(BuildContext context) {
    final String formattedName = Uri.encodeComponent(
      widget.artist.name.replaceAll(' ', '_'),
    );
    final String wikipediaUrl = 'https://en.wikipedia.org/wiki/$formattedName';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder<List<Album>>(
              future: _fetchFullDiscography(),
              builder: (context, discoSnapshot) {
                final bool isLoadingDiscography =
                    discoSnapshot.connectionState == ConnectionState.waiting;
                final List<Album> albums =
                    discoSnapshot.data ?? widget.artist.albums;

                final int albumCount = albums.length;
                final List<int> releaseYears =
                    albums
                        .map((a) => int.tryParse(a.releaseYear) ?? 0)
                        .where((y) => y > 1900)
                        .toList()
                      ..sort();
                final String activeSince = releaseYears.isNotEmpty
                    ? releaseYears.first.toString()
                    : widget.album.releaseYear;

                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: widget.album.coverUrl.startsWith('http')
                                ? Image.network(
                                    widget.album.coverUrl,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, e, st) => Container(
                                      width: 72,
                                      height: 72,
                                      color: Colors.grey[900],
                                      child: const Icon(Icons.person, size: 36),
                                    ),
                                  )
                                : Image.asset(
                                    widget.album.coverUrl,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.artist.name,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.3,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.verified,
                                      color: Color(0xFF1DB954),
                                      size: 20,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF1DB954,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF1DB954,
                                      ).withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Text(
                                    widget.artist.genre.toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF1DB954),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.album_rounded,
                                        size: 15,
                                        color: Color(0xFF1DB954),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'RELEASES',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    isLoadingDiscography
                                        ? '...'
                                        : '$albumCount Albums',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              height: 36,
                              width: 1,
                              color: Colors.white12,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_rounded,
                                        size: 14,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'ACTIVE SINCE',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    isLoadingDiscography ? '...' : activeSince,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 12),

                      const Text(
                        'About Artist',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<String>(
                        future: _fetchWikipediaBio(widget.artist.name),
                        builder: (context, bioSnapshot) {
                          if (bioSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF1DB954),
                                ),
                              ),
                            );
                          }
                          return Text(
                            bioSnapshot.data ?? widget.artist.biography,
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 13,
                              height: 1.5,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _launchUrl(context, wikipediaUrl),
                          icon: const FaIcon(
                            FontAwesomeIcons.wikipediaW,
                            size: 15,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Read on Wikipedia',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.04,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        'Discography on Spotify',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (isLoadingDiscography)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF1DB954),
                            ),
                          ),
                        )
                      else if (albums.isEmpty)
                        Text(
                          'No albums found.',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        )
                      else
                        Column(
                          children: albums.map((a) {
                            return InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AlbumDetailScreen(
                                      album: a,
                                      artist: widget.artist,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6.0,
                                  horizontal: 4.0,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.album_rounded,
                                      size: 16,
                                      color: Color(0xFF1DB954),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${a.title} (${a.releaseYear})',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 11,
                                      color: Colors.white24,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                      const SizedBox(height: 24),

                      const Text(
                        'Upcoming Concerts',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<List<ConcertLocation>>(
                        future: TicketmasterService.fetchUpcomingConcerts(
                          widget.artist.name,
                        ),
                        builder: (context, concertSnapshot) {
                          final bool isLoadingConcerts =
                              concertSnapshot.connectionState ==
                              ConnectionState.waiting;
                          final List<ConcertLocation> concerts =
                              (concertSnapshot.data != null &&
                                  concertSnapshot.data!.isNotEmpty)
                              ? concertSnapshot.data!
                              : widget.artist.upcomingConcerts;

                          if (isLoadingConcerts &&
                              widget.artist.upcomingConcerts.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF1DB954),
                                ),
                              ),
                            );
                          }

                          if (concerts.isEmpty) {
                            return Text(
                              'No upcoming concerts found.',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...concerts.map(
                                (c) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4.0,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        size: 16,
                                        color: Color(0xFFBB86FC),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${c.venueName} - ${c.city} (${c.date})',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MapScreen(
                                        initialArtistName: widget.artist.name,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.map,
                                  size: 16,
                                  color: Color(0xFF1DB954),
                                ),
                                label: const Text(
                                  'View on map',
                                  style: TextStyle(
                                    color: Color(0xFF1DB954),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveHeroTag = widget.heroTag ?? 'album_${widget.album.id}';

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 380,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFF121212),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () => _shareAlbum(context),
              ),
              ValueListenableBuilder<List<Album>>(
                valueListenable: FavoritesService.instance.favoriteAlbums,
                builder: (context, favorites, child) {
                  final isFav = FavoritesService.instance.isFavorite(
                    widget.album.id,
                  );
                  return IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? const Color(0xFF1DB954) : Colors.white,
                    ),
                    onPressed: () =>
                        FavoritesService.instance.toggleFavorite(widget.album),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF1DB954,
                          ).withValues(alpha: 0.35),
                          blurRadius: 90,
                          spreadRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 30,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.8),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Hero(
                          tag: effectiveHeroTag,
                          child: _buildCoverImage(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.album.title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),

                  InkWell(
                    onTap: () => _showArtistDetails(context),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person,
                            color: Color(0xFF1DB954),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.artist.name} • ${widget.album.releaseYear}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GlassContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.notes,
                              color: Color(0xFF1DB954),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Liner Notes',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.album.description,
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1DB954).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _launchSpotify(context, widget.album.spotifyUrl),
                      icon: const FaIcon(
                        FontAwesomeIcons.spotify,
                        color: Colors.black,
                        size: 22,
                      ),
                      label: const Text(
                        'Play on Spotify',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tracklist',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_tracks.length} tracks',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          if (_isLoadingTracks)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: Color(0xFF1DB954)),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final track = _tracks[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      leading: Text(
                        (index + 1).toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.grey[500],
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      title: Text(
                        track.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      trailing: Text(
                        track.duration,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }, childCount: _tracks.length),
              ),
            ),
        ],
      ),
    );
  }
}
