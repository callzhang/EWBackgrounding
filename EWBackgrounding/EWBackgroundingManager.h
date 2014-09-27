//
//  EWSleepManager.h
//  Woke
//
//  Created by Lee on 8/6/14.
//  Copyright (c) 2014 Shens. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kLocalNotificationTypeKey   @"tyoe"
#define kLocalNotificationTypeReactivate    @"reactivate"
#define kAlarmTimerCheckInterval    120
@import UIKit;

@class EWTaskItem;

@interface EWBackgroundingManager : NSObject
@property (nonatomic) BOOL sleeping;
@property (nonatomic) EWTaskItem *task;

+ (EWBackgroundingManager *)sharedInstance;
+ (BOOL)supportBackground;
- (void)startBackgrounding;
- (void)endBackgrounding;

- (void)backgroundKeepAlive:(NSTimer *)timer;
@end
