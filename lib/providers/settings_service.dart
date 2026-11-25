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

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _use24HourTimeFormatKey = "use_24_hour_time_format";
const _appHighlightAnimationEnabledKey = "app_highlight_animation_enabled";
const _gradientUuidKey = "gradient_uuid";
const _unsplashAuthorKey = "unsplash_author";

// RakTV Custom Keys
const _redditSubredditKey = "raktv_reddit_subreddit";
const _vaultSubredditKey = "raktv_vault_subreddit";
const _wallpaperSourceKey = "raktv_wallpaper_source"; // 'reddit', 'local_folder', 'video', 'custom', 'gradient'
const _wallpaperIntervalMinutesKey = "raktv_wallpaper_interval_minutes";
const _localWallpaperFolderKey = "raktv_local_wallpaper_folder";
const _videoWallpaperPathKey = "raktv_video_wallpaper_path";
const _posterIdleSecondsKey = "raktv_poster_idle_seconds";
const _glassNeonEnabledKey = "raktv_glass_neon_enabled";
const _neonAccentColorKey = "raktv_neon_accent_color";
const _customFontFamilyKey = "raktv_custom_font_family";
const _nightDimmerLevelKey = "raktv_night_dimmer_level";
const _lockedPackagesKey = "raktv_locked_packages";
const _vaultPackagesKey = "raktv_vault_packages";
const _jellyfinEnabledKey = "raktv_jellyfin_enabled";
const _jellyfinServerUrlKey = "raktv_jellyfin_server_url";
const _jellyfinApiKeyKey = "raktv_jellyfin_api_key";
const _systemHudEnabledKey = "raktv_system_hud_enabled";
const _ps5BackdropPreviewKey = "raktv_ps5_backdrop_preview_enabled";
const _autoNightShiftKey = "raktv_auto_night_shift_enabled";
const _showHdmiCardsKey = "raktv_show_hdmi_cards_enabled";
const _frigateAlertsKey = "raktv_frigate_alerts_enabled";
const _frigateServerUrlKey = "raktv_frigate_server_url";

class SettingsService extends ChangeNotifier {
  final SharedPreferences _sharedPreferences;
  bool _vaultUnlocked = false;

  bool get crashReportsEnabled => false;
  bool get analyticsEnabled => false;
  bool get unsplashEnabled => false;

  bool get use24HourTimeFormat => _sharedPreferences.getBool(_use24HourTimeFormatKey) ?? true;
  bool get appHighlightAnimationEnabled => _sharedPreferences.getBool(_appHighlightAnimationEnabledKey) ?? false;
  String? get gradientUuid => _sharedPreferences.getString(_gradientUuidKey);
  String? get unsplashAuthor => _sharedPreferences.getString(_unsplashAuthorKey);

  // RakTV Getters
  String get redditSubreddit => _sharedPreferences.getString(_redditSubredditKey) ?? "AnimeWallpaper";
  String get vaultSubreddit => _sharedPreferences.getString(_vaultSubredditKey) ?? "Waifu";
  String get wallpaperSource => _sharedPreferences.getString(_wallpaperSourceKey) ?? "reddit";
  int get wallpaperIntervalMinutes => _sharedPreferences.getInt(_wallpaperIntervalMinutesKey) ?? 15;
  String get localWallpaperFolder => _sharedPreferences.getString(_localWallpaperFolderKey) ?? "/sdcard/Pictures";
  String? get videoWallpaperPath => _sharedPreferences.getString(_videoWallpaperPathKey);
  int get posterIdleSeconds => _sharedPreferences.getInt(_posterIdleSecondsKey) ?? 60;
  bool get glassNeonEnabled => _sharedPreferences.getBool(_glassNeonEnabledKey) ?? true;
  int get neonAccentColorValue => _sharedPreferences.getInt(_neonAccentColorKey) ?? 0xFFFF2A85;
  Color get neonAccentColor => Color(neonAccentColorValue);
  String get customFontFamily => _sharedPreferences.getString(_customFontFamilyKey) ?? "Roboto";
  double get nightDimmerLevel => _sharedPreferences.getDouble(_nightDimmerLevelKey) ?? 0.15;

