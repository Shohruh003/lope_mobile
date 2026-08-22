package uz.lopestyle.lope_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    createNotificationChannel()
  }

  // Firebase auto-creates a channel using the `channelId` from the push
  // payload IF one doesn't exist — but at IMPORTANCE_DEFAULT (medium),
  // which shows the notification in the tray but NO sound and NO
  // heads-up banner. We create the same-id channel first with HIGH
  // importance + default notification sound so the barber actually
  // hears + sees the incoming booking. Channel ID must match the
  // `channelId: 'lopestyle_notifications'` used in
  // backend/src/firebase/firebase.service.ts.
  private fun createNotificationChannel() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    val channelId = "lopestyle_notifications"
    // Recreate if already registered with the wrong importance — Android
    // otherwise treats the existing channel as immutable and our HIGH
    // importance change never takes effect.
    val existing = nm.getNotificationChannel(channelId)
    if (existing != null && existing.importance == NotificationManager.IMPORTANCE_HIGH) return
    if (existing != null) nm.deleteNotificationChannel(channelId)
    val channel = NotificationChannel(
      channelId,
      "Bildirishnomalar",
      NotificationManager.IMPORTANCE_HIGH,
    ).apply {
      description = "Yangi bron, bekor qilish va boshqa muhim xabarlar"
      enableVibration(true)
      setSound(
        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
        AudioAttributes.Builder()
          .setUsage(AudioAttributes.USAGE_NOTIFICATION)
          .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
          .build(),
      )
    }
    nm.createNotificationChannel(channel)
  }
}
