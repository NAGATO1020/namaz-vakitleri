package com.tunahan.namaz_vakitleri

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.util.Log
import java.util.Calendar
import java.util.concurrent.Executors

/**
 * Vakitleri günde bir kez, uygulama açılmadan tazeler.
 *
 * Neden gerekli: Fazilet Takvimi yalnızca dün/bugün/yarını veriyor. Kullanıcı
 * uygulamayı üç gün açmazsa elde vakit kalmıyor ve bildirim susuyor. Türkiye
 * Takvimi'nde aylık indirme yapılabildiği için orada bu bir emniyet ağı.
 *
 * Flutter uyandırılmaz; indirme ve ayrıştırma tamamen native tarafta
 * ([SourceFetcher]) yapılır ve sonuç [PrayerStore]'a yazılır. Uygulama bir
 * sonraki açılışında kendi veritabanını zaten tazeliyor.
 */
object DailyRefresh {

    private const val TAG = "DailyRefresh"

    /**
     * Yenileme saati (şehrin yerel saatiyle değil, cihaz saatiyle).
     * Gece 03:00 seçildi: İmsâk'ten önce, kullanıcı uyanmadan veri hazır olur.
     */
    private const val HOUR_OF_DAY = 3

    /**
     * İki deneme arasındaki en kısa süre.
     *
     * Kaynak elindekinden daha ilerisini veremiyorsa (Fazilet hep aynı üç günü
     * döndürür) `isRunningLow` sürekli doğru kalır. Bu bekleme olmasaydı her
     * tetiklenmede yeniden istek atılır, kaynağa boşuna yük binerdi.
     */
    private const val MIN_INTERVAL_MS = 6 * 60 * 60 * 1000L

    private const val PREFS = "DailyRefreshState"
    private const val KEY_LAST_ATTEMPT = "last_attempt"

    private val executor = Executors.newSingleThreadExecutor()

    /** Aynı anda birden çok yenileme başlamasın. */
    @Volatile
    private var running = false

    /** Bir sonraki günlük yenilemeyi zamanlar. */
    fun schedule(context: Context) {
        AlarmScheduler.scheduleDailyRefresh(context, nextRunAt())
    }

    /**
     * Elde veri azaldıysa ve son denemeden beri yeterince zaman geçtiyse
     * yeniler. Alarm dışındaki tetikleyiciler (açılış, yeniden başlatma,
     * saat değişimi) bunu çağırır.
     */
    fun runIfNeeded(context: Context) {
        val snapshot = PrayerStore.read(context)
        if (!isRunningLow(snapshot)) return

        val last = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getLong(KEY_LAST_ATTEMPT, 0L)
        if (System.currentTimeMillis() - last < MIN_INTERVAL_MS) return

        run(context)
    }

    /**
     * Veriyi çeker ve saklar. Ağ işi olduğu için arka plan iş parçacığında
     * yürür.
     *
     * [onFinished] iş bittiğinde çağrılır — yayın alıcısının `goAsync()`
     * kilidini bırakması için.
     */
    fun run(context: Context, onFinished: (() -> Unit)? = null) {
        val appContext = context.applicationContext
        if (running) {
            onFinished?.invoke()
            return
        }
        running = true

        appContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putLong(KEY_LAST_ATTEMPT, System.currentTimeMillis())
            .apply()

        executor.execute {
            try {
                refreshNow(appContext)
            } catch (e: Exception) {
                Log.w(TAG, "Günlük yenileme başarısız", e)
            } finally {
                running = false
                // Başarısız olsa da bir sonraki günü kur; internet yarın gelebilir.
                schedule(appContext)
                onFinished?.invoke()
            }
        }
    }

    /** Ağ varsa çeker; yoksa hiç denemez. */
    private fun refreshNow(context: Context) {
        if (!isOnline(context)) {
            Log.i(TAG, "Ağ yok, yenileme atlandı")
            return
        }

        val snapshot = PrayerStore.read(context)
        if (snapshot.cityId <= 0) return

        val fetched = SourceFetcher.fetch(snapshot)

        // Saat farkını veri gelmese de güncelle: şehir başka bir ülkedeyse
        // taraflardan biri yaz saatine geçtiğinde fark bir saat yanlışa
        // düşüyor ve uygulama açılana kadar öyle kalıyordu.
        val offsetChanged = fetched.offsetMinutes
            ?.takeIf { it != snapshot.offsetMinutes }
            ?.also {
                PrayerStore.storeOffsetMinutes(context, it)
                Log.i(TAG, "Saat farkı güncellendi: $it dk")
            } != null

        if (fetched.days.isEmpty()) {
            Log.i(TAG, "Yeni veri gelmedi")
            // Fark değiştiyse vakitler aynı kalsa da alarmlar kaymıştır.
            if (offsetChanged) applyChanges(context)
            return
        }

        PrayerStore.mergeDays(context, fetched.days)
        Log.i(TAG, "${fetched.days.size} gün tazelendi")

        applyChanges(context)
    }

    /**
     * Yeni günlerle alarmları ve bildirimi yeniden kurar.
     *
     * Burada `rescheduleAll` **çağrılmıyor**: o metod yenilemeyi tekrar
     * tetikliyor ve kaynağa arka arkaya istek atan bir döngü oluşuyordu.
     */
    private fun applyChanges(context: Context) {
        AlarmScheduler.reschedulePrayerAlarms(context)
        OngoingNotification.refresh(context)
        PrayerWidgetUpdater.updateAll(context)
    }

    private fun isOnline(context: Context): Boolean {
        val manager = context.getSystemService(ConnectivityManager::class.java)
            ?: return true
        val network = manager.activeNetwork ?: return false
        val capabilities = manager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }

    /** Bir sonraki 03:00. Şu an 03:00'ı geçtiyse yarın. */
    internal fun nextRunAt(now: Long = System.currentTimeMillis()): Long {
        val calendar = Calendar.getInstance().apply {
            timeInMillis = now
            set(Calendar.HOUR_OF_DAY, HOUR_OF_DAY)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (calendar.timeInMillis <= now) calendar.add(Calendar.DAY_OF_MONTH, 1)
        return calendar.timeInMillis
    }

    /**
     * Elde kalan veri bitmek üzere mi.
     *
     * Bildirim durmadan önce erken davranmak için: son gün bugün ya da
     * geçmişse hemen bir yenileme denenir.
     */
    fun isRunningLow(snapshot: PrayerStore.Snapshot, deviceNow: Long = System.currentTimeMillis()):
        Boolean {
        val last = snapshot.lastDate ?: return true
        val today = PrayerSchedule.dateKeyOf(deviceNow + snapshot.offsetMinutes * 60_000L)
        return last <= today
    }
}
