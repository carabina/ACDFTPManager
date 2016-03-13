//
//  ACDFTPServer.h
//  ACDFTPManager
//
//  Created by WangBo on 16/3/14.
//  Copyright © 2016年 nkreipke. All rights reserved.
//

#import <Foundation/Foundation.h>

// these are used internally:
#define FTPANONYMOUS @"anonymous"

/*enum {
 kFTPAnswerSuccess = 200,
 kFTPAnswerLoggedIn = 230,
 kFTPAnswerFileActionOkay = 250,
 kFTPAnswerNeedsPassword = 331,
 kFTPAnswerNotAvailable = 421,
 kFTPAnswerNotLoggedIn = 530
 };*/

@interface ACDFTPServer : NSObject {
  @private
    NSString *destination;
    NSString *password;
    NSString *username;
    int port;
}

/**
 *  The URL of the FMServer.
 */
@property (strong) NSString *destination;

/**
 *  The password for the FMServer login.
 */
@property (strong) NSString *password;

/**
 *  The username for the FMServer login.
 */
@property (strong) NSString *username;

/**
 *  The port which is used for the connection.
 */
@property (unsafe_unretained) int port;

/**
 *  Returns a FMServer initialized with the given URL and credentials.
 *
 *  @param dest The URL of the FTP server.
 *  @param user The username of the account which will be used to log in.
 *  @param pass The password which will be used to log in.
 *
 *  @return A FMServer object with the given URL, username and password.
 */
+ (ACDFTPServer *)serverWithDestination:(NSString *)dest
                               username:(NSString *)user
                               password:(NSString *)pass;

/**
 *  Returns a FMServer initialized with the given URL and anonymous login.
 *
 *  @param dest The URL of the FTP server.
 *
 *  @return A FMServer object with the given URL and anonymous login.
 */
+ (ACDFTPServer *)anonymousServerWithDestination:(NSString *)dest;

@end
