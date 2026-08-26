import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../data/mock_data.dart';
import '../models/music_data_models.dart';
import '../services/spotify_service.dart';
import 'album_detail_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? scannedValue = barcodes.first.rawValue;
    if (scannedValue == null || scannedValue.isEmpty) return;

    setState(() => _isProcessing = true);

    // Trigger physical vibration on scan match
    HapticFeedback.vibrate();

    Album? matchedAlbum;
    Artist? matchedArtist;

    // 1. Try local match first
    final allAlbums = mockArtists.expand((a) => a.albums).toList();
    for (final alb in allAlbums) {
      if (alb.id.toLowerCase() == scannedValue.toLowerCase() ||
          alb.title.toLowerCase().contains(scannedValue.toLowerCase())) {
        matchedAlbum = alb;
        matchedArtist = mockArtists.firstWhere(
          (a) => a.albums.any((x) => x.id == alb.id),
        );
        break;
      }
    }

    // 2. Try Spotify UPC / Search API
    /* if (matchedAlbum == null) {
      final spotifyResult = await SpotifyService.searchByBarcode(scannedValue);
      if (spotifyResult != null) {
        matchedAlbum = spotifyResult['album'];
        matchedArtist = spotifyResult['artist'];
      }
    } */

    // 3. Fallback
    matchedAlbum ??= allAlbums.first;
    matchedArtist ??= mockArtists.first;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Album Identified!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Barcode: $scannedValue',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              '${matchedAlbum!.title} by ${matchedArtist!.name}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isProcessing = false);
            },
            child: const Text(
              'Scan Again',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AlbumDetailScreen(
                    album: matchedAlbum!,
                    artist: matchedArtist!,
                  ),
                ),
              ).then((_) => setState(() => _isProcessing = false));
            },
            child: const Text(
              'View Album',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Vinyl / CD Barcode'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                  color: const Color(0xFF1DB954),
                );
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _handleBarcode),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF1DB954), width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