  List<String> get lockedPackages => _sharedPreferences.getStringList(_lockedPackagesKey) ?? [];
  List<String> get vaultPackages => _sharedPreferences.getStringList(_vaultPackagesKey) ?? [];
  bool get vaultUnlocked => _vaultUnlocked;

  bool get jellyfinEnabled => _sharedPreferences.getBool(_jellyfinEnabledKey) ?? true;
  String get jellyfinServerUrl => _sharedPreferences.getString(_jellyfinServerUrlKey) ?? "";
  String get jellyfinApiKey => _sharedPreferences.getString(_jellyfinApiKeyKey) ?? "";
  bool get systemHudEnabled => _sharedPreferences.getBool(_systemHudEnabledKey) ?? false;
  bool get ps5BackdropPreviewEnabled => _sharedPreferences.getBool(_ps5BackdropPreviewKey) ?? true;
  bool get autoNightShiftEnabled => _sharedPreferences.getBool(_autoNightShiftKey) ?? false;
  bool get showHdmiCardsEnabled => _sharedPreferences.getBool(_showHdmiCardsKey) ?? false;
  bool get frigateAlertsEnabled => _sharedPreferences.getBool(_frigateAlertsKey) ?? true;
  String get frigateServerUrl => _sharedPreferences.getString(_frigateServerUrlKey) ?? "";

  bool get isAutoNightShiftActive {
    if (!autoNightShiftEnabled) return false;
    final h = DateTime.now().hour;
    return h >= 22 || h < 7;
  }

  double get effectiveNightDimmerLevel {
    if (isAutoNightShiftActive) {
      return nightDimmerLevel < 0.40 ? 0.40 : nightDimmerLevel;
    }
    return nightDimmerLevel;
  }

  SettingsService(this._sharedPreferences);

  bool isAppLocked(String packageName) => lockedPackages.contains(packageName);

  bool isVaultApp(String packageName) => vaultPackages.contains(packageName);

  Future<void> toggleAppLock(String packageName) async {
    final current = List<String>.from(lockedPackages);
    if (current.contains(packageName)) {
      current.remove(packageName);
    } else {
      current.add(packageName);
    }
    await _sharedPreferences.setStringList(_lockedPackagesKey, current);
    notifyListeners();
  }

  Future<void> toggleVaultApp(String packageName) async {
    final current = List<String>.from(vaultPackages);
    if (current.contains(packageName)) {
      current.remove(packageName);
    } else {
      current.add(packageName);
    }
    await _sharedPreferences.setStringList(_vaultPackagesKey, current);
    notifyListeners();
  }

  void setVaultUnlocked(bool unlocked) {
    if (_vaultUnlocked != unlocked) {
      _vaultUnlocked = unlocked;
      notifyListeners();
    }
  }

  void toggleVaultUnlocked() {
    _vaultUnlocked = !_vaultUnlocked;
    notifyListeners();
  }

  Future<void> setCrashReportsEnabled(bool value) async {}
  Future<void> setAnalyticsEnabled(bool value) async {}

  Future<void> setUse24HourTimeFormat(bool value) async {
    await _sharedPreferences.setBool(_use24HourTimeFormatKey, value);
    notifyListeners();
  }

  Future<void> setAppHighlightAnimationEnabled(bool value) async {
    await _sharedPreferences.setBool(_appHighlightAnimationEnabledKey, value);
    notifyListeners();
  }

  Future<void> setGradientUuid(String value) async {
    await _sharedPreferences.setString(_gradientUuidKey, value);
    notifyListeners();
  }

  Future<void> setUnsplashAuthor(String? value) async {
    if (value == null) {
      await _sharedPreferences.remove(_unsplashAuthorKey);
    } else {
      await _sharedPreferences.setString(_unsplashAuthorKey, value);
    }
    notifyListeners();
  }

