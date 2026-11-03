#import <Foundation/Foundation.h>
#import "SqfliteDarwinDatabase.h"

// Exercise the exact Objective-C SQLite wrapper shipped by sqflite_darwin.
// The runner passes the application's real onConfigure calls in source order.
int main(int argc, const char *argv[]) {
  @autoreleasepool {
    if (argc < 4 || (argc - 2) % 2 != 0) return 2;
    SqfliteDarwinDatabase *db = [SqfliteDarwinDatabase databaseWithPath:@(argv[1])];
    if (![db open]) return 3;
    for (int index = 2; index < argc; index += 2) {
      NSString *operation = @(argv[index]);
      NSString *sql = @(argv[index + 1]);
      if ([operation isEqualToString:@"execute"]) {
        if (![db executeUpdate:sql]) {
          fprintf(stderr, "Native configuration rejected execute: %s\n", sql.UTF8String);
          return 4;
        }
      } else if ([operation isEqualToString:@"rawQuery"]) {
        SqfliteDarwinResultSet *rows = [db executeQuery:sql];
        if (rows == nil) return 5;
        while ([rows next]) {}
        [rows close];
      } else {
        return 6;
      }
    }
    // Configuration must permit the first durable write and preserve settings.
    if (![db executeUpdate:@"CREATE TABLE startup_check (value TEXT NOT NULL)"] ||
        ![db executeUpdate:@"INSERT INTO startup_check VALUES ('durable')"]) return 7;
    SqfliteDarwinResultSet *rows = [db executeQuery:@"PRAGMA secure_delete"];
    if (![rows next] || [rows intForColumnIndex:0] != 1) return 8;
    [rows close];
    rows = [db executeQuery:@"PRAGMA synchronous"];
    if (![rows next] || [rows intForColumnIndex:0] != 2) return 9;
    [rows close];
    [db close];
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:@(argv[1]) error:nil];
    if ([attributes fileSize] == 0) return 10;
    puts("Native sqflite Darwin configuration and first durable write passed.");
  }
  return 0;
}
