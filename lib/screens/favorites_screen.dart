import 'package:flutter/material.dart';
import '../services/favorites_service.dart';
import '../data/mock_data.dart';
import '../models/music_data_models.dart';
import '../widgets/album_card.dart';
import 'album_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Favorite Albums',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ValueListenableBuilder<List<Album>>(
        valueListenable: FavoritesService.instance.favoriteAlbums,
        builder: (context, favorites, child) {
          if (favorites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No favorites yet',
                    style: TextStyle(color: Colors.grey[500], fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add albums to favorites from their detail view',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final album = favorites[index];

                final artist = mockArtists.firstWhere(
                  (a) => a.albums.any((alb) => alb.id == album.id),
                  orElse: () => Artist(
                    id: 'fav_artist_${album.id}',
                    name: 'Artist',
                    genre: 'Music',
                    biography: 'Saved in your library favorites.',
                    wikipediaUrl:
                        'https://en.wikipedia.org/wiki/Special:Search?search=${Uri.encodeComponent(album.title)}',
                    albums: [album],
                    upcomingConcerts: const [],
                  ),
                );
                final heroTag = 'favorites_${album.id}_$index';

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AlbumDetailScreen(
                          album: album,
                          artist: artist,
                          heroTag: heroTag,
                        ),
                      ),
                    );
                  },
                  child: AlbumCard(
                    heroTag: heroTag,
                    title: album.title,
                    artist: artist.name,
                    coverUrl: album.coverUrl,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
