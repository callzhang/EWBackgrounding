//
//  EWSleepManager.m
//  SleepManager
//  Manage the backgrounding. Currently only support backgrounding during sleep.
//  Will support sleep music and statistics later
//
//  Created by Lee on 8/6/14.
//  Copyright (c) 2014 Woke. All rights reserved.
//

#import "EWBackgroundingManager.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>


@interface EWBackgroundingManager(){
    NSTimer *backgroundingtimer;
    UIBackgroundTaskIdentifier backgroundTaskIdentifier;
    UILocalNotification *backgroundingFailNotification;
    BOOL BACKGROUNDING_FROM_START;
    AVPlayer *avplayer;
}

@end

@implementation EWBackgroundingManager

+ (EWBackgroundingManager *)sharedInstance{
    static EWBackgroundingManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[EWBackgroundingManager alloc] init];
    });
    
    return manager;
}

- (id)init{
    self = [super init];
    if (self) {
        //enter background
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
        //enter foreground
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
        //resign active
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willResignActive) name:UIApplicationWillResignActiveNotification object:nil];
        //become active
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didbecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
        

        BACKGROUNDING_FROM_START = YES;
    }
    
    return self;
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
}

+ (BOOL)supportBackground{
    BOOL supported;
    if ([[UIDevice currentDevice] respondsToSelector:@selector(isMultitaskingSupported)]){
        supported = [[UIDevice currentDevice] isMultitaskingSupported];
    }else {
        NSLog(@"Your device doesn't support background task. Alarm will not fire. Please change your settings.");
        supported = NO;
    }
    return supported;
}


#pragma mark - Application state change
- (void)enterBackground{
    if (self.sleeping || BACKGROUNDING_FROM_START) {
        [self startBackgrounding];
    }
}

- (void)enterForeground{
    
    [self registerAudioSession];
    [backgroundingtimer invalidate];
    
    if (!self.sleeping && !BACKGROUNDING_FROM_START) {
        [self endBackgrounding];
    }else{
        //[self startBackgrounding];
    }
    
    for (UILocalNotification *note in [UIApplication sharedApplication].scheduledLocalNotifications) {
        if ([note.userInfo[kLocalNotificationTypeKey] isEqualToString:kLocalNotificationTypeReactivate]) {
            [[UIApplication sharedApplication] cancelLocalNotification:note];
        }
    }
}


- (void)willResignActive{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    //temporarily end backgrounding
    
    //Timer will fail automatically
    //backgroundTask will stop automatically
    //notification needs to be cancelled (or delayed)
    
    if (backgroundingFailNotification) {
        [[UIApplication sharedApplication] cancelLocalNotification:backgroundingFailNotification];
    }
}

- (void)didbecomeActive{
    // This method is called to let your app know that it moved from the inactive to active state. This can occur because your app was launched by the user or the system.
    
    //resume backgrounding
    UIApplication *app = [UIApplication sharedApplication];
    if (app.applicationState != UIApplicationStateActive) {
        UILocalNotification *notif = [[UILocalNotification alloc] init];
        notif.alertBody = @"Woke become active!";
        [app scheduleLocalNotification:notif];
    }
    
    if (self.sleeping || BACKGROUNDING_FROM_START) {
        [self startBackgrounding];
    }
}

#pragma mark - Backgrounding

- (void)startBackgrounding{
    self.sleeping = YES;
    [self registerAudioSession];
    [self backgroundKeepAlive:nil];
    NSLog(@"Start Sleep");
}

- (void)endBackgrounding{
    NSLog(@"End Sleep");
    self.sleeping = NO;
    
    UIApplication *application = [UIApplication sharedApplication];
    
    if (backgroundTaskIdentifier != UIBackgroundTaskInvalid){
        //end background task
        [application endBackgroundTask:backgroundTaskIdentifier];
    }
    //stop timer
    if ([backgroundingtimer isValid]){
        [backgroundingtimer invalidate];
    }
    
    //stop backgrounding fail notif
    if (backgroundingFailNotification) {
        [[UIApplication sharedApplication] cancelLocalNotification:backgroundingFailNotification];
    }else{
        for (UILocalNotification *n in [UIApplication sharedApplication].scheduledLocalNotifications) {
            if ([n.userInfo[kLocalNotificationTypeKey] isEqualToString:kLocalNotificationTypeReactivate]) {
                [[UIApplication sharedApplication] cancelLocalNotification:n];
            }
        }
    }
}


