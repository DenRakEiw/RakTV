/*
 * RakTV (based on FLauncher)
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
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class JellyfinRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Consumer2<JellyfinService, SettingsService>(
        builder: (context, jellyfin, settings, _) {
          if (!settings.jellyfinEnabled || jellyfin.latestItems.isEmpty) {
            return SizedBox.shrink();
          }
          final accent = settings.neonAccentColor;

          return Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 16, bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.movie_filter_outlined, color: accent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Jellyfin • Newly Added",
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          shadows: [Shadow(color: Colors.black54, offset: Offset(1, 1), blurRadius: 8)],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 135,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    itemCount: jellyfin.latestItems.length,
                    itemBuilder: (context, index) {
                      final item = jellyfin.latestItems[index];
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: EnsureVisible(
                          alignment: 0.5,
                          child: _JellyfinPosterCard(item: item, accentColor: accent),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _JellyfinPosterCard extends StatefulWidget {
  final JellyfinItem item;
  final Color accentColor;

  const _JellyfinPosterCard({required this.item, required this.accentColor});

  @override
  State<_JellyfinPosterCard> createState() => _JellyfinPosterCardState();
}

class _JellyfinPosterCardState extends State<_JellyfinPosterCard> {
  late final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasFocus = _focusNode.hasPrimaryFocus;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Transform.scale(
        scale: hasFocus ? 1.06 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: hasFocus ? Border.all(color: widget.accentColor, width: 3.0) : Border.all(color: Colors.white24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Material(
              color: Colors.black54,
              child: InkWell(
                focusNode: _focusNode,
                focusColor: Colors.transparent,
                onTap: () => context.read<AppsService>().launchPackage("org.jellyfin.androidtv"),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      widget.item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.black45,
                        child: Icon(Icons.movie_outlined, color: widget.accentColor, size: 36),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                        child: Text(
                          widget.item.subtitle.isNotEmpty
                              ? "${widget.item.name} • ${widget.item.subtitle}"
                              : widget.item.name,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
