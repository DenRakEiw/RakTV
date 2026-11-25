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

import 'package:flauncher/widgets/right_panel_dialog.dart';
import 'package:flauncher/widgets/settings/applications_panel_page.dart';
import 'package:flauncher/widgets/settings/categories_panel_page.dart';
import 'package:flauncher/widgets/settings/category_panel_page.dart';
import 'package:flauncher/widgets/settings/gradient_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_panel_page.dart';
import 'package:flauncher/widgets/settings/unsplash_panel_page.dart';
import 'package:flauncher/widgets/settings/wallpaper_panel_page.dart';
import 'package:flutter/material.dart';

class SettingsPanel extends StatefulWidget {
  final String? initialRoute;

  const SettingsPanel({Key? key, this.initialRoute}) : super(key: key);

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => WillPopScope(
        onWillPop: () async => !await _navigatorKey.currentState!.maybePop(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: RightPanelDialog(
            width: 375,
            child: Navigator(
              key: _navigatorKey,
              initialRoute: widget.initialRoute ?? SettingsPanelPage.routeName,
              onGenerateRoute: (settings) {
                switch (settings.name) {
                  case SettingsPanelPage.routeName:
                    return MaterialPageRoute(builder: (_) => SettingsPanelPage());
                  case WallpaperPanelPage.routeName:
                    return MaterialPageRoute(builder: (_) => WallpaperPanelPage());
                  case UnsplashPanelPage.routeName:
                    return MaterialPageRoute(builder: (_) => UnsplashPanelPage());
                  case GradientPanelPage.routeName:
                    return MaterialPageRoute(builder: (_) => GradientPanelPage());
                  case ApplicationsPanelPage.routeName:
                    return MaterialPageRoute(builder: (_) => ApplicationsPanelPage());
                  case CategoriesPanelPage.routeName:
                    return MaterialPageRoute(builder: (_) => CategoriesPanelPage());
                  case CategoryPanelPage.routeName:
                    return MaterialPageRoute(
                      builder: (_) => CategoryPanelPage(categoryId: settings.arguments! as int),
                    );
                  default:
                    throw ArgumentError.value(settings.name, "settings.name", "Route not supported.");
                }
              },
            ),
          ),
        ),
      );
}
