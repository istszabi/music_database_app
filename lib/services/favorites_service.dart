import 'package:flutter/material.dart';
import '../models/music_data_models.dart';

class FavoritesService {
  static final FavoritesService instance = FavoritesService._internal();
  FavoritesService._internal();

  final ValueNotifier<List<Album>> favoriteAlbums = ValueNotifier<List<Album>>([]);

  bool isFavorite(String albumId) {
    return favoriteAlbums.value.any((a) => a.id == albumId);
  }

  void toggleFavorite(Album album) {
    final currentList = List<Album>.from(favoriteAlbums.value);
    if (isFavorite(album.id)) {
      currentList.removeWhere((a) => a.id == album.id);
    } else {
      currentList.add(album);
    }
    favoriteAlbums.value = currentList;
  }
}