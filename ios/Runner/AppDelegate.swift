import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase configuration is handled by the firebase_core plugin's
    // auto-registration (GeneratedPluginRegistrant → FLTFirebaseCorePlugin).
    // Do NOT call FirebaseApp.configure() here — the plugin does it too
    // and Firebase throws NSException 'Default app has already been
    // configured' on the second call.
    //
    // Do NOT set UNUserNotificationCenter.current().delegate = self —
    // firebase_messaging swizzles this delegate to install its own
    // implementation, which honours setForegroundNotificationPresentation-
    // Options(alert:true,...). Overriding it silently suppresses the
    // foreground banner and prevents onMessage from firing.
    //
    // The only thing we still do here is kick off the APNs handshake
    // early so getAPNSToken() doesn't return null on the first launch.
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
