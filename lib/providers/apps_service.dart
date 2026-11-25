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
import 'dart:collection';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flauncher/database.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class AppsService extends ChangeNotifier {
  final FLauncherChannel _fLauncherChannel;
  final FLauncherDatabase _database;
  bool _initialized = false;

  List<App> _applications = [];
  List<CategoryWithApps> _categoriesWithApps = [];
  final Map<String, Uint8List> _customBanners = {};
  Directory? _docsDir;

  bool get initialized => _initialized;

  FLauncherChannel get fLauncherChannel => _fLauncherChannel;

  List<App> get applications => UnmodifiableListView(_applications);

  List<CategoryWithApps> get categoriesWithApps => _categoriesWithApps
      .map((item) => CategoryWithApps(item.category, UnmodifiableListView(item.applications)))
      .toList(growable: false);

  AppsService(this._fLauncherChannel, this._database) {
    _init();
  }

  Uint8List? getCustomBanner(String packageName) => _customBanners[packageName];

  bool hasCustomBanner(String packageName) => _customBanners.containsKey(packageName);

  Future<void> _loadCustomBanners() async {
    try {
      _docsDir = await getApplicationDocumentsDirectory();
      final files = _docsDir!.listSync();
      for (final entity in files) {
        if (entity is File) {
          final name = entity.path.split(Platform.pathSeparator).last;
          if (name.startsWith("custom_banner_") && name.endsWith(".img")) {
            final pkg = name.substring("custom_banner_".length, name.length - 4);
            _customBanners[pkg] = await entity.readAsBytes();
          }
        }
      }
    } catch (_) {}
  }

  Future<bool> pickCustomAppBanner(String packageName) async {
    try {
      if (await _fLauncherChannel.checkForGetContentAvailability()) {
        final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (picked != null) {
          final bytes = await picked.readAsBytes();
          await setCustomAppBanner(packageName, bytes);
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> setCustomAppBanner(String packageName, Uint8List bytes) async {
    _docsDir ??= await getApplicationDocumentsDirectory();
    final file = File("${_docsDir!.path}/custom_banner_$packageName.img");
    await file.writeAsBytes(bytes);
    _customBanners[packageName] = bytes;
    notifyListeners();
  }

  Future<void> clearCustomAppBanner(String packageName) async {
    _docsDir ??= await getApplicationDocumentsDirectory();
    final file = File("${_docsDir!.path}/custom_banner_$packageName.img");
    if (await file.exists()) {
      await file.delete();
    }
    _customBanners.remove(packageName);
    notifyListeners();
  }

  Future<Map<String, int>> getMemoryInfo() => _fLauncherChannel.getMemoryInfo();

  Future<Map<String, int>> boostRam() => _fLauncherChannel.boostRam();

  Future<void> _init() async {
    await _loadCustomBanners();
    await _refreshState(shouldNotifyListeners: false);
    if (_database.wasCreated) {
      await _initDefaultCategories();
    }
    _fLauncherChannel.addAppsChangedListener((event) async {
      switch (event["action"]) {
        case "PACKAGE_ADDED":
        case "PACKAGE_CHANGED":
          await _database.persistApps([_buildAppCompanion(event["activitiyInfo"])]);
          break;
        case "PACKAGES_AVAILABLE":
          await _database.persistApps((event["activitiesInfo"] as List<dynamic>).map(_buildAppCompanion).toList());
          break;
        case "PACKAGE_REMOVED":
          await _database.deleteApps([event["packageName"]]);
          break;
      }
      _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
      _applications = await _database.listApplications();
      notifyListeners();
    });
    _initialized = true;
    notifyListeners();
  }

  AppsCompanion _buildAppCompanion(dynamic data) => AppsCompanion(
        packageName: Value(data["packageName"]),
        name: Value(data["name"]),
        version: Value(data["version"] ?? "(unknown)"),
        banner: Value(data["banner"]),
        icon: Value(data["icon"]),
        hidden: Value.absent(),
        sideloaded: Value(data["sideloaded"]),
      );

  Future<void> _initDefaultCategories() => _database.transaction(() async {
        final tvApplications = _applications.where((element) => element.sideloaded == false);
        final nonTvApplications = _applications.where((element) => element.sideloaded == true);
        if (tvApplications.isNotEmpty) {
          await addCategory("TV Applications", shouldNotifyListeners: false);
          final tvAppsCategory =
              _categoriesWithApps.map((e) => e.category).firstWhere((element) => element.name == "TV Applications");
          await setCategoryType(
            tvAppsCategory,
            CategoryType.grid,
            shouldNotifyListeners: false,
          );
          for (final app in tvApplications) {
            await addToCategory(app, tvAppsCategory, shouldNotifyListeners: false);
          }
        }
        if (nonTvApplications.isNotEmpty) {
          await addCategory(
            "Non-TV Applications",
            shouldNotifyListeners: false,
          );
          final nonTvAppsCategory =
              _categoriesWithApps.map((e) => e.category).firstWhere((element) => element.name == "Non-TV Applications");
          for (final app in nonTvApplications) {
            await addToCategory(
              app,
              nonTvAppsCategory,
              shouldNotifyListeners: false,
            );
          }
        }
        _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
      });

  Future<void> _refreshState({bool shouldNotifyListeners = true}) async {
    await _database.transaction(() async {
      final appsFromSystem = (await _fLauncherChannel.getApplications()).map(_buildAppCompanion).toList();

      final appsRemovedFromSystem = (await _database.listApplications())
          .where((app) => !appsFromSystem.any((systemApp) => systemApp.packageName.value == app.packageName))
          .map((app) => app.packageName)
          .toList();

      final List<String> uninstalledApplications = [];
      await Future.forEach(appsRemovedFromSystem, (String packageName) async {
        if (!(await _fLauncherChannel.applicationExists(packageName))) {
          uninstalledApplications.add(packageName);
        }
      });

      await _database.persistApps(appsFromSystem);
      await _database.deleteApps(uninstalledApplications);

      _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
      _applications = await _database.listApplications();
    });
    if (shouldNotifyListeners) {
      notifyListeners();
    }
  }

  Future<void> launchApp(App app) => _fLauncherChannel.launchApp(app.packageName);

  Future<void> launchPackage(String packageName) => _fLauncherChannel.launchApp(packageName);

  Future<void> openAppInfo(App app) => _fLauncherChannel.openAppInfo(app.packageName);

  Future<void> uninstallApp(App app) => _fLauncherChannel.uninstallApp(app.packageName);

  Future<void> openSettings() => _fLauncherChannel.openSettings();

  Future<bool> isDefaultLauncher() => _fLauncherChannel.isDefaultLauncher();

  Future<void> startAmbientMode() => _fLauncherChannel.startAmbientMode();

  Future<void> addToCategory(App app, Category category, {bool shouldNotifyListeners = true}) async {
    int index = await _database.nextAppCategoryOrder(category.id) ?? 0;
    await _database.insertAppsCategories([
      AppsCategoriesCompanion.insert(
        categoryId: category.id,
        appPackageName: app.packageName,
        order: index,
      )
    ]);
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    if (shouldNotifyListeners) {
      notifyListeners();
    }
  }

  Future<void> removeFromCategory(App app, Category category) async {
    await _database.deleteAppCategory(category.id, app.packageName);
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    notifyListeners();
  }

  Future<void> saveOrderInCategory(Category category) async {
    final applications = _categoriesWithApps.firstWhere((element) => element.category.id == category.id).applications;
    final orderedAppCategories = <AppsCategoriesCompanion>[];
    for (int i = 0; i < applications.length; ++i) {
      orderedAppCategories.add(AppsCategoriesCompanion(
        categoryId: Value(category.id),
        appPackageName: Value(applications[i].packageName),
        order: Value(i),
      ));
    }
    await _database.replaceAppsCategories(orderedAppCategories);
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    notifyListeners();
  }

  void reorderApplication(Category category, int oldIndex, int newIndex) {
    final applications = _categoriesWithApps.firstWhere((element) => element.category.id == category.id).applications;
    final application = applications.removeAt(oldIndex);
    applications.insert(newIndex, application);
    notifyListeners();
  }

  Future<void> addCategory(String categoryName, {bool shouldNotifyListeners = true}) async {
    final orderedCategories = <CategoriesCompanion>[];
    for (int i = 0; i < _categoriesWithApps.length; ++i) {
      final category = _categoriesWithApps[i].category;
      orderedCategories.add(CategoriesCompanion(id: Value(category.id), order: Value(i + 1)));
    }
    await _database.insertCategory(CategoriesCompanion.insert(name: categoryName, order: 0));
    await _database.updateCategories(orderedCategories);
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    if (shouldNotifyListeners) {
      notifyListeners();
    }
  }

  Future<void> renameCategory(Category category, String categoryName) async {
    await _database.updateCategory(category.id, CategoriesCompanion(name: Value(categoryName)));
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    notifyListeners();
  }

  Future<void> deleteCategory(Category category) async {
    await _database.deleteCategory(category.id);
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    notifyListeners();
  }

  Future<void> moveCategory(int oldIndex, int newIndex) async {
    final categoryWithApps = _categoriesWithApps.removeAt(oldIndex);
    _categoriesWithApps.insert(newIndex, categoryWithApps);
    final orderedCategories = <CategoriesCompanion>[];
    for (int i = 0; i < _categoriesWithApps.length; ++i) {
      final category = _categoriesWithApps[i].category;
      orderedCategories.add(CategoriesCompanion(id: Value(category.id), order: Value(i)));
    }
    await _database.updateCategories(orderedCategories);
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    notifyListeners();
  }

  Future<void> hideApplication(App application) async {
    await _database.updateApp(application.packageName, AppsCompanion(hidden: Value(true)));
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    _applications = await _database.listApplications();
    notifyListeners();
  }

  Future<void> unHideApplication(App application) async {
    await _database.updateApp(application.packageName, AppsCompanion(hidden: Value(false)));
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    _applications = await _database.listApplications();
    notifyListeners();
  }

  Future<void> setCategoryType(Category category, CategoryType type, {bool shouldNotifyListeners = true}) async {
    await _database.updateCategory(category.id, CategoriesCompanion(type: Value(type)));
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    if (shouldNotifyListeners) {
      notifyListeners();
    }
  }

  Future<void> setCategorySort(Category category, CategorySort sort) async {
    await _database.updateCategory(category.id, CategoriesCompanion(sort: Value(sort)));
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    notifyListeners();
  }

  Future<void> setCategoryColumnsCount(Category category, int columnsCount) async {
    await _database.updateCategory(category.id, CategoriesCompanion(columnsCount: Value(columnsCount)));
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    notifyListeners();
  }

  Future<void> setCategoryRowHeight(Category category, int rowHeight) async {
    await _database.updateCategory(category.id, CategoriesCompanion(rowHeight: Value(rowHeight)));
    _categoriesWithApps = await _database.listCategoriesWithVisibleApps();
    notifyListeners();
  }
}
