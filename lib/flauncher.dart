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
import 'dart:typed_data';
import 'dart:ui';

import 'package:flauncher/custom_traversal_policy.dart';
import 'package:flauncher/database.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/apps_grid.dart';
import 'package:flauncher/widgets/category_row.dart';
import 'package:flauncher/widgets/jellyfin_row.dart';
import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flauncher/widgets/time_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

class FLauncher extends StatefulWidget {
  @override
  State<FLauncher> createState() => _FLauncherState();
}

class _FLauncherState extends State<FLauncher> {
  Timer? _idleTimer;
  bool _isIdlePosterMode = false;
  final List<LogicalKeyboardKey> _konamiBuffer = [];
  String? _lastVideoUrl;
  WebViewController? _videoWebController;

  static final List<LogicalKeyboardKey> _konamiSequence = [
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
  ];

  @override
  void initState() {
    super.initState();
    RawKeyboard.instance.addListener(_handleGlobalKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) => _resetIdleTimer());
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(_handleGlobalKeyEvent);
    _idleTimer?.cancel();
    super.dispose();
  }

  void _resetIdleTimer() {
    if (!mounted) return;
    if (_isIdlePosterMode) {
      setState(() => _isIdlePosterMode = false);
    }
    _idleTimer?.cancel();
    final idleSeconds = context.read<SettingsService>().posterIdleSeconds;
    if (idleSeconds > 0) {
      _idleTimer = Timer(Duration(seconds: idleSeconds), () {
        if (mounted) {
          setState(() => _isIdlePosterMode = true);
        }
      });
    }
  }

  void _handleGlobalKeyEvent(RawKeyEvent event) {
    _resetIdleTimer();
    if (event is RawKeyDownEvent) {
      final key = event.logicalKey;
      if ([
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
      ].contains(key)) {
        _konamiBuffer.add(key);
        if (_konamiBuffer.length > _konamiSequence.length) {
          _konamiBuffer.removeAt(0);
        }
        if (_konamiBuffer.length == _konamiSequence.length) {
          bool matched = true;
          for (int i = 0; i < _konamiSequence.length; i++) {
            if (_konamiBuffer[i] != _konamiSequence[i]) {
              matched = false;
              break;
            }
          }
          if (matched) {
            _konamiBuffer.clear();
            if (!mounted) return;
            final settings = context.read<SettingsService>();
            settings.toggleVaultUnlocked();
            final unlocked = settings.vaultUnlocked;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: Duration(seconds: 3),
                backgroundColor: Colors.black87,
                content: Row(
                  children: [
                    Icon(unlocked ? Icons.lock_open : Icons.lock, color: settings.neonAccentColor),
                    SizedBox(width: 10),
                    Text(
                      unlocked
                          ? "🕵️ Hidden Vault Unlocked! (r/${settings.vaultSubreddit})"
                          : "🔒 Hidden Vault Locked",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            );
          }
        }
      } else {
        _konamiBuffer.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    return FocusTraversalGroup(
      policy: RowByRowTraversalPolicy(),
      child: Stack(
        children: [
          Consumer<WallpaperService>(
            builder: (_, wallpaper, __) => _wallpaper(
              context,
              wallpaper.wallpaperBytes,
              wallpaper.activeVideoPath,
              wallpaper.gradient.gradient,
            ),
          ),
          if (settings.nightDimmerLevel > 0)
            IgnorePointer(
              child: Container(
                color: Colors.black.withOpacity(settings.nightDimmerLevel),
              ),
            ),
          Visibility(
            visible: !_isIdlePosterMode,
            maintainState: true,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: _appBar(context, settings),
              body: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Consumer<AppsService>(
                  builder: (context, appsService, _) => appsService.initialized
                      ? SingleChildScrollView(
                          child: _categories(context, appsService.categoriesWithApps, appsService.applications, settings),
                        )
                      : _emptyState(context),
                ),
              ),
            ),
          ),
          if (_isIdlePosterMode)
            Positioned(
              bottom: 24,
              right: 32,
              child: IgnorePointer(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: TimeWidget(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _categories(
    BuildContext context,
    List<CategoryWithApps> categoriesWithApps,
    List<App> allApplications,
    SettingsService settings,
  ) {
    final vaultPkgs = settings.vaultPackages;
    final vaultApps = allApplications.where((a) => vaultPkgs.contains(a.packageName)).toList();

    return Column(
      children: [
        if (settings.vaultUnlocked && vaultApps.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: CategoryRow(
              key: Key("hidden_vault_row"),
              category: Category(
                id: -999,
                name: "🕵️ Secret Vault",
                sort: CategorySort.alphabetical,
                type: CategoryType.row,
                rowHeight: 110,
                columnsCount: 6,
                order: -1,
              ),
              applications: vaultApps,
            ),
          ),
        JellyfinRow(),
        ...categoriesWithApps.map((categoryWithApps) {
          final visibleApps = settings.vaultUnlocked
              ? categoryWithApps.applications
              : categoryWithApps.applications.where((a) => !vaultPkgs.contains(a.packageName)).toList();
          switch (categoryWithApps.category.type) {
            case CategoryType.row:
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: CategoryRow(
                  key: Key(categoryWithApps.category.id.toString()),
                  category: categoryWithApps.category,
                  applications: visibleApps,
                ),
              );
            case CategoryType.grid:
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: AppsGrid(
                  key: Key(categoryWithApps.category.id.toString()),
                  category: categoryWithApps.category,
                  applications: visibleApps,
                ),
              );
          }
        }).toList(),
      ],
    );
  }

  AppBar _appBar(BuildContext context, SettingsService settings) => AppBar(
        title: Row(
          children: [
            Text(
              "RakTV",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: settings.neonAccentColor,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
              ),
            ),
            if (settings.vaultUnlocked) ...[
              SizedBox(width: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: settings.neonAccentColor.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: settings.neonAccentColor),
                ),
                child: Text(
                  "🕵️ VAULT UNLOCKED",
                  style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 2.0,
                top: 18.0,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2, tileMode: TileMode.decal),
                  child: Icon(Icons.settings_outlined, color: Colors.black54),
                ),
              ),
              IconButton(
                padding: EdgeInsets.all(2),
                constraints: BoxConstraints(),
                splashRadius: 20,
                icon: Icon(Icons.settings_outlined),
                onPressed: () => showDialog(context: context, builder: (_) => SettingsPanel()),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(left: 16, right: 32),
            child: Align(
              alignment: Alignment.center,
              child: TimeWidget(),
            ),
          ),
        ],
      );

  Widget _wallpaper(BuildContext context, Uint8List? wallpaperImage, String? activeVideoPath, Gradient gradient) {
    if (activeVideoPath != null && activeVideoPath.isNotEmpty) {
      final videoSrc = activeVideoPath.startsWith("http") ? activeVideoPath : "file://$activeVideoPath";
      if (_lastVideoUrl != videoSrc || _videoWebController == null) {
        _lastVideoUrl = videoSrc;
        final html = '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: #000; overflow: hidden; }
  video { width: 100vw; height: 100vh; object-fit: cover; }
</style>
</head>
<body>
  <video src="$videoSrc" autoplay loop muted playsinline></video>
</body>
</html>
''';
        _videoWebController = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.black)
          ..loadHtmlString(html);
      }
      return SizedBox(
        key: Key("background_video"),
        height: window.physicalSize.height,
        width: window.physicalSize.width,
        child: IgnorePointer(child: WebViewWidget(controller: _videoWebController!)),
      );
    }

    return wallpaperImage != null
        ? Image.memory(
            wallpaperImage,
            key: Key("background"),
            fit: BoxFit.cover,
            height: window.physicalSize.height,
            width: window.physicalSize.width,
          )
        : Container(key: Key("background"), decoration: BoxDecoration(gradient: gradient));
  }

  Widget _emptyState(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Loading...", style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      );
}
