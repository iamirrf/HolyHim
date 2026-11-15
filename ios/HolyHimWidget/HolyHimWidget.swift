import SwiftUI
import UIKit
import WidgetKit

private struct VerseEntry: TimelineEntry {
  let date: Date
  let content: HolyHimWidgetData
}

private struct VerseProvider: TimelineProvider {
  func placeholder(in context: Context) -> VerseEntry {
    VerseEntry(date: Date(), content: .placeholder)
  }

  func getSnapshot(in context: Context, completion: @escaping (VerseEntry) -> Void) {
    let now = Date()
    let content = context.isPreview ? HolyHimWidgetData.placeholder : HolyHimWidgetData.read()
    completion(VerseEntry(date: now, content: content.content(at: now)))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<VerseEntry>) -> Void) {
    let now = Date()
    let content = HolyHimWidgetData.read()
    let entries = HolyHimWidgetSchedule.snapshots(for: content, now: now).map {
      VerseEntry(date: $0.date, content: $0.content)
    }
    let refresh = HolyHimWidgetSchedule.nextMidnight(after: now, calendar: content.calendar).addingTimeInterval(60)
    completion(Timeline(entries: entries, policy: .after(refresh)))
  }
}

private enum Palette {
  static let charcoal = Color(red: 14/255, green: 17/255, blue: 22/255)
  static let midnight = Color(red: 16/255, green: 20/255, blue: 24/255)
  static let surface = Color(red: 23/255, green: 28/255, blue: 34/255)
  static let gold = Color(red: 201/255, green: 162/255, blue: 39/255)
  static let ivory = Color(red: 242/255, green: 239/255, blue: 233/255)
}

private extension Color {
  init(hex: String) {
    let value = UInt64(hex, radix: 16) ?? 0xFFC9A227
    self.init(.sRGB, red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255,
              blue: Double(value & 255) / 255, opacity: Double((value >> 24) & 255) / 255)
  }
}
private extension HolyHimWidgetData {
  var backgroundColors: [Color] { colors?.map { Color(hex: $0) } ?? [Palette.charcoal, Palette.midnight, Palette.surface] }
  var accentColor: Color { accent.map { Color(hex: $0) } ?? Palette.gold }
  var inkColor: Color { ink.map { Color(hex: $0) } ?? Palette.ivory }
  var artImage: UIImage? {
    if let artPath, let image = UIImage(contentsOfFile: artPath) { return image }
    return artAsset.flatMap { Bundle.main.url(forResource: $0 + "-thumb", withExtension: "jpg") }.flatMap { UIImage(contentsOfFile: $0.path) }
  }
}

private struct VerseBackdrop: View {
  let content: HolyHimWidgetData

  var body: some View {
    ZStack {
      LinearGradient(colors: content.backgroundColors,
                     startPoint: .topLeading, endPoint: .bottomTrailing)
      if let image = content.artImage {
        Image(uiImage: image).resizable().scaledToFill().opacity(0.32)
      }
      RadialGradient(colors: [.white.opacity(0.8), .clear],
                     center: .topLeading, startRadius: 0, endRadius: 220)
    }
    .clipped()
    .accessibilityHidden(true)
  }
}

private struct VerseView: View {
  @Environment(\.widgetFamily) private var family
  let entry: VerseEntry

  var body: some View {
    Group {
      if family == .accessoryRectangular {
        accessory
      } else {
        homeScreen
      }
    }
    .holyHimBackground(content: entry.content, accessory: family == .accessoryRectangular)
    .widgetURL(URL(string: entry.content.accessRequired == false
      ? "holyhim://verse/\(entry.content.day)" : "holyhim://paywall"))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(entry.content.accessRequired == false
      ? "HolyHim. Day \(entry.content.day). \(entry.content.reference). \(entry.content.teaser)"
      : "HolyHim. Lifetime access required. Open the app to sign in or restore.")
  }

  private var accessory: some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 4) {
        Image(systemName: "sparkle").widgetAccentable()
        Text(entry.content.accessRequired == false ? "VERSE OF THE DAY" : "ACCESS REQUIRED")
          .font(.system(size: 10, weight: .bold, design: .rounded))
          .tracking(0.8)
      }
      Text(entry.content.teaser)
        .font(.system(size: 13, weight: .medium, design: .serif))
        .lineLimit(2)
      Text(entry.content.reference)
        .font(.system(size: 10, weight: .semibold))
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .foregroundStyle(.primary)
  }

  private var homeScreen: some View {
    HStack(alignment: .center, spacing: 18) {
      VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 10) {
        HStack(spacing: 5) {
          Image(systemName: "sparkle")
            .font(.system(size: 12, weight: .medium))
          Text("HOLYHIM")
            .font(.system(size: 10, weight: .heavy))
            .tracking(1.8)
          Spacer(minLength: 0)
          if family == .systemMedium {
            Text(entry.content.accessRequired == false ? "DAILY VERSE · WEB" : "LIFETIME ACCESS")
              .font(.system(size: 9, weight: .bold))
              .tracking(0.6)
          }
        }
        .foregroundStyle(entry.content.accentColor)
        if family == .systemMedium {
          Text(entry.content.title)
            .font(.system(size: 19, weight: .semibold, design: .serif))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        Text(entry.content.teaser)
          .font(.system(size: family == .systemSmall ? 18 : 17, weight: .regular, design: .serif))
          .lineSpacing(2)
          .lineLimit(family == .systemSmall ? 4 : 2)
          .minimumScaleFactor(0.8)
          .frame(maxHeight: .infinity, alignment: .center)
        HStack(alignment: .firstTextBaseline, spacing: 5) {
          Text(entry.content.reference)
            .font(.system(size: 10, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
          if family == .systemSmall {
            Spacer(minLength: 0)
            Text(entry.content.accessRequired == false ? "WEB" : "HOLYHIM")
              .font(.system(size: 8, weight: .bold))
          }
        }
        .foregroundStyle(entry.content.accentColor)
      }
      if family == .systemMedium, let image = entry.content.artImage {
        Image(uiImage: image)
          .resizable().scaledToFill()
          .frame(width: 70, height: 104)
          .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
          .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.8)))
          .accessibilityHidden(true)
      }
    }
    .foregroundStyle(entry.content.inkColor)
  }
}

private extension View {
  @ViewBuilder
  func holyHimBackground(content: HolyHimWidgetData, accessory: Bool) -> some View {
    if #available(iOS 17.0, *) {
      self.containerBackground(for: .widget) {
        if accessory { Color.clear } else { VerseBackdrop(content: content) }
      }
    } else if accessory {
      self
    } else {
      self.padding(16).background(VerseBackdrop(content: content))
    }
  }
}

struct HolyHimVerseWidget: Widget {
  let kind = "HolyHim"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: VerseProvider()) { entry in
      VerseView(entry: entry)
    }
    .configurationDisplayName("HolyHim")
    .description("Today's Word. A little peace for your day.")
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
  }
}

@main
struct HolyHimWidgetBundle: WidgetBundle {
  var body: some Widget { HolyHimVerseWidget() }
}
