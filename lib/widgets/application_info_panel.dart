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

import 'dart:io';

import 'package:flauncher/database.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/right_panel_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ApplicationInfoPanel extends StatelessWidget {
  final Category? category;
  final App application;

  ApplicationInfoPanel({
    required this.category,
    required this.application,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final appsService = context.watch<AppsService>();
    final isLocked = settings.isAppLocked(application.packageName);
    final isVault = settings.isVaultApp(application.packageName);
    final hasCustomBanner = appsService.hasCustomBanner(application.packageName);
    final accent = settings.neonAccentColor;

    return RightPanelDialog(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Image.memory(application.icon!, width: 50),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    application.name,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              application.packageName,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              "v${application.version}",
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
            Divider(),
            TextButton(
              child: Row(
                children: [
                  Icon(Icons.open_in_new),
                  Container(width: 8),
                  Text("Open", style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              onPressed: () async {
                await context.read<AppsService>().launchApp(application);
                Navigator.of(context).pop(ApplicationInfoPanelResult.none);
              },
            ),
            if (category?.sort == CategorySort.manual)
              TextButton(
                child: Row(
                  children: [
                    Icon(Icons.open_with),
                    Container(width: 8),
                    Text("Reorder", style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                onPressed: () => Navigator.of(context).pop(ApplicationInfoPanelResult.reorderApp),
              ),
            TextButton(
              child: Row(
                children: [
                  Icon(application.hidden ? Icons.visibility : Icons.visibility_off_outlined),
                  Container(width: 8),
                  Text(application.hidden ? "Unhide" : "Hide", style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              onPressed: () async {
                if (application.hidden) {
                  await context.read<AppsService>().unHideApplication(application);
                } else {
                  await context.read<AppsService>().hideApplication(application);
                }
                Navigator.of(context).pop(ApplicationInfoPanelResult.none);
              },
            ),
            Divider(),
            // RakTV Custom Pro Features
            TextButton(
              child: Row(
                children: [
                  Icon(Icons.image_outlined, color: accent),
                  Container(width: 8),
                  Flexible(
                    child: Text(
                      "Custom Banner / Icon",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              onPressed: () async {
                final picked = await appsService.pickCustomAppBanner(application.packageName);
                if (!picked) {
                  final localFiles = (await appsService.fLauncherChannel.listLocalMedia())
                      .where((p) => p.toLowerCase().endsWith(".png") || p.toLowerCase().endsWith(".jpg") || p.toLowerCase().endsWith(".webp"))
                      .toList();
                  if (localFiles.isNotEmpty) {
                    await showDialog(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        title: Text("Select Local Banner Image"),
                        content: SizedBox(
                          width: 400,
                          height: 260,
                          child: ListView.builder(
                            itemCount: localFiles.length,
                            itemBuilder: (_, idx) => ListTile(
                              leading: Icon(Icons.image, color: accent),
                              title: Text(localFiles[idx].split('/').last),
                              subtitle: Text(localFiles[idx]),
                              onTap: () async {
                                final bytes = await File(localFiles[idx]).readAsBytes();
                                await appsService.setCustomAppBanner(application.packageName, bytes);
                                Navigator.of(dCtx).pop();
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                }
              },
            ),
            if (hasCustomBanner)
              TextButton(
                child: Row(
                  children: [
                    Icon(Icons.restore, color: Colors.orangeAccent),
                    Container(width: 8),
                    Text("Reset Custom Banner", style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                onPressed: () async {
                  await appsService.clearCustomAppBanner(application.packageName);
                },
              ),
            TextButton(
              child: Row(
                children: [
                  Icon(isLocked ? Icons.lock_open : Icons.lock_outline, color: Colors.amberAccent),
                  Container(width: 8),
                  Flexible(
                    child: Text(
                      isLocked ? "Unlock App (Remove PIN)" : "Lock App (D-Pad PIN: ⬆️⬆️⬇️⬇️)",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              onPressed: () => settings.toggleAppLock(application.packageName),
            ),
            TextButton(
              child: Row(
                children: [
                  Icon(isVault ? Icons.vpn_key_off : Icons.vpn_key, color: accent),
                  Container(width: 8),
                  Flexible(
                    child: Text(
                      isVault ? "Remove from Hidden Vault" : "Move to Hidden Vault 🕵️",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              onPressed: () => settings.toggleVaultApp(application.packageName),
            ),
            if (category != null) ...[
              Divider(),
              TextButton(
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined),
                    Container(width: 8),
                    Flexible(
                      child: Text(
                        "Remove from ${category!.name}",
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                onPressed: () async {
                  await context.read<AppsService>().removeFromCategory(application, category!);
                  Navigator.of(context).pop(ApplicationInfoPanelResult.none);
                },
              ),
            ],
            Divider(),
            TextButton(
              child: Row(
                children: [
                  Icon(Icons.info_outlined),
                  Container(width: 8),
                  Text("App info", style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              onPressed: () => context.read<AppsService>().openAppInfo(application),
            ),
            TextButton(
              child: Row(
                children: [
                  Icon(Icons.delete_outlined),
                  Container(width: 8),
                  Text("Uninstall", style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              onPressed: () async {
                await context.read<AppsService>().uninstallApp(application);
                Navigator.of(context).pop(ApplicationInfoPanelResult.none);
              },
            ),
          ],
        ),
      ),
    );
  }
}

enum ApplicationInfoPanelResult { none, reorderApp }
