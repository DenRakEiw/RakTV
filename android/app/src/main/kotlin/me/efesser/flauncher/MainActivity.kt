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

package me.efesser.flauncher

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.Intent.*
import android.content.pm.*
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.media.tv.TvContract
import android.media.tv.TvInputInfo
import android.media.tv.TvInputManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.UserHandle
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.Serializable

private const val METHOD_CHANNEL = "me.efesser.flauncher/method"
private const val EVENT_CHANNEL = "me.efesser.flauncher/event"

class MainActivity : FlutterActivity() {
    val launcherAppsCallbacks = ArrayList<LauncherApps.Callback>()

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getApplications" -> result.success(getApplications())
                "applicationExists" -> result.success(applicationExists(call.arguments as String))
                "launchApp" -> result.success(launchApp(call.arguments as String))
                "openSettings" -> result.success(openSettings())
                "openAppInfo" -> result.success(openAppInfo(call.arguments as String))
                "uninstallApp" -> result.success(uninstallApp(call.arguments as String))
                "isDefaultLauncher" -> result.success(isDefaultLauncher())
                "checkForGetContentAvailability" -> result.success(checkForGetContentAvailability())
                "startAmbientMode" -> result.success(startAmbientMode())
                "getMemoryInfo" -> result.success(getMemoryInfo())
                "boostRam" -> result.success(boostRam())
                "listLocalMedia" -> result.success(listLocalMedia(call.arguments as? String))
                "switchHdmiInput" -> result.success(switchHdmiInput((call.arguments as? Int) ?: 1))
                else -> throw IllegalArgumentException()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(object : StreamHandler {
            lateinit var launcherAppsCallback: LauncherApps.Callback
            val launcherApps = getSystemService(LAUNCHER_APPS_SERVICE) as LauncherApps
            override fun onListen(arguments: Any?, events: EventSink) {
                launcherAppsCallback = object : LauncherApps.Callback() {
                    override fun onPackageRemoved(packageName: String, user: UserHandle) {
                        events.success(mapOf("action" to "PACKAGE_REMOVED", "packageName" to packageName))
                    }

                    override fun onPackageAdded(packageName: String, user: UserHandle) {
                        getApplication(packageName)
                            ?.let { events.success(mapOf("action" to "PACKAGE_ADDED", "activitiyInfo" to it)) }
                    }

                    override fun onPackageChanged(packageName: String, user: UserHandle) {
                        getApplication(packageName)
                            ?.let { events.success(mapOf("action" to "PACKAGE_CHANGED", "activitiyInfo" to it)) }
                    }

                    override fun onPackagesAvailable(packageNames: Array<out String>, user: UserHandle, replacing: Boolean) {
                        val applications = packageNames.map(::getApplication)
                        if (applications.isNotEmpty()) {
                            events.success(mapOf("action" to "PACKAGES_AVAILABLE", "activitiesInfo" to applications))
                        }
                    }

                    override fun onPackagesUnavailable(packageNames: Array<out String>, user: UserHandle, replacing: Boolean) {}
                }

                launcherAppsCallbacks.add(launcherAppsCallback)
                launcherApps.registerCallback(launcherAppsCallback)
            }

            override fun onCancel(arguments: Any?) {
                launcherApps.unregisterCallback(launcherAppsCallback)
                launcherAppsCallbacks.remove(launcherAppsCallback)
            }
        })
    }

    override fun onDestroy() {
        val launcherApps = getSystemService(LAUNCHER_APPS_SERVICE) as LauncherApps
        launcherAppsCallbacks.forEach(launcherApps::unregisterCallback)
        super.onDestroy()
    }

    private fun getMemoryInfo(): Map<String, Int> {
        return try {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val memInfo = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(memInfo)
            val totalMb = (memInfo.totalMem / (1024 * 1024)).toInt()
            val availMb = (memInfo.availMem / (1024 * 1024)).toInt()
            val usedMb = (totalMb - availMb).coerceAtLeast(0)
            val usedPercent = if (totalMb > 0) ((usedMb * 100) / totalMb) else 0
            mapOf("totalMb" to totalMb, "availMb" to availMb, "usedPercent" to usedPercent)
        } catch (e: Exception) {
            mapOf("totalMb" to 2048, "availMb" to 768, "usedPercent" to 62)
        }
    }

    private fun boostRam(): Map<String, Int> {
        return try {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val beforeInfo = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(beforeInfo)
            val beforeAvail = (beforeInfo.availMem / (1024 * 1024)).toInt()

            var killedCount = 0
            val packages = packageManager.getInstalledApplications(0)
            for (app in packages) {
                if (app.packageName != packageName && app.packageName != "com.neilturner.aerialviews") {
                    try {
                        activityManager.killBackgroundProcesses(app.packageName)
                        killedCount++
                    } catch (_: Exception) {}
                }
            }
            System.gc()

            val afterInfo = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(afterInfo)
            val afterAvail = (afterInfo.availMem / (1024 * 1024)).toInt()
            val freedMb = (afterAvail - beforeAvail).coerceAtLeast(0)
            val usedPercent = if (afterInfo.totalMem > 0) {
                (((afterInfo.totalMem - afterInfo.availMem) * 100) / afterInfo.totalMem).toInt()
            } else 0

            mapOf("freedMb" to freedMb, "availMb" to afterAvail, "usedPercent" to usedPercent, "killedCount" to killedCount)
        } catch (e: Exception) {
            mapOf("freedMb" to 0, "availMb" to 768, "usedPercent" to 60, "killedCount" to 0)
        }
    }

    private fun listLocalMedia(customFolder: String?): List<String> {
        val result = ArrayList<String>()
        val allowedExtensions = setOf("jpg", "jpeg", "png", "webp", "gif", "mp4", "webm")
        val foldersToScan = ArrayList<File>()
        if (!customFolder.isNullOrBlank()) {
            foldersToScan.add(File(customFolder))
        }
        try {
            foldersToScan.add(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES))
            foldersToScan.add(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS))
            foldersToScan.add(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES))
            foldersToScan.add(File("/sdcard/Wallpapers"))
        } catch (_: Exception) {}

        for (dir in foldersToScan) {
            try {
                if (dir.exists() && dir.isDirectory) {
                    dir.listFiles()?.forEach { file ->
                        if (file.isFile) {
                            val ext = file.extension.lowercase()
                            if (allowedExtensions.contains(ext) && !result.contains(file.absolutePath)) {
                                result.add(file.absolutePath)
                            }
                        }
                    }
                }
            } catch (_: Exception) {}
        }
        return result
    }

    private fun getApplications(): List<Map<String, Serializable?>> {
        val tvActivitiesInfo = queryIntentActivities(false)
        val nonTvActivitiesInfo = queryIntentActivities(true)
                .filter { nonTvActivityInfo -> !tvActivitiesInfo.any { tvActivityInfo -> tvActivityInfo.packageName == nonTvActivityInfo.packageName } }
        return tvActivitiesInfo.map { buildAppMap(it, false) } + nonTvActivitiesInfo.map { buildAppMap(it, true) }
    }

    private fun getApplication(packageName: String): Map<String, Serializable?>? {
        return packageManager.getLeanbackLaunchIntentForPackage(packageName)
            ?.resolveActivityInfo(packageManager, 0)
            ?.let { buildAppMap(it, false) }
            ?: return packageManager.getLaunchIntentForPackage(packageName)
                ?.resolveActivityInfo(packageManager, 0)
                ?.let { buildAppMap(it, true) }
    }

    private fun applicationExists(packageName: String) = try {
        val flag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            PackageManager.MATCH_UNINSTALLED_PACKAGES
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_UNINSTALLED_PACKAGES
        }
        packageManager.getApplicationInfo(packageName, flag)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    private fun queryIntentActivities(sideloaded: Boolean) = packageManager
            .queryIntentActivities(Intent(ACTION_MAIN, null)
                    .addCategory(if (sideloaded) CATEGORY_LAUNCHER else CATEGORY_LEANBACK_LAUNCHER), 0)
            .map(ResolveInfo::activityInfo)
            .filter { it.packageName != packageName }

    private fun buildAppMap(activityInfo: ActivityInfo, sideloaded: Boolean) = mapOf(
            "name" to activityInfo.loadLabel(packageManager).toString(),
            "packageName" to activityInfo.packageName,
            "banner" to activityInfo.loadBanner(packageManager)?.let(::drawableToByteArray),
            "icon" to activityInfo.loadIcon(packageManager)?.let(::drawableToByteArray),
            "version" to packageManager.getPackageInfo(activityInfo.packageName, 0).versionName,
            "sideloaded" to sideloaded,
    )

    private fun launchApp(packageName: String) = try {
        val intent = packageManager.getLeanbackLaunchIntentForPackage(packageName)
                ?: packageManager.getLaunchIntentForPackage(packageName)
        startActivity(intent)
        true
    } catch (e: Exception) {
        false
    }

    private fun openSettings() = try {
        startActivity(Intent(Settings.ACTION_SETTINGS))
        true
    } catch (e: Exception) {
        false
    }

    private fun openAppInfo(packageName: String) = try {
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.fromParts("package", packageName, null))
                .let(::startActivity)
        true
    } catch (e: Exception) {
        false
    }

    private fun uninstallApp(packageName: String) = try {
        Intent(ACTION_DELETE)
                .setData(Uri.fromParts("package", packageName, null))
                .let(::startActivity)
        true
    } catch (e: Exception) {
        false
    }

    private fun checkForGetContentAvailability() = try {
        val intentActivities = packageManager.queryIntentActivities(Intent(ACTION_GET_CONTENT, null).setTypeAndNormalize("image/*"), 0)
        intentActivities.isNotEmpty()
    } catch (e: Exception) {
        false
    }

    private fun isDefaultLauncher() = try {
        val defaultLauncher = packageManager.resolveActivity(Intent(ACTION_MAIN).addCategory(CATEGORY_HOME), 0)
        defaultLauncher?.activityInfo?.packageName == packageName
    } catch (e: Exception) {
        false
    }

    private fun startAmbientMode() = try {
        Intent(ACTION_MAIN)
            .setClassName("com.android.systemui", "com.android.systemui.Somnambulator")
            .let(::startActivity)
        true
    } catch (e: Exception) {
        false
    }

    private fun switchHdmiInput(port: Int): Boolean {
        return try {
            val tvInputManager = getSystemService(Context.TV_INPUT_SERVICE) as? TvInputManager
            val inputs = tvInputManager?.tvInputList ?: emptyList()
            val hdmiInputs = inputs.filter { it.type == TvInputInfo.TYPE_HDMI }
            val targetInput = hdmiInputs.firstOrNull {
                it.id.contains("HDMI$port", ignoreCase = true) ||
                it.id.contains("HW$port", ignoreCase = true) ||
                it.id.endsWith("/$port") ||
                it.loadLabel(this).toString().contains("$port")
            } ?: hdmiInputs.getOrNull((port - 1).coerceAtLeast(0))

            if (targetInput != null) {
                val uri = TvContract.buildChannelUriForPassthroughInput(targetInput.id)
                val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                true
            } else {
                launchApp("com.tcl.tv")
            }
        } catch (e: Exception) {
            launchApp("com.tcl.tv")
        }
    }

    private fun drawableToByteArray(drawable: Drawable): ByteArray? {
        if (drawable.intrinsicWidth <= 0 || drawable.intrinsicHeight <= 0) {
            return null
        }

        fun drawableToBitmap(drawable: Drawable): Bitmap {
            val bitmap = Bitmap.createBitmap(drawable.intrinsicWidth, drawable.intrinsicHeight, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            return bitmap
        }

        val bitmap = drawableToBitmap(drawable)
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return stream.toByteArray()
    }
}
