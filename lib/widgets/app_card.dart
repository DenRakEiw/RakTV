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

import 'package:flauncher/database.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/ticker_model.dart';
import 'package:flauncher/widgets/application_info_panel.dart';
import 'package:flauncher/widgets/color_helpers.dart';
import 'package:flauncher/widgets/focus_keyboard_listener.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

const _validationKeys = [LogicalKeyboardKey.select, LogicalKeyboardKey.enter, LogicalKeyboardKey.gameButtonA];

class AppCard extends StatefulWidget {
  final Category category;
  final App application;
  final bool autofocus;
  final void Function(AxisDirection) onMove;
  final VoidCallback onMoveEnd;

  AppCard({
    Key? key,
    required this.category,
    required this.application,
    required this.autofocus,
    required this.onMove,
    required this.onMoveEnd,
  }) : super(key: key);

  @override
  _AppCardState createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> with SingleTickerProviderStateMixin {
  bool _moving = false;
  MemoryImage? _imageProvider;
  late final FocusNode _focusNode = FocusNode();
  late final AnimationController _animation = AnimationController(
    vsync: Provider.of<TickerModel>(context, listen: false).tickerProvider ?? this,
    duration: Duration(
      milliseconds: 800,
    ),
  );
  Color _lastBorderColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    _animation.addStatusListener((animationStatus) {
      switch (animationStatus) {
        case AnimationStatus.completed:
          _animation.reverse();
          break;
        case AnimationStatus.dismissed:
          _animation.forward();
          break;
        case AnimationStatus.forward:
        case AnimationStatus.reverse:
          break;
      }
    });
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
    _animation.dispose();
    super.dispose();
  }

