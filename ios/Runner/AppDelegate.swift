import Flutter
import UIKit
import StoreKit
import UserNotifications
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var accessibilityChannel: FlutterMethodChannel?
  #if V2_VISUAL_QA
  private var visualQAEvents: [[String: Any]] = []
  #endif

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // FlutterAppDelegate forwards foreground and response callbacks to plugins.
    // Install before launch finishes so cold-start and warm taps are delivered.
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    #if V2_VISUAL_QA
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HolyHimVisualQA") {
      let channel = FlutterMethodChannel(name: "holyhim/visual-qa", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { [weak self] call, result in
        if call.method == "launchArguments" {
          result(ProcessInfo.processInfo.arguments)
        } else if call.method == "record", let event = call.arguments as? [String: Any], let self = self {
          self.visualQAEvents.append(event)
          if self.visualQAEvents.count > 1500 { self.visualQAEvents.removeFirst() }
          do {
            let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
              .appendingPathComponent("V2-QA", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: self.visualQAEvents, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: folder.appendingPathComponent("events.json"), options: .atomic)
            result(nil)
          } catch { result(FlutterError(code: "visual-qa", message: error.localizedDescription, details: nil)) }
        } else { result(FlutterMethodNotImplemented) }
      }
    }
    #endif
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HolyHimAccessibility") {
      let channel = FlutterMethodChannel(name: "holyhim/accessibility", binaryMessenger: registrar.messenger())
      accessibilityChannel = channel
      channel.setMethodCallHandler { call, result in
        if call.method == "reduceTransparency" {
          result(UIAccessibility.isReduceTransparencyEnabled)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
      NotificationCenter.default.addObserver(self, selector: #selector(transparencyChanged),
        name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HolyHimReview") {
      let channel = FlutterMethodChannel(name: "holyhim/review", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { [weak self] call, result in
        if call.method == "request" {
          self?.requestReview()
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  /// iOS decides whether to show its rating prompt and how often.
  private func requestReview() {
    if let scene = UIApplication.shared.connectedScenes
      .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
      if #available(iOS 18.0, *) {
        AppStore.requestReview(in: scene)
      } else {
        SKStoreReviewController.requestReview(in: scene)
      }
    }
  }

  @objc private func transparencyChanged() {
    accessibilityChannel?.invokeMethod("transparencyChanged", arguments: UIAccessibility.isReduceTransparencyEnabled)
  }
}
