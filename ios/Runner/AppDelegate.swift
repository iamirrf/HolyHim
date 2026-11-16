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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HolyHimNotifications") {
      // The real permission state, so the app can show iOS's prompt when it is
      // still possible and send her to Settings when it is not.
      let channel = FlutterMethodChannel(name: "holyhim/notifications", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "status":
          UNUserNotificationCenter.current().getNotificationSettings { settings in
            let value: String
            switch settings.authorizationStatus {
            case .notDetermined: value = "notDetermined"
            case .denied: value = "denied"
            case .authorized: value = "authorized"
            case .provisional: value = "provisional"
            case .ephemeral: value = "authorized"
            @unknown default: value = "denied"
            }
            DispatchQueue.main.async { result(value) }
          }
        case "request":
          UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { result(granted) }
          }
        case "openSettings":
          var link = UIApplication.openSettingsURLString
          if #available(iOS 16.0, *) { link = UIApplication.openNotificationSettingsURLString }
          if let url = URL(string: link) { UIApplication.shared.open(url) }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HolyHimAppIcon") {
      // The Home Screen icon she picks in Profile. Names are the asset
      // catalog's alternate icon sets; nil is the primary icon.
      let channel = FlutterMethodChannel(name: "holyhim/app-icon", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        let app = UIApplication.shared
        switch call.method {
        case "supported":
          result(app.supportsAlternateIcons)
        case "current":
          result(app.alternateIconName)
        case "set":
          guard app.supportsAlternateIcons else {
            result(FlutterError(code: "unsupported", message: "This iPhone can't change the app icon.", details: nil))
            return
          }
          app.setAlternateIconName(call.arguments as? String) { error in
            DispatchQueue.main.async {
              if let error = error {
                result(FlutterError(code: "app-icon", message: error.localizedDescription, details: nil))
              } else {
                result(app.alternateIconName)
              }
            }
          }
        default:
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
