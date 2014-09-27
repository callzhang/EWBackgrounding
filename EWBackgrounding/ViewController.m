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
        NSDate *start = note.userInfo[@"start_date"];
        NSNumber *count = (NSNumber *)note.userInfo[@"count"];
        self.textView.text = [NSString stringWithFormat:@"Backgrounding started at %@ is checking the %@ times, backgrounding length: %.1f hours, last checked: %@", start, count, -[start timeIntervalSinceReferenceDate], [NSDate date]];
        
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
