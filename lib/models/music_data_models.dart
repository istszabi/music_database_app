class Song {
  final String title;
  final String duration;

  const Song({required this.title, required this.duration});
}

class ConcertLocation {
  final String venueName;
  final String city;
  final double latitude;
  final double longitude;
  final String date;

  const ConcertLocation({
    required this.venueName,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.date,
  });
}

class Album {
  final String id;
  final String title;
  final String releaseYear;
  final String coverUrl;
  final String description;
  final String spotifyUrl;
  final List<Song> tracks;

  const Album({
    required this.id,
    required this.title,
    required this.releaseYear,
    required this.coverUrl,
    required this.description,
    required this.spotifyUrl,
    required this.tracks,
  });
}

class Artist {
  final String id;
  final String name;
  final String genre;
  final String biography;
  final String wikipediaUrl;
  final List<Album> albums;
  final List<ConcertLocation> upcomingConcerts;

  /// Spotify artist image URL. Null for mock-data artists (no network
  /// image available) — UI should fall back to an initial-letter avatar.
  final String? imageUrl;

  const Artist({
    required this.id,
    required this.name,
    required this.genre,
    required this.biography,
    required this.wikipediaUrl,
    required this.albums,
    required this.upcomingConcerts,
    this.imageUrl,
  });
}
