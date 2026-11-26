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
import 'package:flauncher/providers/frigate_service.dart';
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
                // 5-Theme App Banner Pack Switcher
                TextButton(
                  child: Row(
                    children: [
                      Icon(Icons.style_outlined, color: accent),
                      Container(width: 8),
                      Expanded(
                        child: Text(
                          "Banner Theme: ${_themePackLabel(settingsService.iconThemePack)}",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  onPressed: () async {
                    const packs = [
                      "default",
                      "cyberpunk",
                      "anime",
                      "oled",
                      "synthwave",
                      "ps5",
                      "matrix",
                      "ghibli",
                      "vaporwave",
                      "wood_luxury",
                      "pixel_arcade",
                      "manga_ink",
                      "nordic_aurora",
                      "gold_noir",
                      "holographic",
                      "volcanic_ember",
                    ];
                    final idx = packs.indexOf(settingsService.iconThemePack);
                    final next = packs[(idx + 1) % packs.length];
                    await settingsService.setIconThemePack(next);
                    await context.read<AppsService>().applyIconThemePack(next);
                    // Sync matching neon accent color for cohesive look
                    if (next == "cyberpunk" || next == "synthwave" || next == "vaporwave" || next == "manga_ink" || next == "volcanic_ember") {
                      settingsService.setNeonAccentColorValue(0xFFFF2A85);
                    } else if (next == "anime" || next == "holographic") {
                      settingsService.setNeonAccentColorValue(0xFFB537F2);
                    } else if (next == "oled" || next == "wood_luxury" || next == "gold_noir" || next == "ghibli") {
                      settingsService.setNeonAccentColorValue(0xFFFFC800);
                    } else if (next == "matrix" || next == "nordic_aurora") {
                      settingsService.setNeonAccentColorValue(0xFF00FF87);
                    } else if (next == "ps5" || next == "pixel_arcade") {
                      settingsService.setNeonAccentColorValue(0xFF00F0FF);
                    }
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
                SwitchListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  value: settingsService.autoNightShiftEnabled,
                  onChanged: (value) => settingsService.setAutoNightShiftEnabled(value),
                  title: Text("Auto-Night-Shift (22:00–07:00 OLED Dimmer & Night Art)"),
                  dense: true,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  value: settingsService.showHdmiCardsEnabled,
                  onChanged: (value) => settingsService.setShowHdmiCardsEnabled(value),
                  title: Text("Show Direct HDMI Input Cards (HDMI 1–3)"),
                  dense: true,
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
                SwitchListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  value: settingsService.ps5BackdropPreviewEnabled,
                  onChanged: (value) => settingsService.setPs5BackdropPreviewEnabled(value),
                  title: Text("PS5-Style Dynamic Movie Backdrop Preview"),
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
                Divider(),
                // Frigate Live Camera & Person Alert PiP
                SwitchListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  value: settingsService.frigateAlertsEnabled,
                  onChanged: (value) => settingsService.setFrigateAlertsEnabled(value),
                  title: Text("Frigate AI Camera Person Alerts (10s PiP)"),
                  dense: true,
                ),
                TextButton(
                  child: Row(
                    children: [
                      Icon(Icons.videocam_outlined, color: accent),
                      Container(width: 8),
                      Expanded(
                        child: Text(
                          "Configure / Preview Frigate Camera PiP",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  onPressed: () => _showFrigateDialog(context, settingsService),
                ),
                Divider(),
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
                labelText: "Server URL (e.g. http://192.168.1.100:8096)",
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

  Future<void> _showFrigateDialog(BuildContext context, SettingsService settings) async {
    final frigate = context.read<FrigateService>();
    final urlCtrl = TextEditingController(text: frigate.activeServerUrl);

    await showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text("Frigate AI Camera (10s PiP)"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: urlCtrl,
              decoration: InputDecoration(
                labelText: "Frigate Server URL (e.g. http://192.168.1.100:5000)",
              ),
            ),
            if (frigate.cameras.isNotEmpty) ...[
              SizedBox(height: 12),
              Text(
                "Detected Cameras: ${frigate.cameras.join(', ')}",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await frigate.discoverOnLan();
              urlCtrl.text = frigate.activeServerUrl;
            },
            child: Text("Auto-Discover LAN"),
          ),
          TextButton(
            onPressed: () async {
              await settings.setFrigateServerUrl(urlCtrl.text);
              Navigator.of(dCtx).pop();
              await frigate.showCameraPip(durationSeconds: 10);
            },
            child: Text("Preview 10s PiP"),
          ),
          TextButton(
            onPressed: () async {
              await settings.setFrigateServerUrl(urlCtrl.text);
              Navigator.of(dCtx).pop();
            },
            child: Text("Save"),
          ),
        ],
      ),
    );
  }

  String _themePackLabel(String pack) {
    switch (pack) {
      case "cyberpunk":
        return "Cyberpunk Neon";
      case "anime":
        return "Anime Glassmorphism";
      case "oled":
        return "OLED Minimal Dark";
      case "synthwave":
        return "Retro 80s Synthwave";
      case "ps5":
        return "PS5 Frosted Cinema";
      case "matrix":
        return "Matrix Hacker Emerald";
      case "ghibli":
        return "Studio Ghibli Watercolor";
      case "vaporwave":
        return "90s Vaporwave Marble";
      case "wood_luxury":
        return "Walnut & Brushed Brass";
      case "pixel_arcade":
        return "16-Bit Pixel Arcade";
      case "manga_ink":
        return "Japanese Manga Ink";
      case "nordic_aurora":
        return "Nordic Aurora Frost";
      case "gold_noir":
        return "Art Deco Gold Noir";
      case "holographic":
        return "Iridescent Liquid Holo";
      case "volcanic_ember":
        return "Obsidian Lava Ember";
      default:
        return "Original Default";
    }
  }
}
