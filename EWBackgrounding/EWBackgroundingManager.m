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
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface EWBackgroundingManager(){
    NSTimer *backgroundingtimer;
    UIBackgroundTaskIdentifier backgroundTaskIdentifier;
    UILocalNotification *backgroundingFailNotification;
    BOOL BACKGROUNDING_FROM_START;
    AVPlayer *player;
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
		//terminate
		[[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillTerminateNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
			NSDate *start = backgroundingtimer.userInfo[@"start"];
			DDLogError(@"Application will terminate after %.1f hours of running. Current battery level is %.1f%%", -start.timeIntervalSinceNow/3600, [UIDevice currentDevice].batteryLevel*100);
		}];
		
        BACKGROUNDING_FROM_START = YES;
        
        //play
        [self registerAudioSession];
        
        //session
        [self newSession];
    }
    
    return self;
}

- (void)newSession{
    PFInstallation *installation = [PFInstallation currentInstallation];
    self.session = [PFObject objectWithClassName:@"session"];
    [installation saveInBackgroundWithBlock:^(BOOL succeeded, NSError *PF_NULLABLE_S error){
        self.session[@"installation"] = installation;
        [self.session saveInBackground];
    }];
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
        DDLogInfo(@"Your device doesn't support background task. Alarm will not fire. Please change your settings.");
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
    
    [self endBackgrounding];
    
    for (UILocalNotification *note in [UIApplication sharedApplication].scheduledLocalNotifications) {
        if ([note.userInfo[kLocalNotificationTypeKey] isEqualToString:kLocalNotificationTypeReactivate]) {
            [[UIApplication sharedApplication] cancelLocalNotification:note];
        }
    }
    
    [self newSession];
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
    else {
        if (backgroundingFailNotification) {
            [app cancelLocalNotification:backgroundingFailNotification];
        }
    }
}

#pragma mark - Backgrounding

- (void)startBackgrounding{
	[self registerAudioSession];
	[self backgroundKeepAlive:nil];
    DDLogInfo(@"Start Backgrounding");
}

- (void)endBackgrounding{
    DDLogInfo(@"End Sleep");
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
    }
}


