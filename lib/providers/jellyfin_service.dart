/*
 * RakTV (based on FLauncher)
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

import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/foundation.dart';

class JellyfinItem {
  final String id;
  final String name;
  final String subtitle;
  final String imageUrl;

  JellyfinItem({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.imageUrl,
  });
}

class JellyfinService extends ChangeNotifier {
  SettingsService? _settingsService;
  Timer? _pollTimer;

  bool _serverOnline = false;
  String _serverName = "Jellyfin";
  String _discoveredUrl = "";
  List<JellyfinItem> _latestItems = [];

  bool get serverOnline => _serverOnline;
  String get serverName => _serverName;
  String get activeServerUrl {
    final configured = _settingsService?.jellyfinServerUrl ?? "";
    return configured.isNotEmpty ? configured : _discoveredUrl;
  }

  List<JellyfinItem> get latestItems => List.unmodifiable(_latestItems);

  set settingsService(SettingsService settings) {
    final oldUrl = _settingsService?.jellyfinServerUrl;
    final oldKey = _settingsService?.jellyfinApiKey;
    _settingsService = settings;
    if (oldUrl != settings.jellyfinServerUrl || oldKey != settings.jellyfinApiKey) {
      refresh();
    }
  }

  JellyfinService() {
    _init();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await discoverOnLan();
    await refresh();
    _pollTimer = Timer.periodic(Duration(minutes: 2), (_) => refresh());
  }

  Future<void> discoverOnLan() async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      final data = utf8.encode("who is JellyfinServer?");
      socket.send(data, InternetAddress("255.255.255.255"), 7359);

      final completer = Completer<void>();
      late StreamSubscription sub;
      sub = socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final dg = socket.receive();
          if (dg != null) {
            try {
              final msg = utf8.decode(dg.data);
              final json = jsonDecode(msg) as Map<String, dynamic>;
              final addr = (json["Address"] ?? "").toString();
              final name = (json["Name"] ?? "Jellyfin").toString();
              if (addr.isNotEmpty) {
                _discoveredUrl = addr;
                _serverName = name;
                _serverOnline = true;
                notifyListeners();
                if (!completer.isCompleted) completer.complete();
              }
            } catch (_) {}
          }
        }
      });

      await completer.future.timeout(Duration(seconds: 2), onTimeout: () {});
      await sub.cancel();
      socket.close();
    } catch (_) {}
  }

  Future<void> refresh() async {
    if (_settingsService?.jellyfinEnabled == false) return;
    if (activeServerUrl.isEmpty) {
      await discoverOnLan();
    }
    final baseUrl = activeServerUrl.replaceAll(RegExp(r'/$'), '');
    if (baseUrl.isEmpty) {
      _serverOnline = false;
      notifyListeners();
      return;
    }

    try {
      final client = HttpClient();
      client.connectionTimeout = Duration(seconds: 4);
      final infoUri = Uri.parse("$baseUrl/System/Info/Public");
      final req = await client.getUrl(infoUri);
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final info = jsonDecode(body) as Map<String, dynamic>;
        _serverName = (info["ServerName"] ?? "Jellyfin").toString();
        _serverOnline = true;
      } else {
        _serverOnline = false;
      }

      final apiKey = _settingsService?.jellyfinApiKey ?? "";
      if (_serverOnline && apiKey.isNotEmpty) {
        final itemsUri = Uri.parse(
          "$baseUrl/Items?Recursive=true&IncludeItemTypes=Movie,Episode,Series"
          "&SortBy=DateCreated&SortOrder=Descending&Limit=12",
        );
        final itemsReq = await client.getUrl(itemsUri);
        itemsReq.headers.add("X-Emby-Token", apiKey);
        final itemsResp = await itemsReq.close();
        if (itemsResp.statusCode == 200) {
          final itemsBody = await itemsResp.transform(utf8.decoder).join();
          final itemsJson = jsonDecode(itemsBody) as Map<String, dynamic>;
          final list = (itemsJson["Items"] as List<dynamic>?) ?? [];
          final parsed = <JellyfinItem>[];
          for (final raw in list) {
            final item = raw as Map<String, dynamic>;
            final id = (item["Id"] ?? "").toString();
            final name = (item["SeriesName"] ?? item["Name"] ?? "").toString();
            final epName = item["SeriesName"] != null ? (item["Name"] ?? "").toString() : (item["ProductionYear"] ?? "").toString();
            if (id.isNotEmpty && name.isNotEmpty) {
              parsed.add(
                JellyfinItem(
                  id: id,
                  name: name,
                  subtitle: epName,
                  imageUrl: "$baseUrl/Items/$id/Images/Primary?maxHeight=320&quality=85",
                ),
              );
            }
          }
          _latestItems = parsed;
        }
      }
      client.close();
    } catch (_) {
      _serverOnline = false;
    }
    notifyListeners();
  }
}
