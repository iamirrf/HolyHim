import Foundation

struct HolyHimCalendarVerse: Codable, Equatable {
  let day: Int
  let reference: String
  let verse: String
  let artId: String?
}

struct HolyHimWidgetData: Codable, Equatable {
  let day: Int
  let title: String
  let reference: String
  let teaser: String
  let timeZone: String?
  let artPath: String?
  let nextDay: Int?
  let nextReference: String?
  let nextTeaser: String?
  let nextTitle: String?
  let unlockAt: TimeInterval?
  var theme: String? = nil
  var colors: [String]? = nil
  var accent: String? = nil
  var ink: String? = nil
  var artAsset: String? = nil
  var accessRequired: Bool? = nil

  static let appGroup = "group.com.holyhim.app"
  static let storageKey = "widgetData"
  static let placeholder: HolyHimWidgetData = {
    var value = HolyHimWidgetData(
      day: 1, title: "Lifetime access required", reference: "Open HolyHim",
      teaser: "Sign in or restore your lifetime access to see today's verse.",
      timeZone: nil, artPath: nil, nextDay: nil, nextReference: nil, nextTeaser: nil,
      nextTitle: nil, unlockAt: nil)
    value.accessRequired = true
    return value
  }()
  static let catalog: [HolyHimCalendarVerse] = {
    guard let url = Bundle.main.url(forResource: "WidgetVerses", withExtension: "json"),
          let bytes = try? Data(contentsOf: url),
          let verses = try? JSONDecoder().decode([HolyHimCalendarVerse].self, from: bytes) else { return [] }
    return verses
  }()
  static func read() -> HolyHimWidgetData {
    guard let json = UserDefaults(suiteName: appGroup)?.string(forKey: storageKey),
          let bytes = json.data(using: .utf8),
          let value = try? JSONDecoder().decode(HolyHimWidgetData.self, from: bytes),
          (1...365).contains(value.day), !value.reference.isEmpty else { return placeholder }
    return value
  }
  var calendar: Calendar {
    var result = Calendar(identifier: .gregorian)
    // A widget must follow the device after travel, even before the app reopens.
    result.timeZone = .current
    return result
  }
  func content(at date: Date, calendar: Calendar? = nil) -> HolyHimWidgetData {
    Self.dailyContent(at: date, source: self, verses: Self.catalog, calendar: calendar)
  }
  static func dailyContent(at date: Date, source: HolyHimWidgetData,
                           verses: [HolyHimCalendarVerse], calendar: Calendar? = nil) -> HolyHimWidgetData {
    guard source.accessRequired == false else { return Self.placeholder }
    guard !verses.isEmpty else { return source }
    let parts = (calendar ?? source.calendar).dateComponents([.year, .month, .day], from: date)
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(secondsFromGMT: 0)!
    let civil = utc.date(from: parts)!
    let anchor = utc.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    let distance = utc.dateComponents([.day], from: anchor, to: civil).day!
    let index = ((distance % verses.count) + verses.count) % verses.count
    let verse = verses[index]
    var result = HolyHimWidgetData(day: verse.day, title: "Verse of the Day", reference: verse.reference,
      teaser: verse.verse, timeZone: source.timeZone, artPath: source.day == verse.day ? source.artPath : nil,
      nextDay: nil, nextReference: nil, nextTeaser: nil, nextTitle: nil, unlockAt: nil)
    result.theme = source.theme; result.colors = source.colors
    result.accent = source.accent; result.ink = source.ink; result.artAsset = verse.artId
    result.accessRequired = false
    return result
  }
}
struct HolyHimWidgetSnapshot: Equatable {
  let date: Date
  let content: HolyHimWidgetData
}
enum HolyHimWidgetSchedule {
  static func nextMidnight(after date: Date, calendar: Calendar = .current) -> Date {
    calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
  }
  static func snapshots(for content: HolyHimWidgetData, now: Date,
                        calendar: Calendar? = nil) -> [HolyHimWidgetSnapshot] {
    let calendar = calendar ?? content.calendar
    return (0..<8).map { offset in
      let date = offset == 0 ? now : calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now))!
      return HolyHimWidgetSnapshot(date: date, content: content.content(at: date, calendar: calendar))
    }
  }
}
