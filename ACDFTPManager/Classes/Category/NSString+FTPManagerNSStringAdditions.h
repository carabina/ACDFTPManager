//
//  NSString+FTPManagerNSStringAdditions.h
//  ACDFTPManager
//
//  Created by WangBo on 16/3/14.
//  Copyright © 2016年 nkreipke. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (FTPManagerNSStringAdditions)
- (NSString *)stringWithoutProtocol;
- (NSURL *)ftpURLForPort:(int)port;
- (NSString *)fmhost;
- (NSString *)fmdir;
@end
