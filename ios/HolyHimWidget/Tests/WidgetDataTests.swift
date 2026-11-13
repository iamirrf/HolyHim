import Foundation
@main
struct WidgetDataTests {
  static func main() throws {
    let json = #"{"day":1,"timeZone":"America/New_York","title":"Verse of the Day","reference":"Psalm 46:1","teaser":"Refuge","accent":"FF9D3156","colors":["FFFFFCFA","FFE7EDDF"],"accessRequired":false}"#
    let content = try JSONDecoder().decode(HolyHimWidgetData.self, from: Data(json.utf8))
    let verses = [HolyHimCalendarVerse(day: 1,reference: "Psalm 46:1",verse: "Refuge",artId: "sky-dawn"),
                  HolyHimCalendarVerse(day: 2,reference: "Psalm 23:1",verse: "Shepherd",artId: "jesus-dawn")]
    let formatter = ISO8601DateFormatter()
    let before = formatter.date(from:"2026-11-02T04:59:00Z")!
    let after = formatter.date(from:"2026-11-02T05:00:00Z")!
    var newYork = Calendar(identifier:.gregorian)
    newYork.timeZone = TimeZone(identifier:"America/New_York")!
    let first = HolyHimWidgetData.dailyContent(at:before,source:content,verses:verses,calendar:newYork)
    let second = HolyHimWidgetData.dailyContent(at:after,source:content,verses:verses,calendar:newYork)
    precondition(first.day == 1 && second.day == 2, "independent verse switches at local midnight")
    let locked = HolyHimWidgetData.dailyContent(at:after,source:.placeholder,verses:verses,calendar:newYork)
    precondition(locked.accessRequired == true && locked.title == "Lifetime access required", "signed-out widget never rotates bundled verses")
    precondition(second.artPath == nil && second.artAsset == "jesus-dawn", "art follows the new daily verse")
    precondition(second.accent == content.accent && second.colors == content.colors, "theme persists through midnight")
    var calendar = Calendar(identifier:.gregorian)
    calendar.timeZone = TimeZone(identifier:"America/New_York")!
    let spring = formatter.date(from:"2026-03-08T05:30:00Z")!
    precondition(formatter.string(from:HolyHimWidgetSchedule.nextMidnight(after:spring,calendar:calendar)) == "2026-03-09T04:00:00Z")
    let fall = formatter.date(from:"2026-11-01T04:30:00Z")!
    precondition(formatter.string(from:HolyHimWidgetSchedule.nextMidnight(after:fall,calendar:calendar)) == "2026-11-02T05:00:00Z")
    precondition(HolyHimWidgetSchedule.snapshots(for:content,now:before).count == 8)
    var tokyo = Calendar(identifier:.gregorian)
    tokyo.timeZone = TimeZone(identifier:"Asia/Tokyo")!
    let arrival = formatter.date(from:"2026-01-01T17:00:00Z")!
    let travelled = HolyHimWidgetData.dailyContent(at:arrival,source:content,verses:verses,calendar:tokyo)
    precondition(travelled.day == 2, "device calendar wins over the previously synchronized account zone")
    precondition(formatter.string(from:HolyHimWidgetSchedule.nextMidnight(after:arrival,calendar:tokyo)) == "2026-01-02T15:00:00Z")
    let data = try JSONEncoder().encode(content)
    let restored = try JSONDecoder().decode(HolyHimWidgetData.self,from:data)
    precondition(restored == content)
    print("Widget data tests passed: calendar rotation, local midnight, DST, travel, theme, artwork, and JSON.")
  }
}
