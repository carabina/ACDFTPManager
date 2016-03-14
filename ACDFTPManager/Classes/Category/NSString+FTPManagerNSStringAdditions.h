//
//  NSString+FTPManagerNSStringAdditions.h
//  ACDFTPManager
//
//  Created by WangBo on 16/3/14.
//  Copyright © 2016年 WangBo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (FTPManagerNSStringAdditions)

/**
 *  returns the url without the protocol
 *
 *  @return ftp://test.com/test/test -> test.com/test/test
 */
- (NSString *)stringWithoutProtocol;

/**
 *  returns the complete url including the directory
 *
 *  @param port
 *
 *  @return ftp://test.com/test/test
 */
- (NSURL *)ftpURLForPort:(int)port;

/**
 *  returns the host
 *
 *  @return ftp://test.com/test/test -> test.com
 */
- (NSString *)fmhost;

/**
 *  returns the working directory
 *
 *  @return ftp://test.com/test/test -> test/test
 */
- (NSString *)fmdir;

@end
