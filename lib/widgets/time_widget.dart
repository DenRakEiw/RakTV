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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/jellyfin_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class TimeWidget extends StatefulWidget {
  @override
  _TimeWidgetState createState() => _TimeWidgetState();
}

class _TimeWidgetState extends State<TimeWidget> {
  late DateTime _now;
  late Timer _timer;
  Timer? _hudTimer;
  int _ramPercent = 0;
  String? _temperature;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(Duration(seconds: 1), (_) => _refreshTime());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshHud();
      _fetchWeather();
    });
    _hudTimer = Timer.periodic(Duration(seconds: 15), (_) => _refreshHud());
  }

  @override
  void dispose() {
    _timer.cancel();
    _hudTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshHud() async {
    if (!mounted) return;
    try {
      final info = await context.read<AppsService>().getMemoryInfo();
      if (mounted) {
        setState(() {
          _ramPercent = info["usedPercent"] ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchWeather() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = Duration(seconds: 5);
      final uri = Uri.parse(
        "https://api.open-meteo.com/v1/forecast?latitude=51.16&longitude=10.45&current_weather=true",
      );
      final req = await client.getUrl(uri);
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final temp = data["current_weather"]?["temperature"];
        if (temp != null && mounted) {
          setState(() {
            _temperature = "${temp.round()}°C";
          });
        }
      }
      client.close();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Consumer2<SettingsService, JellyfinService>(
        builder: (context, settings, jellyfin, _) {
          final timeStr = settings.use24HourTimeFormat ? DateFormat.Hm().format(_now) : DateFormat.jm().format(_now);
          final accent = settings.neonAccentColor;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (settings.systemHudEnabled) ...[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_temperature != null) ...[
                        Icon(Icons.wb_sunny_outlined, size: 14, color: Colors.amberAccent),
                        SizedBox(width: 4),
                        Text(_temperature!, style: Theme.of(context).textTheme.bodySmall),
                        SizedBox(width: 10),
                      ],
                      if (_ramPercent > 0) ...[
                        Icon(Icons.memory, size: 14, color: accent),
                        SizedBox(width: 4),
                        Text("RAM $_ramPercent%", style: Theme.of(context).textTheme.bodySmall),
                      ],
                      if (jellyfin.serverOnline) ...[
                        SizedBox(width: 10),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF00FF87),
                          ),
                        ),
                        SizedBox(width: 4),
                        Text("JF", style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 14),
              ],
              Text(
                timeStr,
                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  shadows: [Shadow(color: Colors.black54, offset: Offset(1, 1), blurRadius: 8)],
                ),
                textAlign: TextAlign.end,
              ),
            ],
          );
        },
      );

  void _refreshTime() {
    setState(() {
      _now = DateTime.now();
    });
  }
}