  ImageProvider _cachedMemoryImage(Uint8List bytes) {
    if (!listEquals(bytes, _imageProvider?.bytes)) {
      _imageProvider = MemoryImage(bytes);
    }
    return _imageProvider!;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final appsService = context.watch<AppsService>();
    final customBanner = appsService.getCustomBanner(widget.application.packageName);
    final activeBanner = customBanner ?? widget.application.banner;
    final isLocked = settings.isAppLocked(widget.application.packageName);
    final isVault = settings.isVaultApp(widget.application.packageName);
    final glassNeon = settings.glassNeonEnabled;
    final neonColor = settings.neonAccentColor;
    final hasFocus = _focusNode.hasPrimaryFocus;

    if (hasFocus && settings.appHighlightAnimationEnabled) {
      if (!_animation.isAnimating) {
        _animation.forward();
      }
    } else {
      if (_animation.isAnimating) {
        _animation.stop();
      }
    }

    return FocusKeyboardListener(
      onPressed: (key) => _onPressed(context, key),
      onLongPress: (key) => _onLongPress(context, key),
      builder: (context) => AspectRatio(
        aspectRatio: 16 / 9,
        child: Transform.scale(
          scale: _moving ? 1.0 : (hasFocus ? 1.07 : 1.0),
          child: Material(
            borderRadius: BorderRadius.circular(glassNeon ? 10 : 8),
            clipBehavior: Clip.antiAlias,
            color: glassNeon ? Colors.black87 : Theme.of(context).cardColor,
            elevation: hasFocus ? 10 : 0,
            shadowColor: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                InkWell(
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  focusColor: Colors.transparent,
                  onTap: () => _onPressed(context, null),
                  onLongPress: () => _onLongPress(context, null),
                  child: activeBanner != null
                      ? Ink.image(image: _cachedMemoryImage(activeBanner), fit: BoxFit.cover)
                      : Padding(
                          padding: EdgeInsets.all(8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Ink.image(
                                  image: _cachedMemoryImage(widget.application.icon!),
                                  height: double.infinity,
                                ),
                              ),
                              Flexible(
                                flex: 3,
                                child: Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Text(
                                    widget.application.name,
                                    style: Theme.of(context).textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                if (isLocked || isVault)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: IgnorePointer(
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: neonColor, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isVault) Icon(Icons.visibility_off, size: 13, color: neonColor),
                            if (isVault && isLocked) SizedBox(width: 3),
                            if (isLocked) Icon(Icons.lock_outline, size: 13, color: Colors.amberAccent),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_moving) ..._arrows(),
                if (hasFocus && settings.appHighlightAnimationEnabled)
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) => IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _lastBorderColor = computeBorderColor(_animation.value, _lastBorderColor),
                            width: 3.0,
                          ),
                          borderRadius: BorderRadius.circular(glassNeon ? 10 : 8),
                        ),
                      ),
                    ),
                  )
                else if (hasFocus)
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: neonColor, width: 3.0),
                        borderRadius: BorderRadius.circular(glassNeon ? 10 : 8),
                      ),
                    ),
                  )
                else if (glassNeon)
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white12, width: 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Matrix4 _scaleTransform(bool hasFocus) {
    final scale = _moving
        ? 1.0
        : hasFocus
            ? 1.08
            : 1.0;
    return Matrix4.diagonal3Values(scale, scale, 1.0);
  }

  List<Widget> _arrows() => [
        _arrow(Alignment.centerLeft, Icons.keyboard_arrow_left),
        _arrow(Alignment.topCenter, Icons.keyboard_arrow_up),
        _arrow(Alignment.bottomCenter, Icons.keyboard_arrow_down),
        _arrow(Alignment.centerRight, Icons.keyboard_arrow_right),
      ];

  Widget _arrow(Alignment alignment, IconData icon) => Align(
        alignment: alignment,
        child: Padding(
          padding: EdgeInsets.all(4),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).primaryColor.withOpacity(0.8),
            ),
            child: Icon(
              icon,
              size: 16,
            ),
          ),
        ),
      );

  KeyEventResult _onPressed(BuildContext context, LogicalKeyboardKey? key) {
    if (_moving) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Scrollable.ensureVisible(context,
          alignment: 0.1, duration: Duration(milliseconds: 100), curve: Curves.easeInOut));
      if (key == LogicalKeyboardKey.arrowLeft) {
        widget.onMove(AxisDirection.left);
      } else if (key == LogicalKeyboardKey.arrowUp) {
        widget.onMove(AxisDirection.up);
      } else if (key == LogicalKeyboardKey.arrowRight) {
        widget.onMove(AxisDirection.right);
      } else if (key == LogicalKeyboardKey.arrowDown) {
        widget.onMove(AxisDirection.down);
      } else if (_validationKeys.contains(key)) {
        setState(() => _moving = false);
        widget.onMoveEnd();
      }
      return KeyEventResult.handled;
    } else if (key == null || _validationKeys.contains(key)) {
      _handleLaunch(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _handleLaunch(BuildContext context) async {
    final settings = context.read<SettingsService>();
    final appsService = context.read<AppsService>();
    if (settings.isAppLocked(widget.application.packageName)) {
      final unlocked = await _showPinUnlockDialog(context, settings.neonAccentColor);
      if (!unlocked) return;
    }
    await appsService.launchApp(widget.application);
  }

  Future<bool> _showPinUnlockDialog(BuildContext context, Color accentColor) async {
    final targetSeq = [
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowDown,
    ];
    final entered = <LogicalKeyboardKey>[];

    final res = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => RawKeyboardListener(
          focusNode: FocusNode()..requestFocus(),
          autofocus: true,
          onKey: (event) {
            if (event is RawKeyDownEvent) {
              if ([
                LogicalKeyboardKey.arrowUp,
                LogicalKeyboardKey.arrowDown,
                LogicalKeyboardKey.arrowLeft,
                LogicalKeyboardKey.arrowRight,
              ].contains(event.logicalKey)) {
                setDialogState(() {
                  entered.add(event.logicalKey);
                });
                if (entered.length == targetSeq.length) {
                  bool match = true;
                  for (int i = 0; i < targetSeq.length; i++) {
                    if (entered[i] != targetSeq[i]) match = false;
                  }
                  if (match) {
                    Navigator.of(dialogCtx).pop(true);
                  } else {
                    setDialogState(() => entered.clear());
                  }
                }
              }
            }
          },
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: accentColor, width: 2),
            ),
            title: Row(
              children: [
                Icon(Icons.lock_outline, color: accentColor),
                SizedBox(width: 8),
                Text("App Locked • ${widget.application.name}"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Enter D-Pad unlock sequence on your remote:"),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    4,
                    (i) => Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: i < entered.length ? accentColor : Colors.white24,
                        child: Icon(
                          i < entered.length ? Icons.check : Icons.fiber_manual_record,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return res == true;
  }

  KeyEventResult _onLongPress(BuildContext context, LogicalKeyboardKey? key) {
    if (!_moving && (key == null || longPressableKeys.contains(key) || directMenuKeys.contains(key))) {
      _showPanel(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _showPanel(BuildContext context) async {
    final result = await showDialog<ApplicationInfoPanelResult>(
      context: context,
      builder: (context) => ApplicationInfoPanel(
        category: widget.category,
        application: widget.application,
      ),
    );
    if (result == ApplicationInfoPanelResult.reorderApp) {
      setState(() => _moving = true);
    }
  }
}