  Future<void> setRedditSubreddit(String value) async {
    final cleaned = value.trim().replaceAll("r/", "").replaceAll("/", "");
    await _sharedPreferences.setString(_redditSubredditKey, cleaned.isEmpty ? "AnimeWallpaper" : cleaned);
    await _sharedPreferences.setString(_wallpaperSourceKey, "reddit");
    notifyListeners();
  }

  Future<void> setVaultSubreddit(String value) async {
    final cleaned = value.trim().replaceAll("r/", "").replaceAll("/", "");
    await _sharedPreferences.setString(_vaultSubredditKey, cleaned.isEmpty ? "Waifu" : cleaned);
    notifyListeners();
  }

  Future<void> setWallpaperSource(String value) async {
    await _sharedPreferences.setString(_wallpaperSourceKey, value);
    notifyListeners();
  }

  Future<void> setWallpaperIntervalMinutes(int minutes) async {
    await _sharedPreferences.setInt(_wallpaperIntervalMinutesKey, minutes);
    notifyListeners();
  }

  Future<void> setLocalWallpaperFolder(String folderPath) async {
    await _sharedPreferences.setString(_localWallpaperFolderKey, folderPath.trim());
    await _sharedPreferences.setString(_wallpaperSourceKey, "local_folder");
    notifyListeners();
  }

  Future<void> setVideoWallpaperPath(String? path) async {
    if (path == null || path.trim().isEmpty) {
      await _sharedPreferences.remove(_videoWallpaperPathKey);
    } else {
      await _sharedPreferences.setString(_videoWallpaperPathKey, path.trim());
      await _sharedPreferences.setString(_wallpaperSourceKey, "video");
    }
    notifyListeners();
  }

  Future<void> setPosterIdleSeconds(int seconds) async {
    await _sharedPreferences.setInt(_posterIdleSecondsKey, seconds);
    notifyListeners();
  }

  Future<void> setGlassNeonEnabled(bool enabled) async {
    await _sharedPreferences.setBool(_glassNeonEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setNeonAccentColorValue(int colorValue) async {
    await _sharedPreferences.setInt(_neonAccentColorKey, colorValue);
    notifyListeners();
  }

  Future<void> setCustomFontFamily(String fontFamily) async {
    await _sharedPreferences.setString(_customFontFamilyKey, fontFamily);
    notifyListeners();
  }

  Future<void> setNightDimmerLevel(double level) async {
    await _sharedPreferences.setDouble(_nightDimmerLevelKey, level.clamp(0.0, 0.75));
    notifyListeners();
  }

  Future<void> setJellyfinEnabled(bool enabled) async {
    await _sharedPreferences.setBool(_jellyfinEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setJellyfinServerUrl(String url) async {
    await _sharedPreferences.setString(_jellyfinServerUrlKey, url.trim());
    notifyListeners();
  }

  Future<void> setJellyfinApiKey(String apiKey) async {
    await _sharedPreferences.setString(_jellyfinApiKeyKey, apiKey.trim());
    notifyListeners();
  }

  Future<void> setSystemHudEnabled(bool enabled) async {
    await _sharedPreferences.setBool(_systemHudEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setPs5BackdropPreviewEnabled(bool enabled) async {
    await _sharedPreferences.setBool(_ps5BackdropPreviewKey, enabled);
    notifyListeners();
  }

  Future<void> setAutoNightShiftEnabled(bool enabled) async {
    await _sharedPreferences.setBool(_autoNightShiftKey, enabled);
    notifyListeners();
  }

  Future<void> setShowHdmiCardsEnabled(bool enabled) async {
    await _sharedPreferences.setBool(_showHdmiCardsKey, enabled);
    notifyListeners();
  }

  Future<void> setFrigateAlertsEnabled(bool enabled) async {
    await _sharedPreferences.setBool(_frigateAlertsKey, enabled);
    notifyListeners();
  }

  Future<void> setFrigateServerUrl(String url) async {
    await _sharedPreferences.setString(_frigateServerUrlKey, url.trim());
    notifyListeners();
  }
}
