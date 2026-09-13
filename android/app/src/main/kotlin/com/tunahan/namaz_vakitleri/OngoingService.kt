package com.tunahan.namaz_vakitleri

import android.app.Notification
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

/**
 * Kalıcı bildirimi taşıyan ön plan servisi.
 *
 * Neden gerekli: sıradan bir bildirim, sistem ya da üretici pil yönetimi
 * (Samsung "uyuyan uygulamalar", Xiaomi, Huawei…) uygulamayı durdurduğunda
 * siliniyor. Uygulama zorla durdurulunca alarmlar da silindiği için hiçbir
 * emniyet ağı onu geri getiremiyordu. Ön plan servisinin bildirimi sistemce
 * korunur ve süreci öldürülmeye karşı en yüksek önceliğe taşır.
 *
 * Servis hiçbir iş yapmaz: geri sayımı yine sistem (`Chronometer`) işletir,
 * vakit geçişlerini yine [AlarmScheduler] zamanlar. Tek görevi bildirimi
 * ön planda tutmaktır.
 */
class OngoingService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = OngoingNotification.build(this)

        // `startForegroundService` ile başlatılan servis birkaç saniye içinde
        // `startForeground` çağırmak **zorunda**; çağırmazsa sistem uygulamayı
        // çökertir. Gösterecek bir şey kalmadıysa da önce çağırıp sonra kapanıyoruz.
        val promoted = promote(notification ?: OngoingNotification.placeholder(this))

        if (notification == null) {
            if (promoted) {
                ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
            }
            stopSelf()
            return START_NOT_STICKY
        }

        if (!promoted) {
            // Android 12+ bazı durumlarda (ör. sistemin servisi kendiliğinden
            // yeniden başlatması) ön plana geçişe izin vermiyor. Bildirim yine
            // de görünsün; servis olmadan eskisi gibi çalışır.
            OngoingNotification.notifyPlain(this, notification)
            stopSelf()
            return START_NOT_STICKY
        }

        isRunning = true
        // Süreç öldürülürse sistem servisi yeniden başlatsın, bildirim geri gelsin.
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }

    private fun promote(notification: Notification): Boolean = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                Notifications.ID_ONGOING,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(Notifications.ID_ONGOING, notification)
        }
        true
    } catch (e: Exception) {
        Log.w(TAG, "Ön plana geçilemedi", e)
        false
    }

    companion object {
        private const val TAG = "OngoingService"

        /** Servis ön planda ve bildirimi taşıyor. Süreç ölünce kendiliğinden sıfırlanır. */
        @Volatile
        var isRunning = false
            private set

        /**
         * Servisi başlatmayı dener. Android 12'den beri arka plandan ön plan
         * servisi başlatmak yalnızca belirli durumlarda serbest (uygulama
         * önde, tam zamanlı alarm, yeniden başlatma, uygulama güncellemesi);
         * izin yoksa `false` döner ve çağıran bildirimi kendisi basar.
         */
        fun tryStart(context: Context): Boolean = try {
            ContextCompat.startForegroundService(
                context, Intent(context, OngoingService::class.java)
            )
            true
        } catch (e: Exception) {
            Log.i(TAG, "Servis şu an başlatılamıyor: ${e.javaClass.simpleName}")
            false
        }

        /**
         * Servisi durdurur.
         *
         * Yalnızca ön plana geçmiş servis durduruluyor: başlatılıp henüz
         * `startForeground` çağırmamış bir servisi durdurmak uygulamayı
         * çökertir. O ara durumdaki servis zâten gösterecek bir şey
         * bulamayınca kendini kapatıyor.
         */
        fun stop(context: Context) {
            if (!isRunning) return
            runCatching { context.stopService(Intent(context, OngoingService::class.java)) }
        }
    }
}
