//
//  ViewController.m
//  EWBackgrounding
//
//  Created by Lee on 9/26/14.
//  Copyright (c) 2014 Lee. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [[NSNotificationCenter defaultCenter] addObserverForName:@"backgrounding" object:nil queue:nil usingBlock:^(NSNotification *note) {
		DDLogDebug(@"UI received backgrounding notice");
        NSDate *start = note.userInfo[@"start"];
		NSDate *last = note.userInfo[@"last"];
        NSNumber *count = (NSNumber *)note.userInfo[@"count"];
		float batt0 = [(NSNumber *)note.userInfo[@"batt"] floatValue];
		float batt1 = [UIDevice currentDevice].batteryLevel;
		float dur = -[last timeIntervalSinceNow]/3600;
		float t = batt1 / ((batt0 - batt1)/dur);
        NSString *newLine = [NSString stringWithFormat:@"\n\n===>>> [%@]Backgrounding started at %@ is checking the %@ times, backgrounding length: %.1f hours. Current battery level is %.1f %%, and estimated time left is %.1f hours", [NSDate date], start, count, -[start timeIntervalSinceNow]/3600, batt1*100.0f, t];
		self.textView.text = [self.textView.text stringByAppendingString:newLine];
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
	DDLogError(@"Received memory warning");
}

@end
