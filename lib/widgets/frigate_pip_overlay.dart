/*
 * RakTV (based on FLauncher)
 * Copyright (C) 2026  DenRakEiw
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'package:flauncher/providers/frigate_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FrigatePipOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Consumer2<FrigateService, SettingsService>(
        builder: (context, frigate, settings, _) {
          if (!frigate.pipVisible || frigate.currentFrameUrl.isEmpty) {
            return SizedBox.shrink();
          }
          final accent = settings.neonAccentColor;

          return Material(
            color: Colors.transparent,
            child: Container(
              width: 320,
              height: 195,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent, width: 2.5),
                boxShadow: [
                  BoxShadow(color: Colors.black87, blurRadius: 16, spreadRadius: 2),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      frigate.currentFrameUrl,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.black87,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam_outlined, color: accent, size: 36),
                            SizedBox(height: 6),
                            Text(
                              "Frigate • ${frigate.activeCamera}",
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "${frigate.activeAlertText} (${frigate.activeCamera})",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}
