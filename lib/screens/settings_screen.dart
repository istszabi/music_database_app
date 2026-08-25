import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _offlineMode = false;
  bool _highQualityAudio = true;
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildSectionHeader('Preferences'),
          SwitchListTile(
            activeColor: const Color(0xFF1DB954),
            title: const Text('Offline Mode'),
            subtitle: const Text('Only show local cached metadata and covers'),
            value: _offlineMode,
            onChanged: (val) => setState(() => _offlineMode = val),
          ),
          SwitchListTile(
            activeColor: const Color(0xFF1DB954),
            title: const Text('High Quality Images'),
            subtitle: const Text('Render high-resolution album covers'),
            value: _highQualityAudio,
            onChanged: (val) => setState(() => _highQualityAudio = val),
          ),
          SwitchListTile(
            activeColor: const Color(0xFF1DB954),
            title: const Text('Concert Alerts'),
            subtitle: const Text('Get notified when tracked artists announce dates'),
            value: _notifications,
            onChanged: (val) => setState(() => _notifications = val),
          ),
          const Divider(color: Colors.white10),
          _buildSectionHeader('Storage & Cache'),
          ListTile(
            leading: const Icon(Icons.cleaning_services, color: Colors.grey),
            title: const Text('Clear Image Cache'),
            subtitle: const Text('Free up memory storage used by local artwork'),
            onTap: () {
              PaintingBinding.instance.imageCache.clear();
              PaintingBinding.instance.imageCache.clearLiveImages();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Image cache cleared successfully')),
              );
            },
          ),
          const Divider(color: Colors.white10),
          _buildSectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline, color: Colors.grey),
            title: Text('Version'),
            subtitle: Text('1.0.0 (Build 2026.1)'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1DB954),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}