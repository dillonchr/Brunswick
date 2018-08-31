//
//  Logger.m
//  Brunswick
//
//  Created by Dillon Christensen on 8/30/18.
//  Copyright © 2018 Dillon Christensen. All rights reserved.
//

#import "Logger.h"

@interface Logger()
@property (nonatomic, readonly) NSString *logFilePath;
@end

@implementation Logger
@synthesize logs;

- (NSString *) getLogFilePath {
    NSString *path = [[[NSProcessInfo processInfo] environment] objectForKey: @"BRUNSWICK_LOG"];
    if (path == nil) {
        path = [@"~/Desktop/handbrake.log" stringByExpandingTildeInPath];
    }
    return path;
}

- (void) log: (NSString *) message {
    [self.logs addObject:message];
    NSLog(@"%@", message);
}

- (void) writeLog {
    NSFileHandle *logFile = [self getLogFile];
    [logFile writeData:[[self.logs componentsJoinedByString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [logFile closeFile];
}

- (NSFileHandle *) getLogFile {
    NSString *logPath = self.logFilePath;
    if (![[NSFileManager defaultManager] fileExistsAtPath:logPath]) {
        [[NSFileManager defaultManager] createFileAtPath:logPath contents:nil attributes:nil];
    }
    
    NSFileHandle *logFile = [NSFileHandle fileHandleForWritingAtPath:logPath];
    [logFile seekToEndOfFile];
    return logFile;
}
@end
