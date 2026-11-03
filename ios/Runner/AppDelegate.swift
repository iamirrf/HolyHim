import Flutter
import UIKit
import CoreText

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var accessibilityChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @objc private func transparencyChanged() {
    accessibilityChannel?.invokeMethod("transparencyChanged", arguments: UIAccessibility.isReduceTransparencyEnabled)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HolyHerGlass") {
      registrar.register(HolyGlassFactory(), withId: "holyher/glass")
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HolyHerTypography") {
      let channel = FlutterMethodChannel(name: "holyher/typography", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "resolve":
          do {
            let regular = try RoundedTypography.font(.regular)
            let semibold = try RoundedTypography.font(.semibold)
            result(["regular": FlutterStandardTypedData(bytes: try RoundedTypography.data(regular)),
                    "semibold": FlutterStandardTypedData(bytes: try RoundedTypography.data(semibold)),
                    "regularName": regular.fontName, "semiboldName": semibold.fontName,
                    "regularVariations": RoundedTypography.variations(regular), "semiboldVariations": RoundedTypography.variations(semibold),
                    "family": regular.familyName, "design": "UIKit.SystemDesign.rounded",
                    "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
                    "appBuild": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
                    "regularWidth": ("A moment with God. 0123456789" as NSString).size(withAttributes: [.font: regular]).width,
                    "semiboldWidth": ("A moment with God. 0123456789" as NSString).size(withAttributes: [.font: semibold]).width,
                    "regularWidthZeroTracking": ("A moment with God. 0123456789" as NSString).size(withAttributes: [.font: regular, .kern: 0]).width,
                    "semiboldWidthZeroTracking": ("A moment with God. 0123456789" as NSString).size(withAttributes: [.font: semibold, .kern: 0]).width])
          } catch { result(FlutterError(code: "rounded-font", message: error.localizedDescription, details: nil)) }
        case "specimen": result(FlutterStandardTypedData(bytes: RoundedTypography.specimen()))
        case "previewViewport":
          // Isolated QA entry point only: native iPad child-view rendering at a
          // narrow multitasking-sized viewport. This is not a system Split View claim.
          guard ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--holyher-preview=") }),
                let args = call.arguments as? [String: Double] else { result(nil); return }
          DispatchQueue.main.async {
            guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
                  let window = scene.windows.first(where: { $0.isKeyWindow }),
                  let flutter = window.rootViewController else { result(nil); return }
            let host = UIViewController()
            host.view.backgroundColor = UIColor(red: 1, green: 249/255, blue: 251/255, alpha: 1)
            window.rootViewController = host
            host.addChild(flutter)
            host.view.addSubview(flutter.view)
            flutter.view.frame = CGRect(x: 0, y: 0, width: args["width"] ?? 375, height: args["height"] ?? 1000)
            flutter.view.autoresizingMask = []
            flutter.didMove(toParent: host)
            result(nil)
          }
        case "previewArguments":
          result(ProcessInfo.processInfo.arguments)
        default: result(FlutterMethodNotImplemented)
        }
      }
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HolyHerAccessibility") {
      let channel = FlutterMethodChannel(name: "holyher/accessibility", binaryMessenger: registrar.messenger())
      accessibilityChannel = channel
      channel.setMethodCallHandler { call, result in
        if call.method == "reduceTransparency" {
          result(UIAccessibility.isReduceTransparencyEnabled)
        } else { result(FlutterMethodNotImplemented) }
      }
      NotificationCenter.default.addObserver(self, selector: #selector(transparencyChanged), name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
    }
  }
}


