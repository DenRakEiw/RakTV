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

class FrigateService extends ChangeNotifier {
  SettingsService? _settingsService;
  Timer? _eventPollTimer;
  Timer? _pipFrameTimer;
  Timer? _pipHideTimer;

  String _discoveredUrl = "";
  String _localConfigUrl = "";
  List<String> _cameras = [];
  String? _lastEventId;
  bool _initializedEventId = false;

  bool _pipVisible = false;
  String _activeCamera = "";
  String _activeAlertText = "";
  int _frameTick = 0;

  bool get pipVisible => _pipVisible;
  String get activeCamera => _activeCamera;
  String get activeAlertText => _activeAlertText;
  List<String> get cameras => List.unmodifiable(_cameras);

  String get activeServerUrl {
    final configured = _settingsService?.frigateServerUrl ?? "";
    if (configured.isNotEmpty) return configured;
    if (_localConfigUrl.isNotEmpty) return _localConfigUrl;
    return _discoveredUrl;
  }

  String get currentFrameUrl {
    final base = activeServerUrl.replaceAll(RegExp(r'/$'), '');
    if (base.isEmpty || _activeCamera.isEmpty) return "";
    return "$base/api/$_activeCamera/latest.jpg?h=360&t=$_frameTick";
  }

  set settingsService(SettingsService settings) {
    if (_settingsService != settings) {
      _settingsService?.removeListener(_onSettingsChanged);
      _settingsService = settings;
      _settingsService?.addListener(_onSettingsChanged);
    }
  }

  void _onSettingsChanged() {
    if (_settingsService?.frigateAlertsEnabled == false && _pipVisible) {
      dismissPip();
    }
  }

  FrigateService() {
    _init();
  }

  @override
  void dispose() {
    _settingsService?.removeListener(_onSettingsChanged);
    _eventPollTimer?.cancel();
    _pipFrameTimer?.cancel();
    _pipHideTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadLocalConfig();
    if (activeServerUrl.isEmpty) {
      await discoverOnLan();
    } else {
      await _fetchCameras(activeServerUrl);
    }
    _eventPollTimer = Timer.periodic(Duration(seconds: 6), (_) => _pollPersonEvents());
  }

