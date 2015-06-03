//
//  AppDelegate.m
//  EWBackgrounding
//
//  Created by Lee on 9/26/14.
//  Copyright (c) 2014 Lee. All rights reserved.
//

#import "AppDelegate.h"
#import "EWBackgroundingManager.h"
#import <CocoaLumberjack.h>
#import "ViewController.h"
#import "CrashlyticsLogger.h"
#import "Crashlytics.h"
#import "Parse.h"
#define NSLOG	DDLogInfo


@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	[Crashlytics startWithAPIKey:@"6ec9eab6ca26fcd18d51d0322752b861c63bc348"];
    // Override point for customization after application launch.
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    
    DDTTYLogger *log = [DDTTYLogger sharedInstance];
    [DDLog addLogger:log];
    
    DDFileLogger *fileLogger = [[DDFileLogger alloc] init];
    fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
    fileLogger.logFileManager.maximumNumberOfLogFiles = 7;//keep a week's log
    [DDLog addLogger:fileLogger];
    
    //Parse
    [Parse enableLocalDatastore];
    [Parse setApplicationId:@"65qmAxDHC48Yptqj8UNnHotL4FkFajhUzfiVx3Dv"
                  clientKey:@"P6kpdTtFLkDY7YYtXmUMPVyWoplKkK9abCPgkHuk"];
    [PFAnalytics trackAppOpenedWithLaunchOptions:launchOptions];// [Optional] Track statistics around application opens.
    
    // we also enable colors in Xcode debug console
    // because this require some setup for Xcode, commented out here.
    // https://github.com/CocoaLumberjack/CocoaLumberjack/wiki/XcodeColors
    [log setColorsEnabled:YES];
    [log setForegroundColor:[UIColor orangeColor] backgroundColor:nil forFlag:DDLogFlagInfo];
    [log setForegroundColor:[UIColor redColor] backgroundColor:nil forFlag:DDLogFlagError];
    [log setForegroundColor:[UIColor darkGrayColor] backgroundColor:nil forFlag:DDLogFlagVerbose];
    [log setForegroundColor:[UIColor colorWithRed:(255/255.0) green:(58/255.0) blue:(159/255.0) alpha:1.0] backgroundColor:nil forFlag:DDLogFlagWarning];
	
    //crashlytics logger
    [DDLog addLogger:[CrashlyticsLogger sharedInstance]];
	
	//===================================
    [EWBackgroundingManager sharedInstance];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    UIViewController *vc = [[ViewController alloc] initWithNibName:nil bundle:nil];
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    [EWBackgroundingManager sharedInstance].session[@"terminating"] = @(YES);
    [[EWBackgroundingManager sharedInstance].session save];
}


@end
