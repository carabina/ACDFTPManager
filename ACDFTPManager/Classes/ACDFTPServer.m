//
//  ACDFTPServer.m
//  ACDFTPManager
//
//  Created by WangBo on 16/3/14.
//  Copyright © 2016年 nkreipke. All rights reserved.
//

#import "ACDFTPServer.h"

@implementation ACDFTPServer

@synthesize password, username, destination, port;

#pragma mark - Life Cycle
- (id)init {
    self = [super init];
    if (self) {
        self.port = 21;
    }
    return self;
}

+ (ACDFTPServer *)serverWithDestination:(NSString *)dest
                               username:(NSString *)user
                               password:(NSString *)pass {
    ACDFTPServer *server = [[ACDFTPServer alloc] init];
    server.destination = dest;
    server.username = user;
    server.password = pass;
    return server;
}

+ (ACDFTPServer *)anonymousServerWithDestination:(NSString *)dest {
    ACDFTPServer *server = [[ACDFTPServer alloc] init];
    server.destination = dest;
    server.username = FTPANONYMOUS;
    server.password = @"";
    return server;
}
@end
