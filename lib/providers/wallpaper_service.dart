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
import 'dart:math';

import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/gradients.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/unsplash_service.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class WallpaperService extends ChangeNotifier {
  final ImagePicker _imagePicker;
  final FLauncherChannel _fLauncherChannel;
  final UnsplashService _unsplashService;
  SettingsService? _settingsService;
  Timer? _autoRotateTimer;
  final Random _random = Random();

  late File _wallpaperFile;
  bool _fileInitialized = false;
  Uint8List? _wallpaper;
  String? _activeVideoPath;
  String? _currentWallpaperCaption;
  String? _lastRedditImageUrl;
  bool _isLoadingReddit = false;

  Uint8List? get wallpaperBytes => _wallpaper;
  String? get activeVideoPath => _activeVideoPath;
  String? get currentWallpaperCaption => _currentWallpaperCaption;
  bool get isLoadingReddit => _isLoadingReddit;

  FLauncherGradient get gradient => FLauncherGradients.all.firstWhere(
        (gradient) => gradient.uuid == _settingsService?.gradientUuid,
        orElse: () => FLauncherGradients.greatWhale,
      );

  set settingsService(SettingsService settingsService) {
    final prevInterval = _settingsService?.wallpaperIntervalMinutes;
    final prevVault = _settingsService?.vaultUnlocked;
    _settingsService = settingsService;
    if (prevInterval != settingsService.wallpaperIntervalMinutes) {
      _setupAutoRotateTimer();
    }
    if (prevVault != null && prevVault != settingsService.vaultUnlocked) {
      if (settingsService.wallpaperSource == "reddit") {
        fetchRedditWallpaper(
          settingsService.vaultUnlocked ? settingsService.vaultSubreddit : settingsService.redditSubreddit,
        );
      }
    }
    if (settingsService.wallpaperSource == "video" && settingsService.videoWallpaperPath != null) {
      _activeVideoPath = settingsService.videoWallpaperPath;
    } else if (settingsService.wallpaperSource != "video") {
      _activeVideoPath = null;
    }
  }

  WallpaperService(this._imagePicker, this._fLauncherChannel, this._unsplashService) {
    _init();
  }

  @override
  void dispose() {
    _autoRotateTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final directory = await getApplicationDocumentsDirectory();
    _wallpaperFile = File("${directory.path}/wallpaper");
    _fileInitialized = true;
    if (await _wallpaperFile.exists()) {
      _wallpaper = await _wallpaperFile.readAsBytes();
      notifyListeners();
    } else {
      final seeded = File("/sdcard/Pictures/waifu_4k_1.jpg");
      if (await seeded.exists()) {
        final bytes = await seeded.readAsBytes();
        await _wallpaperFile.writeAsBytes(bytes);
        _wallpaper = bytes;
        _currentWallpaperCaption = "4K Anime Wallpaper";
        notifyListeners();
      } else {
        unawaited(fetchRedditWallpaper("Moescape"));
      }
    }
    _setupAutoRotateTimer();
  }

  void _setupAutoRotateTimer() {
    _autoRotateTimer?.cancel();
    final minutes = _settingsService?.wallpaperIntervalMinutes ?? 15;
    if (minutes > 0) {
      _autoRotateTimer = Timer.periodic(Duration(minutes: minutes), (_) => rotateWallpaperNow());
    }
  }

  Future<void> rotateWallpaperNow() async {
    final settings = _settingsService;
    if (settings == null) return;
    if (settings.wallpaperSource == "reddit") {
      final sub = settings.vaultUnlocked ? settings.vaultSubreddit : settings.redditSubreddit;
      await fetchRedditWallpaper(sub);
    } else if (settings.wallpaperSource == "local_folder") {
      await nextLocalFolderWallpaper();
    }
  }

  Future<bool> fetchRedditWallpaper([String? customSubreddit]) async {
    if (_isLoadingReddit) return false;
    _isLoadingReddit = true;
    notifyListeners();

    final rawSub = customSubreddit ??
        (_settingsService?.vaultUnlocked == true
            ? _settingsService?.vaultSubreddit
            : _settingsService?.redditSubreddit) ??
        "AnimeWallpaper";
    final subs = rawSub.split(",").map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final sub = subs.isEmpty ? "AnimeWallpaper" : subs[_random.nextInt(subs.length)];

    try {
      final client = HttpClient();
      client.connectionTimeout = Duration(seconds: 10);
      client.userAgent = "Mozilla/5.0 (Linux; Android 12; TV) RakTV/1.0";

      final uri = Uri.parse("https://www.reddit.com/r/$sub/hot.json?limit=60&raw_json=1");
      final req = await client.getUrl(uri);
      req.headers.add("Cookie", "over18=1");
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final children = (data["data"]?["children"] as List<dynamic>?) ?? [];

        final candidates = <Map<String, String>>[];
        for (final item in children) {
          final post = item["data"] as Map<String, dynamic>?;
          if (post == null) continue;
          final url = (post["url_overridden_by_dest"] ?? post["url"] ?? "").toString();
          final title = (post["title"] ?? "r/$sub").toString();
          if (_isImageUrl(url) && url != _lastRedditImageUrl) {
            candidates.add({"url": url, "title": title});
          } else {
            final previewUrl = post["preview"]?["images"]?[0]?["source"]?["url"]?.toString();
            if (previewUrl != null && previewUrl.isNotEmpty && previewUrl != _lastRedditImageUrl) {
              candidates.add({"url": previewUrl, "title": title});
            }
          }
        }

        if (candidates.isNotEmpty) {
          final chosen = candidates[_random.nextInt(candidates.length)];
          final imgUri = Uri.parse(chosen["url"]!);
          final imgReq = await client.getUrl(imgUri);
          final imgResp = await imgReq.close();
          if (imgResp.statusCode == 200) {
            final bytes = await consolidateHttpClientResponseBytes(imgResp);
            if (bytes.isNotEmpty) {
              if (_fileInitialized) {
                await _wallpaperFile.writeAsBytes(bytes);
              }
              _wallpaper = bytes;
              _activeVideoPath = null;
              _lastRedditImageUrl = chosen["url"];
              _currentWallpaperCaption = "r/$sub • ${chosen["title"]}";
              await _settingsService?.setWallpaperSource("reddit");
              _isLoadingReddit = false;
              client.close();
              notifyListeners();
              return true;
            }
          }
        }
      }
      client.close();
    } catch (e) {
      debugPrint("Reddit wallpaper fetch error: $e");
    }
    // Fallback to Wallhaven 16:9 4K Anime API if Reddit rate-limits or age-gates the subreddit
    final whOk = await fetchWallhavenAnimeWallpaper();
    _isLoadingReddit = false;
    notifyListeners();
    return whOk;
  }

  Future<bool> fetchWallhavenAnimeWallpaper([String query = ""]) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = Duration(seconds: 10);
      client.userAgent = "Mozilla/5.0 (Linux; Android 12; TV) RakTV/1.0";
      final qParam = query.isNotEmpty ? "&q=${Uri.encodeQueryComponent(query)}" : "";
      final uri = Uri.parse(
        "https://wallhaven.cc/api/v1/search?categories=010&purity=100&atleast=1920x1080&ratios=16x9&sorting=random$qParam",
      );
      final req = await client.getUrl(uri);
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final items = (data["data"] as List<dynamic>?) ?? [];
        if (items.isNotEmpty) {
          final item = items[_random.nextInt(items.length)] as Map<String, dynamic>;
          final imgUrl = (item["path"] ?? "").toString();
          final res = (item["resolution"] ?? "4K").toString();
          if (imgUrl.isNotEmpty) {
            final imgReq = await client.getUrl(Uri.parse(imgUrl));
            final imgResp = await imgReq.close();
            if (imgResp.statusCode == 200) {
              final bytes = await consolidateHttpClientResponseBytes(imgResp);
              if (bytes.isNotEmpty) {
                if (_fileInitialized) {
                  await _wallpaperFile.writeAsBytes(bytes);
                }
                _wallpaper = bytes;
                _activeVideoPath = null;
                _currentWallpaperCaption = "Wallhaven 4K Anime ($res)";
                client.close();
                return true;
              }
            }
          }
        }
      }
      client.close();
    } catch (e) {
      debugPrint("Wallhaven fetch error: $e");
    }
    return false;
  }

  bool _isImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith(".jpg") ||
        lower.endsWith(".jpeg") ||
        lower.endsWith(".png") ||
        lower.endsWith(".webp") ||
        lower.endsWith(".gif");
  }

  Future<bool> nextLocalFolderWallpaper() async {
    final folder = _settingsService?.localWallpaperFolder ?? "/sdcard/Pictures";
    final files = await _fLauncherChannel.listLocalMedia(folder);
    if (files.isEmpty) return false;
    final chosenPath = files[_random.nextInt(files.length)];
    return await setLocalFileAsWallpaper(chosenPath);
  }

  Future<bool> setLocalFileAsWallpaper(String filePath) async {
    try {
      final lower = filePath.toLowerCase();
      if (lower.endsWith(".mp4") || lower.endsWith(".webm") || lower.startsWith("http")) {
        _activeVideoPath = filePath;
        _currentWallpaperCaption = "Live Video • ${filePath.split('/').last}";
        await _settingsService?.setVideoWallpaperPath(filePath);
        notifyListeners();
        return true;
      } else {
        final file = File(filePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          if (_fileInitialized) {
            await _wallpaperFile.writeAsBytes(bytes);
          }
          _wallpaper = bytes;
          _activeVideoPath = null;
          _currentWallpaperCaption = "Local • ${filePath.split('/').last}";
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint("Local wallpaper error: $e");
    }
    return false;
  }

  Future<List<String>> scanLocalMediaFiles([String? folder]) =>
      _fLauncherChannel.listLocalMedia(folder ?? _settingsService?.localWallpaperFolder);

  Future<void> pickWallpaper() async {
    if (!await _fLauncherChannel.checkForGetContentAvailability()) {
      throw NoFileExplorerException();
    }
    final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      if (_fileInitialized) {
        await _wallpaperFile.writeAsBytes(bytes);
      }
      _wallpaper = bytes;
      _activeVideoPath = null;
      await _settingsService?.setUnsplashAuthor(null);
      await _settingsService?.setWallpaperSource("custom");
      notifyListeners();
    }
  }

  Future<void> randomFromUnsplash(String query) async {
    final photo = await _unsplashService.randomPhoto(query);
    final bytes = await _unsplashService.downloadPhoto(photo);
    if (_fileInitialized) {
      await _wallpaperFile.writeAsBytes(bytes);
    }
    _wallpaper = bytes;
    _activeVideoPath = null;
    await _settingsService
        ?.setUnsplashAuthor(jsonEncode({"username": photo.username, "link": photo.userLink.toString()}));
    notifyListeners();
  }

  Future<List<Photo>> searchFromUnsplash(String query) => _unsplashService.searchPhotos(query);

  Future<void> setFromUnsplash(Photo photo) async {
    final bytes = await _unsplashService.downloadPhoto(photo);
    if (_fileInitialized) {
      await _wallpaperFile.writeAsBytes(bytes);
    }
    _wallpaper = bytes;
    _activeVideoPath = null;
    await _settingsService
        ?.setUnsplashAuthor(jsonEncode({"username": photo.username, "link": photo.userLink.toString()}));
    notifyListeners();
  }

  Future<void> setGradient(FLauncherGradient fLauncherGradient) async {
    if (_fileInitialized && await _wallpaperFile.exists()) {
      await _wallpaperFile.delete();
    }
    _wallpaper = null;
    _activeVideoPath = null;
    _currentWallpaperCaption = null;
    await _settingsService?.setUnsplashAuthor(null);
    await _settingsService?.setGradientUuid(fLauncherGradient.uuid);
    await _settingsService?.setWallpaperSource("gradient");
    notifyListeners();
  }
}

class NoFileExplorerException implements Exception {}
