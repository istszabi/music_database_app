import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/music_data_models.dart';
import '../services/spotify_service.dart';
import '../services/ticketmaster_service.dart';
import '../widgets/album_card.dart';
import 'album_detail_screen.dart';
import 'map_screen.dart';

class ArtistProfileScreen extends StatefulWidget {
  final Artist artist;

  const ArtistProfileScreen({super.key, required this.artist});

  @override
  State<ArtistProfileScreen> createState() => _ArtistProfileScreenState();
}

class _ArtistProfileScreenState extends State<ArtistProfileScreen> {
  late Future<_ArtistProfileData> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<_ArtistProfileData> _loadProfile() async {
    // Search results carry an id/name/genre but no bio detail or albums —
    // fill those in with real calls, and fall back to what we already
    // have if any individual call comes back empty.
    final results = await Future.wait([
      SpotifyService.getArtistProfile(widget.artist.id, widget.artist.name),
      SpotifyService.getArtistAlbums(
        widget.artist.id,
        artistName: widget.artist.name,
      ),
      TicketmasterService.fetchUpcomingConcerts(widget.artist.name),
    ]);

    final profileJson = results[0] as Map<String, dynamic>?;
    final albums = results[1] as List<Album>;
    final concerts = results[2] as List<ConcertLocation>;

    String genre = widget.artist.genre;
    String biography = widget.artist.biography;
    String? imageUrl = widget.artist.imageUrl;

    if (profileJson != null) {
      final genresList = profileJson['genres'] as List? ?? [];
      if (genresList.isNotEmpty) {
        genre = genresList
            .take(2)
            .map((g) => g.toString().toUpperCase())
            .join(' / ');
      }
      final followers = profileJson['followers']?['total'];
      final followersText = followers != null
          ? ' ($followers followers on Spotify)'
          : '';
      biography =
          '${profileJson['name'] ?? widget.artist.name} '
          'is a verified artist on Spotify$followersText.';

      if (imageUrl == null) {
        final images = profileJson['images'] as List? ?? [];
        if (images.isNotEmpty) {
          imageUrl = images[0]['url'] as String?;
        }
      }
    }

    return _ArtistProfileData(
      genre: genre,
      biography: biography,
      albums: albums.isNotEmpty ? albums : widget.artist.albums,
      concerts: concerts.isNotEmpty ? concerts : widget.artist.upcomingConcerts,
      imageUrl: imageUrl,
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open link')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: Text(widget.artist.name),
      ),
      body: FutureBuilder<_ArtistProfileData>(
        future: _profileFuture,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final data = snapshot.data;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: const Color(0xFF1DB954),
                      backgroundImage:
                          (data?.imageUrl ?? widget.artist.imageUrl) != null
                          ? NetworkImage(
                              (data?.imageUrl ?? widget.artist.imageUrl)!,
                            )
                          : null,
                      child: (data?.imageUrl ?? widget.artist.imageUrl) == null
                          ? Text(
                              widget.artist.name.isNotEmpty
                                  ? widget.artist.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.artist.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (isLoading)
                            const SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF1DB954,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(
                                    0xFF1DB954,
                                  ).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                data?.genre ?? widget.artist.genre,
                                style: const TextStyle(
                                  color: Color(0xFF1DB954),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white10),
                const SizedBox(height: 12),

                // Biography
                const Text(
                  'Biography',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  data?.biography ?? widget.artist.biography,
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _launchUrl(widget.artist.wikipediaUrl),
                    icon: const FaIcon(
                      FontAwesomeIcons.wikipediaW,
                      size: 16,
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
                      backgroundColor: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Discography
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Discography',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (data != null)
                      Text(
                        '${data.albums.length} albums',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (data == null || data.albums.isEmpty)
                  Text(
                    'No albums found.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: data.albums.length,
                    itemBuilder: (context, index) {
                      final album = data.albums[index];
                      final heroTag = 'artist_profile_${album.id}_$index';
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AlbumDetailScreen(
                                album: album,
                                artist: widget.artist,
                                heroTag: heroTag,
                              ),
                            ),
                          );
                        },
                        child: AlbumCard(
                          heroTag: heroTag,
                          title: album.title,
                          artist: widget.artist.name,
                          coverUrl: album.coverUrl,
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 28),

                // Upcoming Concerts
                const Text(
                  'Upcoming Concerts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (data == null || data.concerts.isEmpty)
                  Text(
                    'No upcoming concerts found.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  )
                else ...[
                  ...data.concerts.map(
                    (c) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
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
                          builder: (_) =>
                              MapScreen(initialArtistName: widget.artist.name),
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

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ArtistProfileData {
  final String genre;
  final String biography;
  final List<Album> albums;
  final List<ConcertLocation> concerts;
  final String? imageUrl;

  const _ArtistProfileData({
    required this.genre,
    required this.biography,
    required this.albums,
    required this.concerts,
    this.imageUrl,
  });
}
