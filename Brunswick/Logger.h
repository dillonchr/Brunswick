//
//  Logger.h
//  Brunswick
//
//  Created by Dillon Christensen on 8/30/18.
//  Copyright © 2018 Dillon Christensen. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Logger : NSObject
@property (nonatomic, retain) NSMutableArray *logs;
- (void) log: (NSString *) message;
- (void) writeLog;
@end
