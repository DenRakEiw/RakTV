/*
 * RakTV (based on FLauncher)
 * Copyright (C) 2021  Étienne Fesser
 * Copyright (C) 2026  DenRakEiw
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/jellyfin_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/ensure_visible.dart';
import 'package:flauncher/widgets/settings/applications_panel_page.dart';
import 'package:flauncher/widgets/settings/categories_panel_page.dart';
import 'package:flauncher/widgets/settings/flauncher_about_dialog.dart';
import 'package:flauncher/widgets/settings/wallpaper_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

class SettingsPanelPage extends StatelessWidget {
  static const String routeName = "settings_panel";

  static const List<Map<String, dynamic>> _neonPresets = [
    {"name": "Waifu Pink", "color": 0xFFFF2A85},
    {"name": "Cyber Cyan", "color": 0xFF00F0FF},
    {"name": "Sakura Purple", "color": 0xFFB537F2},
    {"name": "Matrix Emerald", "color": 0xFF00FF87},
    {"name": "Amber Gold", "color": 0xFFFFC800},
  ];

  static const List<String> _fontFamilies = [
    "Roboto",
    "monospace",
    "serif",
    "sans-serif-condensed",
  ];

  @override
  Widget build(BuildContext context) => Consumer<SettingsService>(
        builder: (context, settingsService, __) {
          final accent = settingsService.neonAccentColor;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "RakTV Settings",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: accent),
                  textAlign: TextAlign.center,
                ),
                Divider(),
                EnsureVisible(
                  alignment: 0.5,
                  child: TextButton(
                    child: Row(
                      children: [
                        Icon(Icons.apps),
                        Container(width: 8),
                        Text("Applications", style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                    onPressed: () => Navigator.of(context).pushNamed(ApplicationsPanelPage.routeName),
                  ),
                ),
                TextButton(
                  child: Row(
                    children: [
                      Icon(Icons.category),
                      Container(width: 8),
                      Text("Categories", style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  onPressed: () => Navigator.of(context).pushNamed(CategoriesPanelPage.routeName),
                ),
                TextButton(
                  child: Row(
                    children: [
                      Icon(Icons.wallpaper_outlined, color: accent),
                      Container(width: 8),
                      Text("Wallpapers & Live Video", style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  onPressed: () => Navigator.of(context).pushNamed(WallpaperPanelPage.routeName),
                ),
                TextButton(
                  child: Row(
                    children: [
                      Icon(Icons.bolt, color: Colors.amberAccent),
                      Container(width: 8),
                      Text("1-Click RAM Boost", style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  onPressed: () async {
                    final res = await context.read<AppsService>().boostRam();
                    final avail = res["availMb"] ?? 0;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: Duration(seconds: 3),
                        backgroundColor: Colors.black87,
                        content: Text("⚡ RAM Boosted ($avail MB free)"),
                      ),
                    );
                  },
                ),
                Divider(),
                // Waifu Poster Mode (Auto-Idle UI Fade-Out)
                TextButton(
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_motion, color: accent),
                      Container(width: 8),
                      Expanded(
                        child: Text(
                          "Waifu Poster Idle: ${settingsService.posterIdleSeconds == 0 ? 'Off' : '${settingsService.posterIdleSeconds}s'}",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  onPressed: () {
                    const options = [0, 30, 60, 180, 300];
                    final idx = options.indexOf(settingsService.posterIdleSeconds);
                    final next = options[(idx + 1) % options.length];
                    settingsService.setPosterIdleSeconds(next);
                  },
                ),
                // Glassmorphism & Neon Glow
                SwitchListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  value: settingsService.glassNeonEnabled,
                  onChanged: (value) => settingsService.setGlassNeonEnabled(value),
                  title: Text("Glassmorphism & Neon Glow"),
                  dense: true,
                ),
                // Neon Accent Color Picker
                TextButton(
                  child: Row(
                    children: [
                      Icon(Icons.palette_outlined, color: accent),
                      Container(width: 8),
                      Expanded(
                        child: Text(
                          "Neon Color: ${_neonName(settingsService.neonAccentColorValue)}",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  onPressed: () {
                    final idx = _neonPresets.indexWhere((p) => p["color"] == settingsService.neonAccentColorValue);
                    final next = _neonPresets[(idx + 1) % _neonPresets.length];
                    settingsService.setNeonAccentColorValue(next["color"] as int);
                  },
                ),
                // Custom Font Family
                TextButton(
                  child: Row(
                    children: [
                      Icon(Icons.font_download_outlined),
                      Container(width: 8),
                      Expanded(
                        child: Text(
                          "Font: ${settingsService.customFontFamily}",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  onPressed: () {
                    final idx = _fontFamilies.indexOf(settingsService.customFontFamily);
                    final next = _fontFamilies[(idx + 1) % _fontFamilies.length];
                    settingsService.setCustomFontFamily(next);
                  },
                ),
                // OLED Night Dimmer
                TextButton(
                  child: Row(
                    children: [
                      Icon(Icons.brightness_4_outlined),
                      Container(width: 8),
                      Expanded(
                        child: Text(
                          "Night Dimmer: ${(settingsService.nightDimmerLevel * 100).round()}%",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  onPressed: () {
                    const steps = [0.0, 0.15, 0.30, 0.45, 0.65];
                    final curr = settingsService.nightDimmerLevel;
                    int idx = steps.indexWhere((s) => (s - curr).abs() < 0.05);
                    final next = steps[(idx + 1) % steps.length];
                    settingsService.setNightDimmerLevel(next);
                  },
                ),
                Divider(),
                // Jellyfin Integration
                SwitchListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  value: settingsService.jellyfinEnabled,
                  onChanged: (value) => settingsService.setJellyfinEnabled(value),
                  title: Text("Jellyfin Home Row"),
                  dense: true,
                ),
                TextButton(
                  child: Row(
                    children: [
                      Icon(Icons.dns_outlined, color: accent),
                      Container(width: 8),
                      Expanded(
                        child: Text(
                          "Configure Jellyfin Server",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  onPressed: () => _showJellyfinDialog(context, settingsService),
                ),
                // System HUD (Weather + RAM + Jellyfin Status)
                SwitchListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  value: settingsService.systemHudEnabled,
                  onChanged: (value) => settingsService.setSystemHudEnabled(value),
                  title: Text("Top-Bar System HUD (RAM & Weather)"),
                  dense: true,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  value: settingsService.use24HourTimeFormat,
                  onChanged: (value) => settingsService.setUse24HourTimeFormat(value),
                  title: Text("Use 24-hour time format"),
                  dense: true,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  value: settingsService.appHighlightAnimationEnabled,
                  onChanged: (value) => settingsService.setAppHighlightAnimationEnabled(value),
                  title: Text("App card highlight animation"),
                  dense: true,
                ),
                Divider(),
                // Hidden Vault Toggle
                TextButton(
                  child: Row(
                    children: [
                      Icon(
                        settingsService.vaultUnlocked ? Icons.lock_open : Icons.vpn_key_outlined,
                        color: accent,
                      ),
                      Container(width: 8),
                      Expanded(
                        child: Text(
                          settingsService.vaultUnlocked
                              ? "Lock Hidden Vault (⬆️⬆️⬇️⬇️⬅️➡️)"
                              : "Unlock Hidden Vault (⬆️⬆️⬇️⬇️⬅️➡️)",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  onPressed: () => settingsService.toggleVaultUnlocked(),
                ),
                TextButton(
                  child: Row(
                    children: [
                      Icon(Icons.settings_outlined),
                      Container(width: 8),
                      Text("Android settings", style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  onPressed: () => context.read<AppsService>().openSettings(),
                ),
                Divider(),
                TextButton(
                  child: Row(
                    children: [
                      Icon(Icons.info_outline),
                      Container(width: 8),
                      Text("About RakTV", style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snapshot) => snapshot.connectionState == ConnectionState.done
                          ? FLauncherAboutDialog(packageInfo: snapshot.data!)
                          : Container(),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );

  String _neonName(int colorVal) {
    for (final p in _neonPresets) {
      if (p["color"] == colorVal) return p["name"] as String;
    }
    return "Custom";
  }

  Future<void> _showJellyfinDialog(BuildContext context, SettingsService settings) async {
    final jellyfin = context.read<JellyfinService>();
    final urlCtrl = TextEditingController(text: jellyfin.activeServerUrl);
    final keyCtrl = TextEditingController(text: settings.jellyfinApiKey);

    await showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text("Jellyfin LAN Server"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              decoration: InputDecoration(
                labelText: "Server URL (e.g. http://192.168.50.107:8096)",
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: keyCtrl,
              decoration: InputDecoration(
                labelText: "Optional API Key (for Poster Preview Row)",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await jellyfin.discoverOnLan();
              urlCtrl.text = jellyfin.activeServerUrl;
            },
            child: Text("Auto-Discover LAN"),
          ),
          TextButton(
            onPressed: () async {
              await settings.setJellyfinServerUrl(urlCtrl.text);
              await settings.setJellyfinApiKey(keyCtrl.text);
              Navigator.of(dCtx).pop();
            },
            child: Text("Save"),
          ),
        ],
      ),
    );
  }
}