- (void)backgroundKeepAlive:(NSTimer *)timer{
	
	//start silent sound
	[self playSilentSound];
	
    UIApplication *application = [UIApplication sharedApplication];
    NSMutableDictionary *userInfo;
    float t;
    NSMutableString *newLine;
    if (timer) {
        NSInteger count;
        NSDate *start = timer.userInfo[@"start"];
		NSDate *last = timer.userInfo[@"last"];
        count = [(NSNumber *)timer.userInfo[@"count"] integerValue];
		float batt0 = [(NSNumber *)timer.userInfo[@"batt"] floatValue];
		float batt1 = [UIDevice currentDevice].batteryLevel;
		float dur = -[last timeIntervalSinceNow]/3600;
        float length = -[start timeIntervalSinceNow]/3600;
        newLine = [NSMutableString stringWithFormat:@"\n\n===>>> [%@]Backgrounding started at %@ is checking the %ld times, backgrounding length: %.1f hours. ", [NSDate date], start, (long)count, length];
        if (batt0 >= batt1) {
            //not charging
            t = batt1 / ((batt0 - batt1)/dur);
            [newLine appendFormat:@"Current battery level is %.1f %%, and estimated time left is %.1f hours", batt1*100.0f, t];
        }else{
            t = (1.0f-batt0)/((batt0 - batt1)/dur);
            [newLine appendFormat:@"Current battery level is %.1f %%, and estimated time until fully chaged is %.1f hours", batt1*100.0f, t];
        }
        DDLogInfo(newLine);
        //save
        //if (count%10 == 0) {
            DDLogInfo(@"Uploading info to Parse");
            self.session[@"length"] = @(length);
            self.session[@"count"] = @(count);
            self.session[@"battery"] = @(batt1*100);
            if(t != INFINITY) self.session[@"left"] = @(t);
            [self.session saveInBackground];
        //}
        
        count++;
        timer.userInfo[@"count"] = @(count);
		userInfo[@"batt"] = @(batt1);
		userInfo[@"last"] = [NSDate date];
        userInfo = timer.userInfo;
    }else{
        //first time
		[UIDevice currentDevice].batteryMonitoringEnabled = YES;
        userInfo = [NSMutableDictionary new];
        userInfo[@"start"] = [NSDate date];
		userInfo[@"last"] = [NSDate date];
        userInfo[@"count"] = @0;
		userInfo[@"batt"] = @([UIDevice currentDevice].batteryLevel);
    }
	
	//post notification to UI
	[[NSNotificationCenter defaultCenter] postNotificationName:@"backgrounding" object:self userInfo:userInfo];
	
    //keep old background task
	UIBackgroundTaskIdentifier tempID = backgroundTaskIdentifier;
    //begin a new background task
    backgroundTaskIdentifier = [application beginBackgroundTaskWithExpirationHandler:^{
        DDLogError(@"Backgrounding stopped after %.1f hours of running", t);
    }];
	//end old bg task
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [application endBackgroundTask:tempID];
    });
	
	//check time left
    double timeLeft = application.backgroundTimeRemaining;
    [newLine appendFormat:@"Background time left: %.1f", timeLeft>999?999:timeLeft];
    
    //schedule timer
    if ([backgroundingtimer isValid]) [backgroundingtimer invalidate];
    NSInteger randomInterval = kAlarmTimerCheckInterval + arc4random_uniform(40);
    if(randomInterval > timeLeft) randomInterval = timeLeft - 10;
    backgroundingtimer = [NSTimer scheduledTimerWithTimeInterval:randomInterval target:self selector:@selector(backgroundKeepAlive:) userInfo:userInfo repeats:NO];
    [newLine appendFormat:@"Scheduled timer %ld", (long)randomInterval];
    DDLogVerbose(newLine);
	
	//alert user when suspendid
	if (backgroundingFailNotification) {
		[[UIApplication sharedApplication] cancelLocalNotification:backgroundingFailNotification];
	}
	if (self.sleeping) {
		backgroundingFailNotification= [[UILocalNotification alloc] init];
		backgroundingFailNotification.fireDate = [[NSDate date] dateByAddingTimeInterval:200];
		backgroundingFailNotification.alertBody = @"Woke stopped running. Tap here to reactivate it.";
		backgroundingFailNotification.alertAction = @"Activate";
		backgroundingFailNotification.userInfo = @{kLocalNotificationTypeKey: kLocalNotificationTypeReactivate};
		backgroundingFailNotification.soundName = @"new.caf";
		[[UIApplication sharedApplication] scheduleLocalNotification:backgroundingFailNotification];
	}
    
    
}


//register the BACKGROUNDING audio session
- (void)registerAudioSession{
    
    //audio session
    [[AVAudioSession sharedInstance] setDelegate: self];
    NSError *error = nil;
    //set category
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback
                                                    withOptions:AVAudioSessionCategoryOptionMixWithOthers
                                                          error:&error];
    //set active bg sound
    [self playSilentSound];
}


- (void)playSilentSound{
    NSURL *path = [[NSBundle mainBundle] URLForResource:@"bg" withExtension:@"caf"];
    [self playAvplayerWithURL:path];
}

- (void)playAvplayerWithURL:(NSURL *)url{
    
    //AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
    player = [AVPlayer playerWithURL:url];
    [player setActionAtItemEnd:AVPlayerActionAtItemEndPause];
    player.volume = 1.0;
    //[avplayer addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:NULL];
    [player play];
    
    if (player.status == AVPlayerStatusFailed) {
        DDLogInfo(@"!!! AV player not ready to play.");
    }else {
        DDLogInfo(@"Play silent sound");
    }
}

#pragma mark - delegate
- (void)beginInterruption{
    if(backgroundingFailNotification)
        [[UIApplication sharedApplication] cancelLocalNotification:backgroundingFailNotification];
}

- (void)endInterruptionWithFlags:(NSUInteger)flags{
	if (flags) {
		if (AVAudioSessionInterruptionOptionShouldResume) {
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				
				[self startBackgrounding];
#ifdef DEBUG
				UILocalNotification *n = [UILocalNotification new];
				n.alertBody = @"active";
				[[UIApplication sharedApplication] scheduleLocalNotification:n];
#endif
				
			});
		}
	}
}
@end
