//
//  TestFlightLogger.m
//  TestFlightLogger
//
//  Created by Alex Billingsley on 10/28/12.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
//  documentation files (the "Software"), to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
//  to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of
//  the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
//  THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
//  CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.
//

#import "TestFlightLogger.h"
#import "TestFlight.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@implementation TestFlightLogger

+ (TestFlightLogger *)sharedInstance
{
    static TestFlightLogger *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TestFlightLogger alloc] init];
    });
    return instance;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        [TestFlight setOptions:@{ TFOptionLogToConsole: @NO }];
        [TestFlight setOptions:@{ TFOptionLogToSTDERR:  @NO }];
	}
    return self;
}

- (void)logMessage:(DDLogMessage *)logMessage
{
    NSString *logMsg = (formatter ? [formatter formatLogMessage:logMessage] : logMessage->logMsg);

    if (logMsg)
    {
        TFLog(@"%@", logMsg);
    }
}

- (NSString *)loggerName
{
	return @"cocoa.lumberjack.testflightlogger";
}

@end
