//
//  ACDFTPServer.h
//  ACDFTPManager
//
//  Created by onedotM on 16/3/14.
//  Copyright © 2016年 onedotM. All rights reserved.
//

#import <Foundation/Foundation.h>

#define FTPANONYMOUS @"anonymous"

/*enum {
 kFTPAnswerSuccess = 200,
 kFTPAnswerLoggedIn = 230,
 kFTPAnswerFileActionOkay = 250,
 kFTPAnswerNeedsPassword = 331,
 kFTPAnswerNotAvailable = 421,
 kFTPAnswerNotLoggedIn = 530
 };*/

@interface ACDFTPServer : NSObject

/**
 *  The URL of the ACDFTPServer.
 */
@property (copy) NSString *destination;

/**
 *  The password for the ACDFTPServer login.
 */
@property (copy) NSString *password;

/**
 *  The username for the ACDFTPServer login.
 */
@property (copy) NSString *username;

/**
 *  The port which is used for the connection.
 */
@property (assign) int port;

/**
 *  Returns a ACDFTPServer initialized with the given URL and credentials.
 *
 *  @param dest The URL of the FTP server.
 *  @param user The username of the account which will be used to log in.
 *  @param pass The password which will be used to log in.
 *
 *  @return a ACDFTPServer object with the given URL, username and password.
 */
+ (ACDFTPServer *)serverWithDestination:(NSString *)dest
                               username:(NSString *)user
                               password:(NSString *)pass;

/**
 *  Returns a ACDFTPServer initialized with the given URL and anonymous login.
 *
 *  @param dest The URL of the FTP server.
 *
 *  @return a ACDFTPServer object with the given URL and anonymous login.
 */
+ (ACDFTPServer *)anonymousServerWithDestination:(NSString *)dest;

@end
