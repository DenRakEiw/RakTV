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

import 'package:flutter/services.dart';

class FLauncherChannel {
  static const _methodChannel = MethodChannel('me.efesser.flauncher/method');
  static const _eventChannel = EventChannel('me.efesser.flauncher/event');

  Future<List<dynamic>> getApplications() async => (await _methodChannel.invokeListMethod('getApplications'))!;

  Future<bool> applicationExists(String packageName) async =>
      await _methodChannel.invokeMethod('applicationExists', packageName);

  Future<void> launchApp(String packageName) async => await _methodChannel.invokeMethod('launchApp', packageName);

  Future<void> openSettings() async => await _methodChannel.invokeMethod('openSettings');

  Future<void> openAppInfo(String packageName) async => await _methodChannel.invokeMethod('openAppInfo', packageName);

  Future<void> uninstallApp(String packageName) async => await _methodChannel.invokeMethod('uninstallApp', packageName);

  Future<bool> isDefaultLauncher() async => await _methodChannel.invokeMethod('isDefaultLauncher');

  Future<bool> checkForGetContentAvailability() async =>
      await _methodChannel.invokeMethod("checkForGetContentAvailability");

  Future<void> startAmbientMode() async => await _methodChannel.invokeMethod("startAmbientMode");

  Future<Map<String, int>> getMemoryInfo() async {
    try {
      final res = await _methodChannel.invokeMapMethod<String, int>("getMemoryInfo");
      return res ?? {"totalMb": 2048, "availMb": 768, "usedPercent": 62};
    } catch (_) {
      return {"totalMb": 2048, "availMb": 768, "usedPercent": 62};
    }
  }

  Future<Map<String, int>> boostRam() async {
    try {
      final res = await _methodChannel.invokeMapMethod<String, int>("boostRam");
      return res ?? {"freedMb": 0, "availMb": 768, "usedPercent": 60, "killedCount": 0};
    } catch (_) {
      return {"freedMb": 0, "availMb": 768, "usedPercent": 60, "killedCount": 0};
    }
  }

  Future<List<String>> listLocalMedia([String? folderPath]) async {
    try {
      final res = await _methodChannel.invokeListMethod<String>("listLocalMedia", folderPath);
      return res ?? [];
    } catch (_) {
      return [];
    }
  }

  void addAppsChangedListener(void Function(Map<dynamic, dynamic>) listener) =>
      _eventChannel.receiveBroadcastStream().listen((event) => listener(event));
}