- (void)backgroundKeepAlive:(NSTimer *)timer{
    UIApplication *application = [UIApplication sharedApplication];
    NSMutableDictionary *userInfo;
    if (timer) {
        NSInteger count;
        NSDate *start = timer.userInfo[@"start_date"];
        count = [(NSNumber *)timer.userInfo[@"count"] integerValue];
        NSLog(@"Backgrounding started at %@ is checking the %ld times", start, (long)count);
        count++;
        timer.userInfo[@"count"] = @(count);
        userInfo = timer.userInfo;
    }else{
        //first time
        userInfo = [NSMutableDictionary new];
        userInfo[@"start_date"] = [NSDate date];
        userInfo[@"count"] = @0;
    }
    
    //schedule timer
    if ([backgroundingtimer isValid]) [backgroundingtimer invalidate];
    NSInteger randomInterval = kAlarmTimerCheckInterval + arc4random_uniform(60);
    backgroundingtimer = [NSTimer scheduledTimerWithTimeInterval:randomInterval target:self selector:@selector(backgroundKeepAlive:) userInfo:userInfo repeats:NO];
    
    //start silent sound
    [self playSilentSound];
    
    //end old background task
    [application endBackgroundTask:backgroundTaskIdentifier];
    //begin a new background task
    backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        //[self backgroundTaskKeepAlive:nil];
        NSLog(@"The backgound task ended!");
    }];
    
    //check time left
    double timeLeft = application.backgroundTimeRemaining;
    NSLog(@"Background time left: %.1f", timeLeft>999?999:timeLeft);
    
    //alert user
    if (backgroundingFailNotification) {
        [[UIApplication sharedApplication] cancelLocalNotification:backgroundingFailNotification];
    }
    backgroundingFailNotification= [[UILocalNotification alloc] init];
    backgroundingFailNotification.fireDate = [[NSDate date] dateByAddingTimeInterval:200];
    backgroundingFailNotification.alertBody = @"Woke stopped running in background. Tap here to reactivate it.";
    backgroundingFailNotification.alertAction = @"Activate";
    backgroundingFailNotification.userInfo = @{kLocalNotificationTypeKey: kLocalNotificationTypeReactivate};
    backgroundingFailNotification.soundName = @"new.caf";
    [[UIApplication sharedApplication] scheduleLocalNotification:backgroundingFailNotification];
    
}


//register the BACKGROUNDING audio session
- (void)registerAudioSession{
    //deactivated first
    [[AVAudioSession sharedInstance] setActive:NO error:NULL];
    
    //audio session
    [[AVAudioSession sharedInstance] setDelegate: self];
    NSError *error = nil;
    //set category
    BOOL success = [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback
                                                    withOptions:AVAudioSessionCategoryOptionMixWithOthers
                                                          error:&error];
    if (!success) NSLog(@"AVAudioSession error setting category:%@",error);
    //force speaker
    //    success = [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker
    //                                                                 error:&error];
    //    if (!success || error) NSLog(@"AVAudioSession error overrideOutputAudioPort:%@",error);
    //set active
    success = [[AVAudioSession sharedInstance] setActive:YES error:&error];
    if (!success || error){
        NSLog(@"Unable to activate BACKGROUNDING audio session:%@", error);
    }else{
        NSLog(@"BACKGROUNDING Audio session activated!");
    }
    //set active bg sound
    [self playSilentSound];
}


- (void)playSilentSound{
#if !TARGET_IPHONE_SIMULATOR
    NSLog(@"Play silent sound");
    //NSURL *path = [[NSBundle mainBundle] URLForResource:@"tock" withExtension:@"caf"];
    NSURL *path = [[NSBundle mainBundle] URLForResource:@"tock" withExtension:@"caf"];
    [self playAvplayerWithURL:path];
#endif
}

- (void)playAvplayerWithURL:(NSURL *)url{
    
    //AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
    avplayer = [AVPlayer playerWithURL:url];
    [avplayer setActionAtItemEnd:AVPlayerActionAtItemEndPause];
    avplayer.volume = 1.0;
    if (avplayer.status == AVPlayerStatusFailed) {
        NSLog(@"!!! AV player not ready to play.");
    }
    //[avplayer addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:NULL];
    [avplayer play];
}
@end
