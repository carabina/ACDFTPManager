//
//  ACDFTPManagerThread.m
//  ACDFTPManager
//
//  Created by WangBo on 16/3/14.
//  Copyright © 2016年 nkreipke. All rights reserved.
//

#import "ACDFTPManagerThread.h"

@implementation ACDFTPManagerThread

+ (void)runInSeparateThread:(void (^)(void))block {
    ACDFTPManagerThread *thread = [[ACDFTPManagerThread alloc] init];
    thread.block = block;
    thread->waitCondition = [[NSCondition alloc] init];
    [thread->waitCondition lock];
    NSThread *t = [[NSThread alloc] initWithTarget:thread
                                          selector:@selector(threadMain)
                                            object:nil];
    [t start];
    [thread->waitCondition wait];
    [thread->waitCondition unlock];
}

- (void)threadMain {
    @autoreleasepool {
        self.block();
        [waitCondition broadcast];
    }
}

@end
