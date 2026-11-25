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

import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/settings/gradient_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WallpaperPanelPage extends StatelessWidget {
  static const String routeName = "wallpaper_panel";

  static const List<String> _popularSubreddits = [
    "AnimeWallpaper",
    "Moescape",
    "Waifu",
    "Patchuu",
    "EarthPorn",
    "Cyberpunk",
  ];

  @override
  Widget build(BuildContext context) => Consumer2<SettingsService, WallpaperService>(
        builder: (context, settings, wallpaper, _) {
          final accent = settings.neonAccentColor;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Wallpapers & Live Video",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: accent),
                  textAlign: TextAlign.center,
                ),
                Divider(),
                // 1. Reddit Subreddit Auto-Loader
                TextButton(
                  autofocus: true,
                  child: Row(
                    children: [
                      Icon(Icons.reddit, color: accent),
                      Container(width: 8),
                      Expanded(
                        child: Text(
                          "Subreddit: r/${settings.redditSubreddit}",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  onPressed: () => _showSubredditDialog(context, settings, wallpaper, false),
                ),
                TextButton(
                  child: Row(
                    children: [
                      Icon(Icons.refresh, color: accent),
                      Container(width: 8),
                      Expanded(
                        child: Text(
                          wallpaper.isLoadingReddit ? "Loading from Reddit..." : "Load Next Reddit Wallpaper Now",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  onPressed: () => wallpaper.fetchRedditWallpaper(),
                ),
                // Quick Presets
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _popularSubreddits
                      .map(
                        (sub) => ActionChip(
                          backgroundColor: settings.redditSubreddit == sub ? accent.withOpacity(0.35) : Colors.black38,
                          label: Text("r/$sub", style: TextStyle(fontSize: 11, color: Colors.white)),
                          onPressed: () async {
                            await settings.setRedditSubreddit(sub);
                            await wallpaper.fetchRedditWallpaper(sub);
                          },
                        ),
                      )
                      .toList(),
                ),
                Divider(),
                // Vault Subreddit
                TextButton(
                  child: Row(
                    children: [
                      Icon(Icons.vpn_key_outlined, color: accent),
                      Container(width: 8),
                      Expanded(
                        child: Text(
                          "Vault Subreddit: r/${settings.vaultSubreddit}",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  onPressed: () => _showSubredditDialog(context, settings, wallpaper, true),
                ),
                // Auto-Rotate Interval
                TextButton(
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined),
                      Container(width: 8),
                      Expanded(
                        child: Text(
                          "Auto-Rotate: ${settings.wallpaperIntervalMinutes == 0 ? 'Off' : 'Every ${settings.wallpaperIntervalMinutes} min'}",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  onPressed: () {
                    const intervals = [0, 5, 15, 30, 60];
                    final idx = intervals.indexOf(settings.wallpaperIntervalMinutes);
                    final next = intervals[(idx + 1) % intervals.length];
                    settings.setWallpaperIntervalMinutes(next);
                  },
                ),
                Divider(),
                // 2. Live Video Wallpaper (.mp4 / .webm) & Local Folder Slideshow
                TextButton(
                  child: Row(
                    children: [
                      Icon(Icons.video_library_outlined, color: accent),
                      Container(width: 8),
                      Expanded(
                        child: Text(
                          "Live Video Wallpaper (.mp4 / URL)",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  onPressed: () => _showVideoWallpaperDialog(context, settings, wallpaper),
                ),
                TextButton(
                  child: Row(
                    children: [
                      Icon(Icons.folder_open_outlined, color: accent),
                      Container(width: 8),
                      Expanded(
                        child: Text(
                          "Local Folder Slideshow (TV / USB)",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  onPressed: () => _showLocalMediaBrowser(context, settings, wallpaper),
                ),
                Divider(),
                TextButton(
                  child: Row(
                    children: [
                      Icon(Icons.gradient),
                      Container(width: 8),
                      Text("Gradients", style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  onPressed: () => Navigator.of(context).pushNamed(GradientPanelPage.routeName),
                ),
                TextButton(
                  child: Row(
                    children: [
                      Icon(Icons.insert_drive_file_outlined),
                      Container(width: 8),
                      Text("Pick Single Image (Gallery)", style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  onPressed: () async {
                    try {
                      await context.read<WallpaperService>().pickWallpaper();
                    } on NoFileExplorerException {
                      await _showLocalMediaBrowser(context, settings, wallpaper);
                    }
                  },
                ),
                if (wallpaper.currentWallpaperCaption != null) ...[
                  SizedBox(height: 12),
                  Text(
                    wallpaper.currentWallpaperCaption!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          );
        },
      );

  Future<void> _showSubredditDialog(
    BuildContext context,
    SettingsService settings,
    WallpaperService wallpaper,
    bool isVault,
  ) async {
    final ctrl = TextEditingController(text: isVault ? settings.vaultSubreddit : settings.redditSubreddit);
    await showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(isVault ? "Hidden Vault Subreddit" : "Custom Reddit Subreddit"),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: "Subreddit name (e.g. AnimeWallpaper or Moescape,Waifu)",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (isVault) {
                await settings.setVaultSubreddit(ctrl.text);
              } else {
                await settings.setRedditSubreddit(ctrl.text);
                await wallpaper.fetchRedditWallpaper(ctrl.text);
              }
              Navigator.of(dCtx).pop();
            },
            child: Text("Apply"),
          ),
        ],
      ),
    );
  }

  Future<void> _showVideoWallpaperDialog(
    BuildContext context,
    SettingsService settings,
    WallpaperService wallpaper,
  ) async {
    final ctrl = TextEditingController(text: settings.videoWallpaperPath ?? "");
    final localVideos = (await wallpaper.scanLocalMediaFiles())
        .where((f) => f.toLowerCase().endsWith(".mp4") || f.toLowerCase().endsWith(".webm"))
        .toList();

    await showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text("Live Video Wallpaper (.mp4 / .webm)"),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  labelText: "Local .mp4 path or HTTP video URL",
                ),
              ),
              if (localVideos.isNotEmpty) ...[
                SizedBox(height: 12),
                SizedBox(
                  height: 150,
                  child: ListView.builder(
                    itemCount: localVideos.length,
                    itemBuilder: (_, idx) => ListTile(
                      leading: Icon(Icons.movie, color: settings.neonAccentColor),
                      title: Text(localVideos[idx].split('/').last),
                      subtitle: Text(localVideos[idx]),
                      onTap: () {
                        ctrl.text = localVideos[idx];
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await settings.setVideoWallpaperPath(null);
              await wallpaper.fetchRedditWallpaper();
              Navigator.of(dCtx).pop();
            },
            child: Text("Clear Video"),
          ),
          TextButton(
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                await wallpaper.setLocalFileAsWallpaper(ctrl.text.trim());
              }
              Navigator.of(dCtx).pop();
            },
            child: Text("Set Live Video"),
          ),
        ],
      ),
    );
  }

  Future<void> _showLocalMediaBrowser(
    BuildContext context,
    SettingsService settings,
    WallpaperService wallpaper,
  ) async {
    final files = await wallpaper.scanLocalMediaFiles();
    await showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text("Local Wallpapers & Videos on TV"),
        content: SizedBox(
          width: 420,
          height: 260,
          child: files.isEmpty
              ? Center(
                  child: Text(
                    "No images or .mp4 videos found in /sdcard/Pictures, /sdcard/Download, or /sdcard/Wallpapers.",
                  ),
                )
              : ListView.builder(
                  itemCount: files.length,
                  itemBuilder: (_, idx) => ListTile(
                    leading: Icon(
                      files[idx].toLowerCase().endsWith(".mp4") ? Icons.videocam : Icons.image,
                      color: settings.neonAccentColor,
                    ),
                    title: Text(files[idx].split('/').last),
                    subtitle: Text(files[idx]),
                    onTap: () async {
                      await wallpaper.setLocalFileAsWallpaper(files[idx]);
                      Navigator.of(dCtx).pop();
                    },
                  ),
                ),
        ),
        actions: [
          if (files.isNotEmpty)
            TextButton(
              onPressed: () async {
                await settings.setWallpaperSource("local_folder");
                await wallpaper.nextLocalFolderWallpaper();
                Navigator.of(dCtx).pop();
              },
              child: Text("Start Folder Slideshow"),
            ),
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }
}
