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
    //
    // Guard against double-configure: with UISceneDelegate lifecycle the
    // launch path can end up here after Dart has already called
    // Firebase.initializeApp(), and calling configure() twice throws
    // NSException 'Default app has already been configured'. Only
    // configure if no app exists yet.
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    // Explicit APNs registration so iOS starts the handshake even if the
    // Flutter plugin's requestPermission() hasn't fired yet.
    //
    // DO NOT set `UNUserNotificationCenter.current().delegate = self` —
    // firebase_messaging swizzles this delegate to install its own
    // implementation, which in turn honours the Flutter-side
    // setForegroundNotificationPresentationOptions(alert:true,...) call.
    // Overriding the delegate to `self` (with no willPresent method)
    // silently reverts iOS to its default foreground behaviour: the
    // banner is suppressed and onMessage never fires. Background push
    // still works because it takes a different path.
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
