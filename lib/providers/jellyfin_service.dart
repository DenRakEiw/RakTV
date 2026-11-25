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
import 'package:path_provider/path_provider.dart';

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
  String _localConfigUrl = "";
  String _localConfigKey = "";
  final List<String> _discoveredServers = [];
  int _discoveredIndex = 0;
  List<JellyfinItem> _latestItems = [];

  bool get serverOnline => _serverOnline;
  String get serverName => _serverName;
  String get activeServerUrl {
    final configured = _settingsService?.jellyfinServerUrl ?? "";
    if (configured.isNotEmpty) return configured;
    if (_localConfigUrl.isNotEmpty) return _localConfigUrl;
    return _discoveredUrl;
  }

  String get activeApiKey {
    final configured = _settingsService?.jellyfinApiKey ?? "";
    if (configured.isNotEmpty) return configured;
    return _localConfigKey;
  }

  List<JellyfinItem> get latestItems => List.unmodifiable(_latestItems);

  set settingsService(SettingsService settings) {
    if (_settingsService != settings) {
      _settingsService?.removeListener(_onSettingsChanged);
      _settingsService = settings;
      _settingsService?.addListener(_onSettingsChanged);
      refresh();
    }
  }

  void _onSettingsChanged() {
    refresh();
  }

  JellyfinService() {
    _init();
  }

  @override
  void dispose() {
    _settingsService?.removeListener(_onSettingsChanged);
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadLocalConfig();
    if (_localConfigUrl.isEmpty) {
      await discoverOnLan();
    }
    await refresh();
    _pollTimer = Timer.periodic(Duration(minutes: 2), (_) => refresh());
  }

  Future<void> _loadLocalConfig() async {
    final paths = <String>[
      "/sdcard/Android/data/com.denrakeiw.raktv/files/jellyfin.json",
      "/storage/emulated/0/Android/data/com.denrakeiw.raktv/files/jellyfin.json",
      "/sdcard/Download/.raktv_jellyfin.json",
      "/sdcard/Pictures/.raktv_jellyfin.json",
    ];
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        paths.insert(0, "${extDir.path}/jellyfin.json");
      }
    } catch (_) {}
    for (final p in paths) {
      try {
        final f = File(p);
        if (await f.exists()) {
          final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
          _localConfigUrl = (map["serverUrl"] ?? "").toString().trim();
          _localConfigKey = (map["apiKey"] ?? "").toString().trim();
          if (_localConfigUrl.isNotEmpty) break;
        }
      } catch (_) {}
    }
  }

  Future<void> discoverOnLan() async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      final data = utf8.encode("who is JellyfinServer?");
      socket.send(data, InternetAddress("255.255.255.255"), 7359);

      final found = <String>[];
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
              if (addr.isNotEmpty && !found.contains(addr)) {
                found.add(addr);
                _serverName = name;
                _serverOnline = true;
              }
            } catch (_) {}
          }
        }
      });

      await Future.delayed(Duration(milliseconds: 900));
      await sub.cancel();
      socket.close();

      if (found.isNotEmpty) {
        _discoveredServers
          ..clear()
          ..addAll(found);
        _discoveredIndex = (_discoveredIndex + 1) % _discoveredServers.length;
        _discoveredUrl = _discoveredServers[_discoveredIndex];
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> refresh() async {
    if (_settingsService?.jellyfinEnabled == false) return;
    if (_localConfigUrl.isEmpty) {
      await _loadLocalConfig();
    }
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

      final apiKey = activeApiKey;
      if (_serverOnline && apiKey.isNotEmpty) {
        final itemsUri = Uri.parse(
          "$baseUrl/Items?Recursive=true&IncludeItemTypes=Movie,Episode,Series"
          "&Fields=Path&SortBy=DateCreated&SortOrder=Descending&Limit=2000",
        );
        final itemsReq = await client.getUrl(itemsUri);
        itemsReq.headers.add("Authorization", 'MediaBrowser Token="$apiKey"');
        itemsReq.headers.add("X-Emby-Token", apiKey);
        final itemsResp = await itemsReq.close();
        if (itemsResp.statusCode == 200) {
          final itemsBody = await itemsResp.transform(utf8.decoder).join();
          final itemsJson = jsonDecode(itemsBody) as Map<String, dynamic>;
          final list = (itemsJson["Items"] as List<dynamic>?) ?? [];
          final parsed = <JellyfinItem>[];
          final seenSeries = <String>{};
          for (final raw in list) {
            final item = raw as Map<String, dynamic>;
            final id = (item["Id"] ?? "").toString();
            final path = (item["Path"] ?? "").toString().toLowerCase();
            if (path.isNotEmpty &&
                !path.endsWith(".mkv") &&
                !path.endsWith(".mp4") &&
                !path.endsWith(".avi") &&
                !path.endsWith(".m4v") &&
                !path.endsWith(".mov") &&
                !path.endsWith(".webm") &&
                !path.endsWith(".strm")) {
              continue;
            }
            String rawName = (item["SeriesName"] ?? item["Name"] ?? "").toString().trim();
            String epName = item["SeriesName"] != null
                ? (item["Name"] ?? "").toString()
                : (item["ProductionYear"] ?? "").toString();
            final sMatch = RegExp(r'^(.+?)\.(S\d+E\d+)$', caseSensitive: false).firstMatch(rawName);
            if (sMatch != null) {
              rawName = sMatch.group(1)!.replaceAll('.', ' ');
              epName = sMatch.group(2)!.toUpperCase();
            } else {
              final mMatch = RegExp(r'^(.+?)\.(19\d\d|20\d\d)\.', caseSensitive: false).firstMatch(rawName);
              if (mMatch != null) {
                rawName = mMatch.group(1)!.replaceAll('.', ' ');
                if (epName.isEmpty) epName = mMatch.group(2)!;
              }
            }
            if (id.isEmpty || rawName.isEmpty || seenSeries.contains(rawName.toLowerCase())) {
              continue;
            }
            final tags = (item["ImageTags"] as Map<String, dynamic>?) ?? {};
            final imgType = tags.containsKey("Thumb")
                ? "Thumb"
                : (tags.containsKey("Primary") ? "Primary" : "");
            if (imgType.isEmpty) continue;
            seenSeries.add(rawName.toLowerCase());
            parsed.add(
              JellyfinItem(
                id: id,
                name: rawName,
                subtitle: epName,
                imageUrl: "$baseUrl/Items/$id/Images/$imgType?maxHeight=320&quality=85",
              ),
            );
            if (parsed.length >= 12) break;
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
