//
//  EWSleepManager.h
//  Woke
//
//  Created by Lee on 8/6/14.
//  Copyright (c) 2014 Shens. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Parse.h"

#define kLocalNotificationTypeKey   @"tyoe"
#define kLocalNotificationTypeReactivate    @"reactivate"
#define kAlarmTimerCheckInterval    120
@import UIKit;
@import AVFoundation;
@import AudioToolbox;

@class EWTaskItem;

@interface EWBackgroundingManager : NSObject<AVAudioSessionDelegate>
@property (nonatomic) BOOL sleeping;
@property (nonatomic) EWTaskItem *task;
@property (nonatomic, strong) PFObject *session;

+ (EWBackgroundingManager *)sharedInstance;
+ (BOOL)supportBackground;
- (void)startBackgrounding;
- (void)endBackgrounding;

- (void)backgroundKeepAlive:(NSTimer *)timer;
@end
