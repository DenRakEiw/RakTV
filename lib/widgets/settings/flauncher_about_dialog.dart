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

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class FLauncherAboutDialog extends StatelessWidget {
  final PackageInfo packageInfo;

  FLauncherAboutDialog({
    Key? key,
    required this.packageInfo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium!;
    final underlined = textStyle.copyWith(decoration: TextDecoration.underline);
    return AboutDialog(
      applicationName: "RakTV",
      applicationVersion: "${packageInfo.version} (${packageInfo.buildNumber})",
      applicationIcon: Image.asset("assets/logo.png", height: 72),
      applicationLegalese: "Original FLauncher © 2021 Étienne Fesser\nRakTV Custom Edition © 2026 DenRakEiw (GPLv3)",
      children: [
        SizedBox(height: 20),
        RichText(
          text: TextSpan(
            style: textStyle,
            children: [
              TextSpan(
                text: "RakTV is a 100% tracker-free custom Android TV launcher with Reddit/Local 4K Wallpapers, "
                    ".mp4 Live Video Wallpapers, Waifu Poster Idle Mode, Hidden Vault (Konami Code), "
                    "Custom App Banners, Glassmorphism Neon Glow, and Native Jellyfin LAN integration.\n\n",
              ),
              TextSpan(text: "RakTV Repository: "),
              TextSpan(text: "https://github.com/DenRakEiw/RakTV", style: underlined),
              TextSpan(text: "\n\nBased on the open-source "),
              TextSpan(text: "FLauncher", style: textStyle.copyWith(fontWeight: FontWeight.bold)),
              TextSpan(text: " project by "),
              TextSpan(text: "Étienne Fesser", style: textStyle.copyWith(fontWeight: FontWeight.bold)),
              TextSpan(text: " ("),
              TextSpan(text: "https://gitlab.com/flauncher/flauncher", style: underlined),
              TextSpan(text: ").\nOriginal logo by Katie @fureturoe, design by @FXCostanzo."),
            ],
          ),
        )
      ],
    );
  }
}
