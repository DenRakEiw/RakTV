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
import 'package:flutter/services.dart';

const longPressableKeys = [
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.gameButtonA,
];

const directMenuKeys = [
  LogicalKeyboardKey.contextMenu,
  LogicalKeyboardKey.info,
  LogicalKeyboardKey.gameButtonX,
  LogicalKeyboardKey.gameButtonY,
];

class FocusKeyboardListener extends StatefulWidget {
  final WidgetBuilder builder;
  final KeyEventResult Function(LogicalKeyboardKey)? onPressed;
  final KeyEventResult Function(LogicalKeyboardKey)? onLongPress;

  FocusKeyboardListener({
    Key? key,
    required this.builder,
    this.onPressed,
    this.onLongPress,
  }) : super(key: key);

  @override
  _FocusKeyboardListenerState createState() => _FocusKeyboardListenerState();
}

class _FocusKeyboardListenerState extends State<FocusKeyboardListener> {
  int? _keyDownAt;
  Timer? _longPressTimer;
  bool _longPressTriggered = false;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
        canRequestFocus: false,
        onKey: (_, rawKeyEvent) => _handleKey(context, rawKeyEvent),
        child: Builder(builder: widget.builder),
      );

  KeyEventResult _handleKey(BuildContext context, RawKeyEvent rawKeyEvent) {
    if (rawKeyEvent is RawKeyDownEvent) {
      return _keyDownEvent(context, rawKeyEvent.logicalKey, (rawKeyEvent.data as RawKeyEventDataAndroid));
    } else if (rawKeyEvent is RawKeyUpEvent) {
      return _keyUpEvent(context, rawKeyEvent.logicalKey);
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _keyDownEvent(BuildContext context, LogicalKeyboardKey key, RawKeyEventDataAndroid data) {
    if (directMenuKeys.contains(key)) {
      if (data.repeatCount == 0) {
        return widget.onLongPress?.call(key) ?? KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    }

    if (!longPressableKeys.contains(key)) {
      return widget.onPressed?.call(key) ?? KeyEventResult.ignored;
    }

    if (data.repeatCount == 0) {
      _keyDownAt = DateTime.now().millisecondsSinceEpoch;
      _longPressTriggered = false;
      _longPressTimer?.cancel();
      _longPressTimer = Timer(Duration(milliseconds: 450), () {
        if (mounted && _keyDownAt != null && !_longPressTriggered) {
          _longPressTriggered = true;
          _keyDownAt = null;
          widget.onLongPress?.call(key);
        }
      });
      // Return handled so MaterialApp's SingleActivator(select) doesn't immediately fire InkWell.onTap on key-down!
      return KeyEventResult.handled;
    } else if ((_longPress() || (data.flags & 0x80) != 0) && !_longPressTriggered) {
      _longPressTriggered = true;
      _keyDownAt = null;
      _longPressTimer?.cancel();
      return widget.onLongPress?.call(key) ?? KeyEventResult.handled;
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _keyUpEvent(BuildContext context, LogicalKeyboardKey key) {
    _longPressTimer?.cancel();
    if (_longPressTriggered) {
      _longPressTriggered = false;
      _keyDownAt = null;
      return KeyEventResult.handled;
    }
    if (_keyDownAt != null && longPressableKeys.contains(key)) {
      _keyDownAt = null;
      return widget.onPressed?.call(key) ?? KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  bool _longPress() => _keyDownAt != null && DateTime.now().millisecondsSinceEpoch - _keyDownAt! >= 450;
}
