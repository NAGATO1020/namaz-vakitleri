package com.tunahan.namaz_vakitleri

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Flutter ile native taraf arasındaki köprü.
 *
 * Flutter yalnızca "vakitler değişti, her şeyi yenile" der; sıradaki vaktin
 * hesabı, alarmların kurulması ve bildirimin çizilmesi native tarafta olur.
 * İzinler de burada istenir — ayrı bir izin paketine gerek kalmadı.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.tunahan.namaz_vakitleri/platform"
        private const val REQUEST_NOTIFICATIONS = 5001
    }

    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Vakitler/ayarlar değişti: alarmları ve bildirimi yeniden kur.
                    "syncSchedule" -> {
                        AlarmScheduler.rescheduleAll(this)
                        PrayerWidgetUpdater.updateAll(this)
                        result.success(true)
                    }

                    "cancelAll" -> {
                        AlarmScheduler.cancelAll(this)
                        OngoingNotification.cancel(this)
                        result.success(true)
                    }

                    "notificationsAllowed" ->
                        result.success(
                            NotificationManagerCompat.from(this).areNotificationsEnabled()
                        )

                    "requestNotificationPermission" -> requestNotifications(result)

                    "canScheduleExactAlarms" ->
                        result.success(AlarmScheduler.canScheduleExact(this))

                    "openExactAlarmSettings" -> {
                        openExactAlarmSettings()
                        result.success(true)
                    }

                    "isIgnoringBatteryOptimizations" ->
                        result.success(isIgnoringBatteryOptimizations())

                    "openBatterySettings" -> {
                        openBatterySettings()
                        result.success(true)
                    }

                    "openNotificationSettings" -> {
                        openNotificationSettings()
                        result.success(true)
                    }

                    // --- havadan güncelleme ---

                    "canInstallPackages" -> result.success(canInstallPackages())

                    "openInstallPermissionSettings" -> {
                        openInstallPermissionSettings()
                        result.success(true)
                    }

                    "installApk" -> {
                        val path = call.argument<String>("path")
                        result.success(path != null && installApk(path))
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun requestNotifications(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(NotificationManagerCompat.from(this).areNotificationsEnabled())
            return
        }
        val granted = ContextCompat.checkSelfPermission(
            this, Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED

        if (granted) {
            result.success(true)
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_NOTIFICATIONS
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_NOTIFICATIONS) return
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
        if (granted) AlarmScheduler.rescheduleAll(this)
    }

    private fun openExactAlarmSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        runCatching {
            startActivity(
                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                    .setData(Uri.parse("package:$packageName"))
            )
        }.onFailure {
            // Bazı üreticilerde bu ekran yok; uygulama ayarlarına düşelim.
            openAppSettings()
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val power = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return true
        return power.isIgnoringBatteryOptimizations(packageName)
    }

    @Suppress("BatteryLife")
    private fun openBatterySettings() {
        runCatching {
            startActivity(
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    .setData(Uri.parse("package:$packageName"))
            )
        }.onFailure {
            runCatching {
                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            }.onFailure { openAppSettings() }
        }
    }

    private fun openNotificationSettings() {
        runCatching {
            startActivity(
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            )
        }.onFailure { openAppSettings() }
    }

    // --- havadan güncelleme ---

    /**
     * Android, bir uygulamanın başka bir uygulamayı **sessizce** kurmasına
     * izin vermez (cihaz sâhibi / kurumsal yönetim hâriç). Yapabildiğimiz en
     * fazlası indirilen APK'yı sistemin kurulum ekranına vermek; onayı
     * kullanıcı verir.
     */
    private fun canInstallPackages(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }

    private fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        runCatching {
            startActivity(
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
                    .setData(Uri.parse("package:$packageName"))
            )
        }.onFailure { openAppSettings() }
    }

    private fun installApk(path: String): Boolean {
        val file = File(path)
        if (!file.exists()) return false

        return runCatching {
            val uri = FileProvider.getUriForFile(
                this, "$packageName.fileprovider", file
            )
            startActivity(
                Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "application/vnd.android.package-archive")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            )
            true
        }.getOrElse { false }
    }

    private fun openAppSettings() {
        runCatching {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(Uri.parse("package:$packageName"))
            )
        }
    }
}
