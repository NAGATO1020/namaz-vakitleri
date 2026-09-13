package com.tunahan.namaz_vakitleri

/**
 * Kalıcı bildirimin o an ne göstermesi gerektiği.
 *
 * Android'e bağımlı değil; kararın kendisi birim testleriyle korunuyor
 * (bkz. `OngoingContentTest`).
 */
sealed class OngoingContent {

    /** Kullanıcı kapattı ya da elde hiç vakit yok (şehir henüz seçilmedi). */
    object Hidden : OngoingContent()

    /**
     * Veri var ama gelecek vakit kalmadı.
     *
     * Eskiden bu durumda bildirim siliniyordu; kullanıcı bunu "uygulama
     * bildirimi kapattı" diye görüyordu. Artık bildirim yerinde kalıp
     * vakitlerin yenilenmesi gerektiğini söylüyor.
     */
    object Stale : OngoingContent()

    /** Sıradaki vakte geri sayım. */
    data class Countdown(
        val schedule: PrayerSchedule,
        val upcoming: PrayerSchedule.Upcoming
    ) : OngoingContent()

    companion object {
        fun decide(
            snapshot: PrayerStore.Snapshot,
            deviceNow: Long = System.currentTimeMillis()
        ): OngoingContent {
            if (!snapshot.persistentEnabled || !snapshot.hasData) return Hidden
            val schedule = PrayerSchedule(snapshot)
            val upcoming = schedule.next(deviceNow) ?: return Stale
            return Countdown(schedule, upcoming)
        }
    }
}
