import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:holyhim/domain/daily_verse.dart';
import 'package:holyhim/data/lessons.g.dart';
import 'package:holyhim/domain/notification_plan.dart';
void main(){
  setUpAll(tzdata.initializeTimeZones);
  test('calendar rotation has a fixed anchor, wraps and handles leap days',(){
    expect(dailyVerseDay(DateTime.utc(2026,1,1),'UTC'),1);
    expect(dailyVerseDay(DateTime.utc(2027,1,1),'UTC'),1);
    expect(dailyVerseDay(DateTime.utc(2028,2,29),'UTC'),60);
    expect(dailyVerseDay(DateTime.utc(2028,3,1),'UTC'),61);
    expect(dailyVerseDay(DateTime.utc(2025,12,31),'UTC'),365);
  });
  test('local midnight changes the verse and DST never skips a date',(){
    expect(dailyVerseDay(DateTime.utc(2026,11,2,4,59),'America/New_York'),305);
    expect(dailyVerseDay(DateTime.utc(2026,11,2,5),'America/New_York'),306);
    final before=dailyVerseDay(DateTime.utc(2026,3,8,6,59),'America/New_York');
    expect(dailyVerseDay(DateTime.utc(2026,3,8,7,1),'America/New_York'),before);
    expect(dailyVerseDay(DateTime.utc(2026,11,2,5),'Asia/Tokyo'),306);
  });
  test('only the next note follows progress; the rest are the verse of the day',(){
    List<PlannedNotification> plan(Map<int,String> progress)=>notificationPlan(now:DateTime.utc(2026,11,4),timeZone:'America/New_York',minutes:420,
      name:'Mira',hearts:['peace'],completed:progress,lessons:lessons);
    final fresh=plan({}),finished=plan({for(var i=1;i<=365;i++)i:'2026-11-03'});
    // A new reader's next note is Day 1; a finished year gets the verse.
    expect(fresh.first.subtitle,startsWith('Day 1 · '));
    expect(finished.first.subtitle,endsWith(' · WEB'));
    expect(finished.skip(1).map((v)=>v.day),fresh.skip(1).map((v)=>v.day));
    expect(finished.every((v)=>v.kind==NotificationKind.daily),isTrue);
    expect(finished.first.title,'Today’s word for you, Mira');
    expect(finished.first.body,teaserExcerpt(lessons[finished.first.day-1].verse));
    expect(finished.map((v)=>v.day).toSet().length,29);
  });
}
