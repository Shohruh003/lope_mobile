import Flutter
import UIKit
import FirebaseCore
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Native-side Firebase configure BEFORE any Dart runs. Without this,
    // firebase_messaging's iOS swizzling races Dart's Firebase.initializeApp()
    // and never wires up the APNs delegate — the tell-tale log is
    // "[FirebaseCore][I-COR000005] No app has been configured yet." which
    // appears BEFORE our [FCM] traces. Fixes 'apns-token-not-set' on real
    // devices where all the App ID / entitlements setup is already correct.
    FirebaseApp.configure()
    // Explicit APNs registration so iOS starts the handshake even if the
    // Flutter plugin's requestPermission() hasn't fired yet.
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