/// Resolve Apple's system design on the running OS. The sfnt is assembled from
/// CoreText tables in memory solely for Flutter's Skia font manager.
private enum RoundedTypography {
  static func font(_ weight: UIFont.Weight) throws -> UIFont {
    let system = UIFont.systemFont(ofSize: 22, weight: weight)
    guard let descriptor = system.fontDescriptor.withDesign(.rounded) else {
      throw NSError(domain: "HolyHerTypography", code: 1, userInfo: [NSLocalizedDescriptionKey: "SF Rounded is unavailable."])
    }
    return UIFont(descriptor: descriptor, size: 22)
  }
  static func variations(_ font: UIFont) -> [String: Double] {
    var result: [String: Double] = [:]
    if let values = CTFontCopyVariation(font as CTFont) as? [NSNumber: NSNumber] {
      for (tag, value) in values {
        let n = tag.uint32Value
        let chars: [UInt8] = [UInt8((n >> 24) & 255), UInt8((n >> 16) & 255), UInt8((n >> 8) & 255), UInt8(n & 255)]
        if let key = String(bytes: chars, encoding: .ascii) { result[key] = value.doubleValue }
      }
    }
    return result
  }
  static func word(_ value: UInt32) -> Data {
    var n = value.bigEndian
    return withUnsafeBytes(of: &n) { Data($0) }
  }
  static func short(_ value: UInt16) -> Data {
    var n = value.bigEndian
    return withUnsafeBytes(of: &n) { Data($0) }
  }
  static func checksum(_ bytes: Data) -> UInt32 {
    let b = [UInt8](bytes) + [0, 0, 0]
    var sum: UInt32 = 0
    for i in stride(from: 0, to: bytes.count, by: 4) {
      sum = sum &+ (UInt32(b[i]) << 24 | UInt32(b[i+1]) << 16 | UInt32(b[i+2]) << 8 | UInt32(b[i+3]))
    }
    return sum
  }
  static func u16(_ bytes: Data, _ offset: Int) -> UInt16 {
    UInt16(bytes[offset]) << 8 | UInt16(bytes[offset+1])
  }
  static func i16(_ bytes: Data, _ offset: Int) -> Int16 { Int16(bitPattern: u16(bytes, offset)) }
  static func u32(_ bytes: Data, _ offset: Int) -> UInt32 {
    UInt32(bytes[offset]) << 24 | UInt32(bytes[offset+1]) << 16 | UInt32(bytes[offset+2]) << 8 | UInt32(bytes[offset+3])
  }
  static func axisValue(_ bytes: Data, _ offset: Int) -> Double { Double(Int32(bitPattern: u32(bytes,offset))) / 65536 }
  static func signedShort(_ value: Double) -> Data {
    short(UInt16(bitPattern: Int16(clamping: Int((value * 16384).rounded()))))
  }
  /// UIKit's UI font applies per-em tracking that a raw SF table face lacks.
  /// Resolve that advance through the native specimen, rather than assuming a
  /// family alias or scaling text. Zero-width combining marks remain zero.
  static func adapt(_ tables: inout [(UInt32, Data)]) throws {
    guard let metricsIndex=tables.firstIndex(where:{$0.0==0x686D7478}),
          let hhea=tables.first(where:{$0.0==0x68686561})?.1,
          let head=tables.first(where:{$0.0==0x68656164})?.1 else { return }
    let regular=try font(.regular), units=Double(u16(head,18)), count=Int(u16(hhea,34))
    var character: UniChar=72, glyph: CGGlyph=0
    CTFontGetGlyphsForCharacters(regular as CTFont,&character,&glyph,1)
    var metrics=tables[metricsIndex].1
    let raw=Double(u16(metrics,min(Int(glyph),count-1)*4))
    let measured=("HHHHHHHH" as NSString).size(withAttributes:[.font:regular,.kern:0]).width
    let tracking=Int((Double(measured)/8/Double(regular.pointSize)*units-raw).rounded())
    for index in 0..<count {
      let offset=index*4, advance=Int(u16(metrics,offset))
      if advance>0 { metrics.replaceSubrange(offset..<(offset+2),with:short(UInt16(clamping:advance+tracking))) }
    }
    tables[metricsIndex].1=metrics
    // FontWeight 600 is the app's semibold role. Map its variable coordinate
    // to the semibold UIKit actually resolved on this OS (regular remains 400).
    guard let fvar=tables.first(where:{$0.0==0x66766172})?.1 else { return }
    let axisCount=Int(u16(fvar,8)), axisSize=Int(u16(fvar,10)), axisStart=Int(u16(fvar,4))
    let avarIndex=tables.firstIndex(where:{$0.0==0x61766172})
    let old=avarIndex.map{tables[$0].1}
    // Version 2 also carries variation stores; preserve it instead of dropping data.
    if let old=old, u16(old,0) != 1 { return }
    var cursor=8, maps=[[(Double,Double)]]()
    for axis in 0..<axisCount {
      var points:[(Double,Double)]=[(-1,-1),(0,0),(1,1)]
      if let old=old {
        let n=Int(u16(old,cursor));cursor+=2
        points=(0..<n).map { (Double(i16(old,cursor+$0*4))/16384,Double(i16(old,cursor+$0*4+2))/16384) };cursor+=n*4
      }
      let offset=axisStart+axis*axisSize
      if u32(fvar,offset)==0x77676874 {
        let minimum=axisValue(fvar,offset+4), normal=axisValue(fvar,offset+8), maximum=axisValue(fvar,offset+12)
        func normalize(_ value:Double)->Double { value<normal ? (value-normal)/(normal-minimum) : (value-normal)/(maximum-normal) }
        let resolved=variations(try font(.semibold))["wght"] ?? 600
        let desired=normalize(resolved), input=normalize(600)
        var output=desired
        for i in 0..<(points.count-1) where desired>=points[i].0 && desired<=points[i+1].0 {
          let lower=points[i],upper=points[i+1]
          output=lower.1+(upper.1-lower.1)*(desired-lower.0)/(upper.0-lower.0);break
        }
        points.removeAll{abs($0.0-input)<0.0001};points.append((input,output));points.sort{$0.0<$1.0}
      }
      maps.append(points)
    }
    var adapted=short(1);adapted.append(short(0));adapted.append(short(0));adapted.append(short(UInt16(axisCount)))
    for points in maps { adapted.append(short(UInt16(points.count)));for point in points { adapted.append(signedShort(point.0));adapted.append(signedShort(point.1)) } }
    if let index=avarIndex { tables[index].1=adapted } else { tables.append((0x61766172,adapted));tables.sort{$0.0<$1.0} }
  }
  static func data(_ font: UIFont) throws -> Data {
    let ct = font as CTFont
    guard let available = CTFontCopyAvailableTables(ct, CTFontTableOptions(rawValue: 0)) else {
      throw NSError(domain: "HolyHerTypography", code: 2)
    }
    // CoreText stores CTFontTableTag values as raw pointer-sized integers in
    // this CFArray. Bridging it to [NSNumber] would try to retain e.g. GDEF.
    let tags = (0..<CFArrayGetCount(available)).map {
      UInt32(truncatingIfNeeded: UInt(bitPattern: CFArrayGetValueAtIndex(available, $0)))
    }.sorted()
    var tables: [(UInt32, Data)] = []
    for tag in tags {
      if let table = CTFontCopyTable(ct, tag, CTFontTableOptions(rawValue: 0)) {
        // Device system-font tables may live in read-only mapped pages.
        // Allocate writable bytes explicitly before adapting metrics/checksums.
        let length = CFDataGetLength(table)
        var bytes = Data(bytes: CFDataGetBytePtr(table)!, count: length)
        if tag == 0x68656164 && bytes.count >= 12 { bytes.replaceSubrange(8..<12, with: [0,0,0,0]) }
        tables.append((tag, bytes))
      }
    }
    try adapt(&tables)
    let count = UInt16(tables.count)
    let power = UInt16(pow(2, floor(log2(Double(count)))))
    var output = word(tags.contains(0x43464620) ? 0x4F54544F : 0x00010000)
    output.append(short(count)); output.append(short(power * 16))
    output.append(short(UInt16(log2(Double(power))))); output.append(short(count * 16 - power * 16))
    var payload = Data(), headOffset: Int?
    for (tag, bytes) in tables {
      let offset = 12 + Int(count) * 16 + payload.count
      output.append(word(tag)); output.append(word(checksum(bytes)))
      output.append(word(UInt32(offset))); output.append(word(UInt32(bytes.count)))
      if tag == 0x68656164 { headOffset = offset }
      payload.append(bytes)
      while payload.count % 4 != 0 { payload.append(0) }
    }
    output.append(payload)
    if let offset = headOffset {
      output.replaceSubrange((offset+8)..<(offset+12), with: word(0xB1B0AFBA &- checksum(output)))
    }
    return output
  }
  static func specimen() -> Data {
    let format = UIGraphicsImageRendererFormat(); format.scale = UIScreen.main.scale
    return UIGraphicsImageRenderer(size: CGSize(width: 393, height: 220), format: format).pngData { context in
      UIColor(red: 1, green: 249/255, blue: 251/255, alpha: 1).setFill()
      context.fill(CGRect(x: 0, y: 0, width: 393, height: 220))
      for (index, weight) in [UIFont.Weight.regular, .semibold].enumerated() {
        let style: [NSAttributedString.Key: Any] = [.font: try! font(weight), .foregroundColor: UIColor(red: 56/255, green: 35/255, blue: 49/255, alpha: 1)]
        ("A moment with God.\nHolyHer 0123456789" as NSString).draw(in: CGRect(x: 24, y: 24 + index * 96, width: 345, height: 80), withAttributes: style)
      }
    }
  }
}

private class HolyGlassFactory: NSObject, FlutterPlatformViewFactory {
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView { HolyGlassView(frame: frame, arguments: args) }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
}
private class HolyGlassView: NSObject, FlutterPlatformView {
  private let content: UIVisualEffectView
  init(frame: CGRect, arguments: Any?) {
    let values = arguments as? [String: Any]
    let dark = values?["dark"] as? Bool ?? false
    let tint = (values?["tint"] as? NSNumber)?.uint32Value ?? 0xFFFFFAF7
    let color = UIColor(red: CGFloat((tint >> 16) & 255) / 255, green: CGFloat((tint >> 8) & 255) / 255, blue: CGFloat(tint & 255) / 255, alpha: 0.28)
    if #available(iOS 26.0, *) {
      let glass = UIGlassEffect(style: .regular)
      glass.tintColor = color
      content = UIVisualEffectView(effect: glass)
    } else { content = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial)) }
    super.init()
    content.frame = frame
    content.overrideUserInterfaceStyle = dark ? .dark : .light
    content.layer.cornerRadius = 34
    content.clipsToBounds = true
    content.isUserInteractionEnabled = false
    content.accessibilityElementsHidden = true
  }
  func view() -> UIView { content }
}