  Future<void> _loadLocalConfig() async {
    final paths = <String>[
      "/sdcard/Android/data/com.denrakeiw.raktv/files/frigate.json",
      "/storage/emulated/0/Android/data/com.denrakeiw.raktv/files/frigate.json",
      "/sdcard/Download/.raktv_frigate.json",
    ];
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        paths.insert(0, "${extDir.path}/frigate.json");
      }
    } catch (_) {}
    for (final p in paths) {
      try {
        final f = File(p);
        if (await f.exists()) {
          final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
          _localConfigUrl = (map["serverUrl"] ?? "").toString().trim();
          if (_localConfigUrl.isNotEmpty) break;
        }
      } catch (_) {}
    }
  }

  Future<void> discoverOnLan() async {
    try {
      String subnetPrefix = "";
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.contains(".")) {
            final parts = addr.address.split(".");
            if (parts.length == 4) {
              subnetPrefix = "${parts[0]}.${parts[1]}.${parts[2]}";
              break;
            }
          }
        }
        if (subnetPrefix.isNotEmpty) break;
      }
      if (subnetPrefix.isEmpty) return;

      // Probe port 5000 across subnet in fast batches
      for (int batchStart = 1; batchStart <= 254; batchStart += 32) {
        final futures = <Future<String?>>[];
        final batchEnd = (batchStart + 31).clamp(1, 254);
        for (int i = batchStart; i <= batchEnd; i++) {
          final host = "$subnetPrefix.$i";
          futures.add(_probeFrigateHost(host));
        }
        final results = await Future.wait(futures);
        final hit = results.firstWhere((r) => r != null, orElse: () => null);
        if (hit != null) {
          _discoveredUrl = hit;
          await _fetchCameras(hit);
          notifyListeners();
          return;
        }
      }
    } catch (_) {}
  }

  Future<String?> _probeFrigateHost(String host) async {
    try {
      final socket = await Socket.connect(host, 5000, timeout: Duration(milliseconds: 280));
      socket.destroy();
      final client = HttpClient()..connectionTimeout = Duration(seconds: 2);
      final req = await client.getUrl(Uri.parse("http://$host:5000/api/version"));
      final resp = await req.close();
      client.close();
      if (resp.statusCode == 200) {
        return "http://$host:5000";
      }
    } catch (_) {}
    return null;
  }

  Future<void> _fetchCameras(String baseUrl) async {
    final clean = baseUrl.replaceAll(RegExp(r'/$'), '');
    if (clean.isEmpty) return;
    try {
      final client = HttpClient()..connectionTimeout = Duration(seconds: 3);
      final req = await client.getUrl(Uri.parse("$clean/api/config"));
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final cfg = jsonDecode(body) as Map<String, dynamic>;
        final camsMap = cfg["cameras"] as Map<String, dynamic>?;
        if (camsMap != null && camsMap.isNotEmpty) {
          _cameras = camsMap.keys.toList();
          if (_activeCamera.isEmpty) {
            _activeCamera = _cameras.first;
          }
        }
      }
      client.close();
    } catch (_) {}
  }

  Future<void> _pollPersonEvents() async {
    if (_settingsService?.frigateAlertsEnabled == false) return;
    final base = activeServerUrl.replaceAll(RegExp(r'/$'), '');
    if (base.isEmpty) return;

    try {
      final client = HttpClient()..connectionTimeout = Duration(seconds: 3);
      final req = await client.getUrl(Uri.parse("$base/api/events?label=person&limit=1"));
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final events = jsonDecode(body) as List<dynamic>;
        if (events.isNotEmpty) {
          final ev = events.first as Map<String, dynamic>;
          final id = (ev["id"] ?? "").toString();
          final cam = (ev["camera"] ?? "").toString();
          final scoreNum = (ev["data"]?["score"] ?? ev["top_score"] ?? 0.85);
          final pct = scoreNum is num ? (scoreNum * 100).round() : 85;
          if (!_initializedEventId) {
            _lastEventId = id;
            _initializedEventId = true;
          } else if (id.isNotEmpty && id != _lastEventId) {
            _lastEventId = id;
            showCameraPip(
              camera: cam.isNotEmpty ? cam : (_cameras.isNotEmpty ? _cameras.first : "front_door"),
              alertText: "🚨 PERSON DETECTED • $pct%",
              durationSeconds: 10,
            );
          }
        } else {
          _initializedEventId = true;
        }
      }
      client.close();
    } catch (_) {}
  }

  Future<void> showCameraPip({
    String? camera,
    String alertText = "📹 LIVE CAMERA PREVIEW",
    int durationSeconds = 10,
  }) async {
    final base = activeServerUrl.replaceAll(RegExp(r'/$'), '');
    if (base.isEmpty) {
      await discoverOnLan();
    }
    if (_cameras.isEmpty && activeServerUrl.isNotEmpty) {
      await _fetchCameras(activeServerUrl);
    }
    _activeCamera = camera ?? (_cameras.isNotEmpty ? _cameras.first : "camera");
    _activeAlertText = alertText;
    _pipVisible = true;
    _frameTick = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();

    _pipFrameTimer?.cancel();
    _pipFrameTimer = Timer.periodic(Duration(milliseconds: 900), (_) {
      if (_pipVisible) {
        _frameTick = DateTime.now().millisecondsSinceEpoch;
        notifyListeners();
      }
    });

    _pipHideTimer?.cancel();
    _pipHideTimer = Timer(Duration(seconds: durationSeconds), () {
      dismissPip();
    });
  }

  void dismissPip() {
    _pipFrameTimer?.cancel();
    _pipHideTimer?.cancel();
    if (_pipVisible) {
      _pipVisible = false;
      notifyListeners();
    }
  }
}
