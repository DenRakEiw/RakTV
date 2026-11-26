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
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/ensure_visible.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HdmiInputsRow extends StatelessWidget {
  static const List<Map<String, dynamic>> _hdmiPorts = [
    {"port": 1, "title": "HDMI 1", "subtitle": "Console / PS5", "icon": Icons.sports_esports_outlined},
    {"port": 2, "title": "HDMI 2", "subtitle": "PC / Receiver", "icon": Icons.desktop_windows_outlined},
    {"port": 3, "title": "HDMI 3", "subtitle": "eARC / Media Box", "icon": Icons.settings_input_hdmi_outlined},
  ];

  @override
  Widget build(BuildContext context) => Consumer<SettingsService>(
        builder: (context, settings, _) {
          if (!settings.showHdmiCardsEnabled) {
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
                      Icon(Icons.settings_input_hdmi_outlined, color: accent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Direct HDMI Inputs",
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          shadows: [Shadow(color: Colors.black54, offset: Offset(1, 1), blurRadius: 8)],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _hdmiPorts.length,
                    itemBuilder: (context, index) {
                      final entry = _hdmiPorts[index];
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: EnsureVisible(
                          alignment: 0.5,
                          child: _HdmiInputCard(
                            port: entry["port"] as int,
                            title: entry["title"] as String,
                            subtitle: entry["subtitle"] as String,
                            icon: entry["icon"] as IconData,
                            accentColor: accent,
                            themePack: settings.iconThemePack,
                          ),
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

class _HdmiInputCard extends StatefulWidget {
  final int port;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String themePack;

  const _HdmiInputCard({
    required this.port,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.themePack,
  });

  @override
  State<_HdmiInputCard> createState() => _HdmiInputCardState();
}

class _HdmiInputCardState extends State<_HdmiInputCard> {
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
        scale: hasFocus ? 1.07 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: hasFocus ? Border.all(color: widget.accentColor, width: 3.0) : Border.all(color: Colors.white24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A192F).withOpacity(0.88),
                Color(0xFF020C1B).withOpacity(0.92),
              ],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                focusNode: _focusNode,
                focusColor: Colors.transparent,
                onTap: () => context.read<AppsService>().fLauncherChannel.switchHdmiInput(widget.port),
                child: widget.themePack != "default"
                    ? Image.asset(
                        "assets/themes/${widget.themePack}/hdmi${widget.port}.jpg",
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) => _buildDefaultContent(context),
                      )
                    : _buildDefaultContent(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultContent(BuildContext context) => Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: widget.accentColor, size: 32),
            SizedBox(height: 6),
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
}
