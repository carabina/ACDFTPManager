//
//  NSString+FTPManagerNSStringAdditions.m
//  ACDFTPManager
//
//  Created by WangBo on 16/3/14.
//  Copyright © 2016年 nkreipke. All rights reserved.
//

#import "NSString+FTPManagerNSStringAdditions.h"

@implementation NSString (FTPManagerNSStringAdditions)
- (NSString *)stringWithoutProtocol {
    NSString *urlString = [NSString stringWithString:self];
    NSRange range = [urlString rangeOfString:@"://"];
    if (range.location != NSNotFound) {
        urlString = [urlString substringFromIndex:range.location + 3];
    }
    // test whether a port is included (which would not work)
    NSRange rangeP = [urlString rangeOfString:@":"];
    if (rangeP.location != NSNotFound) {
        const char *ptr = [urlString cStringUsingEncoding:NSUTF8StringEncoding];
        while (*ptr != '/' && *ptr != '\0') {
            if (*(ptr++) == ':') {
                NSLog(@"FTPManager warning: there is possibly a port included "
                      @"in your destination url. Define the port in "
                      @"FMServer.port instead.");
                break;
            }
        }
    }
    return urlString;
}

- (NSURL *)ftpURLForPort:(int)port {
    // returns the complete url including the directory
    // -> ftp://test.com/test/test
    NSString *host =
        port == 21 ? self.fmhost
                   : [NSString stringWithFormat:@"%@:%i", self.fmhost, port];
    NSString *hostWithProtocol = [NSString stringWithFormat:@"ftp://%@", host];

    NSString *url = hostWithProtocol;
    NSString *fmdir = self.fmdir;
    if (fmdir && fmdir.length > 0)
        url = [NSString
            stringWithFormat:@"%@/%@", hostWithProtocol,
                             [fmdir stringByAddingPercentEscapesUsingEncoding:
                                        NSUTF8StringEncoding]];

    return [NSURL URLWithString:url];
}

- (NSString *)fmhost {
    // returns the host
    // ftp://test.com/test/test -> test.com
    NSString *u = [self stringWithoutProtocol];
    NSRange fs = [u rangeOfString:@"/"];
    if (fs.location != NSNotFound) {
        return [u substringToIndex:fs.location];
    } else {
        return u;
    }
}

- (NSString *)fmdir {
    // returns the working directory
    // ftp://test.com/test/test -> test/test
    NSString *u = [self stringWithoutProtocol];
    NSRange fs = [u rangeOfString:@"/"];
    if (fs.location == NSNotFound) {
        return nil;
    } else {
        return [u substringFromIndex:fs.location + 1];
    }
}
@end
