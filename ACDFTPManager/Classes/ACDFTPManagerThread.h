//
//  ACDFTPManagerThread.h
//  ACDFTPManager
//
//  Created by WangBo on 16/3/14.
//  Copyright © 2016年 WangBo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ACDFTPManagerThread : NSObject {
    NSCondition *waitCondition;
}

@property (copy) void (^block)(void);

+ (void)runInSeparateThread:(void (^)(void))block;

@end
