//
//  ACDFTPManagerThread.h
//  ACDFTPManager
//
//  Created by onedotM on 16/3/14.
//  Copyright © 2016年 onedotM. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ACDFTPManagerThread : NSObject {
    NSCondition *waitCondition;
}

@property (copy) void (^block)(void);

+ (void)runInSeparateThread:(void (^)(void))block;

@end
