//
//  FTPMSample1.m
//  FTPManager
//
//  Created by WangBo on 16/3/13.
//  Copyright © 2016年 WangBo. All rights reserved.
//

/* This is a very dirty sample.
 * Do not code like this.
 * However, this does not need anything in the header file. (Demonstration
 * purposes, etc.)
 */

#import "ACDFTPManager.h"
#import "FTPMSample1.h"

@implementation FTPMSample1

ACDFTPServer *server;
ACDFTPManager *man;
NSString *filePath;
BOOL succeeded;
NSTimer *progTimer;

- (void)uploadFinished {
    [progTimer invalidate];
    progTimer = nil;
    filePath = nil;
    server = nil;
    man = nil;

    // test whether succeeded == YES
}

- (void)changeProgress {
    if (!man) {
        return;
    }
    //    NSNumber* progress = [man.progress
    //    objectForKey:kFMProcessInfoProgress];
    //    float p = progress.floatValue; //0.0f ≤ p ≤ 1.0f

    // use p here...
    // update some ui stuff, you know
}

- (void)startUploading {
    man = [[ACDFTPManager alloc] init];

    succeeded = [man uploadFile:[NSURL URLWithString:filePath] toServer:server];

    [self performSelectorOnMainThread:@selector(uploadFinished)
                           withObject:nil
                        waitUntilDone:NO];
}

- (void)upload:(NSString *)file
        ftpUrl:(NSString *)url
        ftpUsr:(NSString *)user
       ftpPass:(NSString *)pass {
    server =
        [ACDFTPServer serverWithDestination:url username:user password:pass];
    filePath = file;
    progTimer =
        [NSTimer scheduledTimerWithTimeInterval:0.1
                                         target:self
                                       selector:@selector(changeProgress)
                                       userInfo:nil
                                        repeats:YES];
    [self performSelectorInBackground:@selector(startUploading) withObject:nil];
}

/*

 usage:

 [self upload:@"/Users/sjobs/test.png" ftpUrl:@"apple.com" ftpPass:@"1234"];

*/

@end
