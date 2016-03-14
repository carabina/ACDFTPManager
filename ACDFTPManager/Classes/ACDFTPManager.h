//
//  ACDFTPManager.m
//  ACDFTPManager
//
//  Created by WangBo on 16/3/13.
//  Copyright © 2016年 WangBo. All rights reserved.
//

#import "ACDFTPServer.h"
#import <Foundation/Foundation.h>
#import <netdb.h>
#import <netinet/in.h>
#import <sys/socket.h>
#import <sys/types.h>

enum { kSendBufferSize = 32768 };

typedef NS_ENUM(NSInteger, ACDStreamFailureReason) {
    ACDStreamFailureReasonNone,
    ACDStreamFailureReasonReadError,
    ACDStreamFailureReasonWriteError,
    ACDStreamFailureReasonGeneralError,
    ACDStreamFailureReasonAborted
};

typedef NS_ENUM(NSInteger, ACDCurrentAction) {
    ACDCurrentActionUploadFile,
    ACDCurrentActionCreateNewFolder,
    ACDCurrentActionContentsOfServer,
    ACDCurrentActionDownloadFile,
    ACDCurrentActionSOCKET,
    ACDCurrentActionNone
};

#pragma mark - ACDFTPManager Delegate
/* I do not recommend to use this delegate, because the methods will slow down
 * the process. On top of this they may have some threading issues that could
 * be pretty confusing. Use an NSTimer and [manager progress] instead. */
@protocol ACDFTPManagerDelegate <NSObject>
@optional
- (void)ftpManagerUploadProgressDidChange:(NSDictionary *)processInfo;
// Returns information about the current upload.
// See "Process Info Dictionary Constants" below for detailed info.
- (void)ftpManagerDownloadProgressDidChange:(NSDictionary *)processInfo;
// Returns information about the current download.
// See "Process Info Dictionary Constants" below for detailed info.
@end

#pragma mark - Process Info Dictionary Constants
// Process Info Dictionary Constants (for [manager progress]):
// ******************
#define kFMProcessInfoProgress @"progress" // 0.0 to 1.0
#define kFMProcessInfoFileSize @"fileSize"
#define kFMProcessInfoBytesProcessed @"bytesProcessed"
#define kFMProcessInfoFileSizeProcessed @"fileSizeProcessed"
// ----------------------(returns NSNumber values)--------------------

#pragma mark -
@interface ACDFTPManager : NSObject <NSStreamDelegate> {
    CFRunLoopRef currentRunLoop;
    ACDCurrentAction action;

    uint8_t _buffer[kSendBufferSize];
    size_t _bufferOffset;
    size_t _bufferLimit;
    unsigned long long fileSize;
    unsigned long long bytesProcessed;
    unsigned long long fileSizeProcessed;
    BOOL streamSuccess;
}

/**
 *  Input steam for reading from a local file
 */
@property (strong) NSInputStream *fileReader;

/**
 *  Output stream for writing to a local file
 */
@property (strong) NSOutputStream *fileWriter;

/**
 *  Input stream for reading from the server (remote file)
 */
@property (strong) NSInputStream *serverReadStream;

/**
 *  Output stream for writing to the server (remote file)
 */
@property (strong) NSOutputStream *serverStream;

@property (strong) NSMutableData *directoryListingData;

@property (assign) id<ACDFTPManagerDelegate> delegate;

#pragma mark - Public Methods
// *** Information
// These methods hold the current thread. You will get an answer with a success
// information.

/**
 *  Uploads a file to a server. Existing remote files of the same name will be
 * overwritten.
 *
 *  @param fileURL The local file which will be uploaded to the FTP server.
 *  @param server  The FTP server which the file will be uploaded to.
 *
 *  @return YES if the upload was successful, NO otherwise.
 */
- (BOOL)uploadFile:(NSURL *)fileURL toServer:(ACDFTPServer *)server;

/**
 *  Uploads NSData to a server. Existing remote files of the same name will be
 * overwritten.
 *
 *  @param data     The data which will be written to the FTP server.
 *  @param fileName The name with which the new file will be created on the FTP
 * server.
 *  @param server   The FTP server on which the file with the given data will be
 * created.
 *
 *  @return YES if the upload was successful, NO otherwise.
 */
- (BOOL)uploadData:(NSData *)data
      withFileName:(NSString *)fileName
          toServer:(ACDFTPServer *)server;

/**
 *  Creates a new folder on the specified FTP server.
 *
 *  @param folderName The name of the folder to create.
 *  @param server     The FTP server on which the new folder should be created.
 *
 *  @return YES if the folder creation was successful, NO otherwise.
 */
- (BOOL)createNewFolder:(NSString *)folderName atServer:(ACDFTPServer *)server;

/**
 *  Returns a list of files and folders at the specified FTP server. as an
 * NSArray containing instances of NSDictionary.
 *  The dictionaries contain objects declared in CFStream FTP Resource
 * Constants. To get the name of the entry, get the object for the
 * (id)kCFFTPResourceName key.
 *
 *  @param server The FTP server whose contents will be listed.
 *
 *  @return The NSArray containing instances of NSDictionary. An empty array if
 * the server has no contents. nil if there was an error during the process.
 */
- (NSArray *)contentsOfServer:(ACDFTPServer *)server;

/**
 *  Downloads a file from the specified FTP server. Existing local files of the
 * same name will be overwritten.
 *
 *  @param fileName     The file which will be downloaded from the specified FTP
 * server.
 *  @param directoryURL The local directory the file will be downloaded to.
 *  @param server       The server the file will be downloaded from.
 *
 *  @return YES if the download was successful, NO otherwise
 */
- (BOOL)downloadFile:(NSString *)fileName
         toDirectory:(NSURL *)directoryURL
          fromServer:(ACDFTPServer *)server;

/**
 *  Delete a file from the specified FTP server and delete directories if they
 * are empty.
 *
 *  @param fileName The file which will be deleted from the FTP server.
 *  @param server   The FTP server from which the file or directory will be
 * deleted.
 *
 *  @return YES if the file was successfully deleted from the server, NO
 * otherwise.
 */
- (BOOL)deleteFileNamed:(NSString *)fileName fromServer:(ACDFTPServer *)server;

/**
 *  Changes the mode of a file on a server. Works only on UNIX servers.
 *
 *  @param fileName The file whose permissions will be modified.
 *  @param mode     The mode which will be applied to the remote file in octal
 * notation.
 *  @param server   The server on which the mode change operation will take
 * place.
 *
 *  @return YES if the chmod command was successful, NO otherwise.
 */
- (BOOL)chmodFileNamed:(NSString *)fileName
                    to:(int)mode
              atServer:(ACDFTPServer *)server;

/**
 *  Logs into the FTP server and logs out again. This can be used to check
 * whether the credentials are correct before trying to do a file operation.
 *
 *  @param server The ACDFTPServer FTP object to log into.
 *
 *  @return YES if the login was successful, NO otherwise.
 */
- (BOOL)checkLogin:(ACDFTPServer *)server;

/**
 *  Returns information about the current process. As the FTP methods hold the
 * thread, you may want to call this method from a different thread that updates
 * the UI.
 *  See 'Process Info Dictionary Constants' above for information about the
 * contents of the dictionary.
 *
 *  @return nil if no process is currently running or information could not be
 * determined. This method only works when downloading or uploading a file.
 */
- (NSMutableDictionary *)progress;

/**
 *  Aborts the current process. As the FTP methods hold the thread, you may want
 * to call this method from a different thread.
 */
- (void)abort;

@end
