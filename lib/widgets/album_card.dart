import 'package:flutter/material.dart';

class AlbumCard extends StatelessWidget {
  final String heroTag;
  final String title;
  final String artist;
  final String coverUrl;

  const AlbumCard({
    super.key,
    required this.heroTag,
    required this.title,
    required this.artist,
    required this.coverUrl,
  });

  Widget _buildCoverImage() {
    if (coverUrl.startsWith('http')) {
      return Image.network(
        coverUrl,
        width: double.infinity,
        fit: BoxFit.cover,
        cacheWidth: 350,
        cacheHeight: 350,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    } else {
      return Image.asset(
        coverUrl,
        width: double.infinity,
        fit: BoxFit.cover,
        cacheWidth: 350,
        cacheHeight: 350,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF222222),
      child: const Center(
        child: Icon(Icons.album, size: 48, color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Hero(tag: heroTag, child: _buildCoverImage()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  artist,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[400],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
