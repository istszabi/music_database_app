import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/music_data_models.dart';
import '../services/favorites_service.dart';
import '../services/spotify_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Configurable Settings State
  bool _preferSpotifyApp = true;
  bool _vibrateOnScan = true;
  bool _autoOpenScannedLinks = true;
  bool _highQualityImages = true;

  // Diagnostic State
  bool _isTestingApi = false;
  String _apiStatus = 'Untested';
  Color _apiStatusColor = Colors.grey;

  Future<void> _testSpotifyConnection() async {
    setState(() {
      _isTestingApi = true;
      _apiStatus = 'Testing...';
      _apiStatusColor = Colors.amber;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final results = await SpotifyService.searchAlbums('Daft Punk');
      stopwatch.stop();

      if (!mounted) return;
      if (results.isNotEmpty) {
        setState(() {
          _isTestingApi = false;
          _apiStatus = 'Connected (${stopwatch.elapsedMilliseconds}ms)';
          _apiStatusColor = const Color(0xFF1DB954);
        });
      } else {
        setState(() {
          _isTestingApi = false;
          _apiStatus = 'No response';
          _apiStatusColor = Colors.orange;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTestingApi = false;
        _apiStatus = 'Failed: $e';
        _apiStatusColor = Colors.redAccent;
      });
    }
  }

  void _clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    if (_vibrateOnScan) HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E1E1E),
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF1DB954), size: 18),
            SizedBox(width: 8),
            Text(
              'Image memory cache cleared',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _confirmClearFavorites() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Clear All Favorites?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will remove all saved albums from your local library. This action cannot be undone.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final favs = List<Album>.from(
                FavoritesService.instance.favoriteAlbums.value,
              );
              for (final album in favs) {
                FavoritesService.instance.toggleFavorite(album);
              }
              Navigator.pop(ctx);
              if (_vibrateOnScan) HapticFeedback.heavyImpact();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF1E1E1E),
                  content: const Text(
                    'All favorites removed',
                    style: TextStyle(color: Colors.white),
                  ),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Clear All',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrlExternal(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open link')));
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF1DB954),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // -------------------------------------------------------------------
          // API & CONNECTIVITY
          // -------------------------------------------------------------------
          _buildSectionHeader('API & Connectivity'),
          _buildCard(
            children: [
              ListTile(
                leading: const FaIcon(
                  FontAwesomeIcons.spotify,
                  color: Color(0xFF1DB954),
                  size: 22,
                ),
                title: const Text(
                  'Spotify Web API',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  'Status: $_apiStatus',
                  style: TextStyle(color: _apiStatusColor, fontSize: 13),
                ),
                trailing: ElevatedButton(
                  onPressed: _isTestingApi ? null : _testSpotifyConnection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(
                      0xFF1DB954,
                    ).withValues(alpha: 0.15),
                    foregroundColor: const Color(0xFF1DB954),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: const Color(0xFF1DB954).withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  child: _isTestingApi
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF1DB954),
                          ),
                        )
                      : const Text(
                          'Test Ping',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const Divider(color: Colors.white10, height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.open_in_new, color: Colors.grey),
                title: const Text(
                  'Prefer Native Spotify App',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                subtitle: const Text(
                  'Opens links directly in installed Spotify app',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                trailing: Switch(
                  value: _preferSpotifyApp,
                  activeColor: const Color(0xFF1DB954),
                  onChanged: (val) => setState(() => _preferSpotifyApp = val),
                ),
              ),
            ],
          ),

          // -------------------------------------------------------------------
          // SCANNER & HARDWARE
          // -------------------------------------------------------------------
          _buildSectionHeader('Scanner & Hardware'),
          _buildCard(
            children: [
              ListTile(
                leading: const Icon(Icons.vibration, color: Colors.grey),
                title: const Text(
                  'Haptic Feedback',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                subtitle: const Text(
                  'Vibrate phone on successful barcode detection',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                trailing: Switch(
                  value: _vibrateOnScan,
                  activeColor: const Color(0xFF1DB954),
                  onChanged: (val) => setState(() => _vibrateOnScan = val),
                ),
              ),
              const Divider(color: Colors.white10, height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.bolt, color: Colors.grey),
                title: const Text(
                  'Auto-Open Scanned Releases',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                subtitle: const Text(
                  'Immediately navigate to album details on match',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                trailing: Switch(
                  value: _autoOpenScannedLinks,
                  activeColor: const Color(0xFF1DB954),
                  onChanged: (val) =>
                      setState(() => _autoOpenScannedLinks = val),
                ),
              ),
            ],
          ),

          // -------------------------------------------------------------------
          // DATA & STORAGE
          // -------------------------------------------------------------------
          _buildSectionHeader('Data & Storage'),
          _buildCard(
            children: [
              ValueListenableBuilder<List<Album>>(
                valueListenable: FavoritesService.instance.favoriteAlbums,
                builder: (context, favs, _) {
                  return ListTile(
                    leading: const Icon(
                      Icons.favorite,
                      color: Color(0xFF1DB954),
                    ),
                    title: const Text(
                      'Saved Albums',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    subtitle: Text(
                      '${favs.length} albums in your local library',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    trailing: favs.isNotEmpty
                        ? TextButton(
                            onPressed: _confirmClearFavorites,
                            child: const Text(
                              'Clear',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                  );
                },
              ),
              const Divider(color: Colors.white10, height: 1, indent: 56),
              ListTile(
                leading: const Icon(
                  Icons.cleaning_services_outlined,
                  color: Colors.grey,
                ),
                title: const Text(
                  'Clear Memory Cache',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                subtitle: const Text(
                  'Frees loaded album cover artwork from RAM',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey,
                  ),
                  onPressed: _clearImageCache,
                ),
                onTap: _clearImageCache,
              ),
            ],
          ),

          // -------------------------------------------------------------------
          // ABOUT & ATTRIBUTION
          // -------------------------------------------------------------------
          _buildSectionHeader('About & Attribution'),
          _buildCard(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.grey),
                title: const Text(
                  'Music Database App',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                subtitle: const Text(
                  'Version 1.0.0 (Build 2026)',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              const Divider(color: Colors.white10, height: 1, indent: 56),
              ListTile(
                leading: const FaIcon(
                  FontAwesomeIcons.wikipediaW,
                  color: Colors.grey,
                  size: 18,
                ),
                title: const Text(
                  'Wikipedia REST API',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                subtitle: const Text(
                  'Artist biography integration under CC BY-SA 4.0',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                trailing: const Icon(
                  Icons.open_in_new,
                  size: 16,
                  color: Colors.grey,
                ),
                onTap: () => _launchUrlExternal('https://www.wikimedia.org/'),
              ),
              const Divider(color: Colors.white10, height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.article_outlined, color: Colors.grey),
                title: const Text(
                  'Open Source Licenses',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey,
                ),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Music Database',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Icon(
                      Icons.library_music,
                      size: 40,
                      color: Color(0xFF1DB954),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
