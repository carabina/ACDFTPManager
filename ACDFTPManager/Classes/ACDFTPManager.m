//
//  ACDFTPManager.m
//  ACDFTPManager
//
//  Created by WangBo on 16/3/13.
//  Copyright © 2016年 WangBo. All rights reserved.
//

#import "ACDFTPManager.h"
#import "ACDFTPManagerThread.h"
#import "NSString+FTPManagerNSStringAdditions.h"

#define And(val1, val2)                                                        \
    { val1 = val1 && val2; }

#define AndV(val1, val2, message)                                              \
    {                                                                          \
        And(val1, val2);                                                       \
        if (!val2) NSLog(message);                                             \
    }

#define Check(val1)                                                            \
    {                                                                          \
        if (val1 == NO) return NO;                                             \
    }

#define RunInSeparateThread(...)                                               \
    ({                                                                         \
        __block __typeof__(__VA_ARGS__) result;                                \
        [ACDFTPManagerThread runInSeparateThread:^{                            \
            result = (__VA_ARGS__);                                            \
        }];                                                                    \
        result;                                                                \
    })

#pragma mark -

@interface ACDFTPManager ()

@property (nonatomic, readonly) uint8_t *buffer;
@property (nonatomic, assign) size_t bufferOffset;
@property (nonatomic, assign) size_t bufferLimit;

- (void)_streamDidEndWithSuccess:(BOOL)success
                   failureReason:(ACDStreamFailureReason)failureReason;
- (BOOL)_ftpActionForServer:(ACDFTPServer *)server
                    command:(NSString *)fullCommand;
@end

#pragma mark -

@implementation ACDFTPManager

@synthesize bufferOffset = _bufferOffset;
@synthesize bufferLimit = _bufferLimit;
@synthesize delegate = _delegate;

#pragma mark - Life Cycle

- (id)init {
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    return self;
}

#pragma mark - Private Methods

- (unsigned long long)fileSizeOf:(NSURL *)file {
    NSDictionary *attrib =
        [[NSFileManager defaultManager] attributesOfItemAtPath:file.path
                                                         error:nil];
    if (!attrib) {
        return 0;
    }
    return [attrib fileSize];
}

- (BOOL)_uploadData:(NSData *)data
       withFileName:(NSString *)fileName
           toServer:(ACDFTPServer *)server {
    BOOL success = YES;
    action = ACDCurrentActionUploadFile;
    fileSize = data.length;
    fileSizeProcessed = 0;

    NSURL *finalURL = [[server.destination ftpURLForPort:server.port]
        URLByAppendingPathComponent:fileName];
    And(success, (finalURL != nil));
    Check(success);

    self.fileReader = [[NSInputStream alloc] initWithData:data];
    And(success, (self.fileReader != nil));
    Check(success);
    [self.fileReader open];

    CFWriteStreamRef writeStream =
        CFWriteStreamCreateWithFTPURL(NULL, (__bridge CFURLRef) finalURL);
    And(success, (writeStream != NULL));
    Check(success);
    self.serverStream = (__bridge_transfer NSOutputStream *) writeStream;
    And(success,
        [self.serverStream setProperty:server.username
                                forKey:(id) kCFStreamPropertyFTPUserName]);
    And(success,
        [self.serverStream setProperty:server.password
                                forKey:(id) kCFStreamPropertyFTPPassword]);
    Check(success);

    self.bufferOffset = 0;
    self.bufferLimit = 0;
    currentRunLoop = CFRunLoopGetCurrent();
    self.serverStream.delegate = self;
    [self.serverStream open];
    [self.serverStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                 forMode:NSDefaultRunLoopMode];

    CFRunLoopRun();
    And(success, streamSuccess);
    return success;
}

- (BOOL)_uploadFile:(NSURL *)fileURL toServer:(ACDFTPServer *)server {
    BOOL success = YES;
    action = ACDCurrentActionUploadFile;
    fileSize = [self fileSizeOf:fileURL];
    fileSizeProcessed = 0;

    NSURL *finalURL = [[server.destination ftpURLForPort:server.port]
        URLByAppendingPathComponent:[fileURL lastPathComponent]];
    And(success, (finalURL != nil));
    Check(success);

    self.fileReader = [[NSInputStream alloc] initWithFileAtPath:fileURL.path];
    And(success, (self.fileReader != nil));
    Check(success);
    [self.fileReader open];

    CFWriteStreamRef writeStream =
        CFWriteStreamCreateWithFTPURL(NULL, (__bridge CFURLRef) finalURL);
    And(success, (writeStream != NULL));
    Check(success);
    self.serverStream = (__bridge_transfer NSOutputStream *) writeStream;
    And(success,
        [self.serverStream setProperty:server.username
                                forKey:(id) kCFStreamPropertyFTPUserName]);
    And(success,
        [self.serverStream setProperty:server.password
                                forKey:(id) kCFStreamPropertyFTPPassword]);
    Check(success);

    self.bufferOffset = 0;
    self.bufferLimit = 0;
    currentRunLoop = CFRunLoopGetCurrent();
    self.serverStream.delegate = self;
    [self.serverStream open];
    [self.serverStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                 forMode:NSDefaultRunLoopMode];

    CFRunLoopRun();
    And(success, streamSuccess);
    return success;
}

- (BOOL)_createNewFolder:(NSString *)folderName
                atServer:(ACDFTPServer *)server {
    BOOL success = YES;
    action = ACDCurrentActionCreateNewFolder;
    fileSize = 0;

    NSURL *finalURL = [[server.destination ftpURLForPort:server.port]
        URLByAppendingPathComponent:folderName
                        isDirectory:YES];
    And(success, (finalURL != nil));
    Check(success);

    CFWriteStreamRef writeStream =
        CFWriteStreamCreateWithFTPURL(NULL, (__bridge CFURLRef) finalURL);
    And(success, (writeStream != NULL));
    Check(success);
    self.serverStream = (__bridge_transfer NSOutputStream *) writeStream;
    And(success,
        [self.serverStream setProperty:server.username
                                forKey:(id) kCFStreamPropertyFTPUserName]);
    And(success,
        [self.serverStream setProperty:server.password
                                forKey:(id) kCFStreamPropertyFTPPassword]);
    Check(success);

    self.bufferOffset = 0;
    self.bufferLimit = 0;

    currentRunLoop = CFRunLoopGetCurrent();
    self.serverStream.delegate = self;
    [self.serverStream open];
    [self.serverStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                 forMode:NSDefaultRunLoopMode];

    CFRunLoopRun();
    And(success, streamSuccess);
    return success;
}

- (NSArray *)_contentsOfServer:(ACDFTPServer *)server {
    BOOL success = YES;
    action = ACDCurrentActionContentsOfServer;
    fileSize = 0;
    self.directoryListingData = [[NSMutableData alloc] init];

    NSURL *dest = [server.destination ftpURLForPort:server.port];
    And(success, (dest != nil));
    Check(success);

    if (![dest.absoluteString hasSuffix:@"/"]) {
        // if the url does not end with an '/' the method fails.
        // no problem, we can fix this.
        dest = [NSURL
            URLWithString:[NSString
                              stringWithFormat:@"%@/", dest.absoluteString]];
    }

    CFReadStreamRef readStream =
        CFReadStreamCreateWithFTPURL(NULL, (__bridge CFURLRef) dest);
    And(success, (readStream != NULL));
    if (!success) return nil;
    self.serverReadStream = (__bridge_transfer NSInputStream *) readStream;
    And(success,
        [self.serverReadStream setProperty:server.username
                                    forKey:(id) kCFStreamPropertyFTPUserName]);
    And(success,
        [self.serverReadStream setProperty:server.password
                                    forKey:(id) kCFStreamPropertyFTPPassword]);
    if (!success) return nil;
    self.bufferOffset = 0;
    self.bufferLimit = 0;
    currentRunLoop = CFRunLoopGetCurrent();
    self.serverReadStream.delegate = self;
    [self.serverReadStream open];
    [self.serverReadStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                     forMode:NSDefaultRunLoopMode];
    CFRunLoopRun();
    And(success, streamSuccess);
    if (!success) return nil;
    NSArray *directoryContents = [self
        _createListingArrayFromDirectoryListingData:self.directoryListingData];
    self.directoryListingData = nil;
    return directoryContents;
}

- (BOOL)_downloadFile:(NSString *)fileName
          toDirectory:(NSURL *)directoryURL
           fromServer:(ACDFTPServer *)server {
    BOOL success = YES;
    action = ACDCurrentActionDownloadFile;
    fileSize = 0;
    fileSizeProcessed = 0;

    NSString *filePath =
        [directoryURL URLByAppendingPathComponent:fileName].path;

    self.fileWriter =
        [[NSOutputStream alloc] initToFileAtPath:filePath append:NO];
    And(success, (self.fileWriter != nil));
    Check(success);
    [self.fileWriter open];

    CFReadStreamRef readStream = CFReadStreamCreateWithFTPURL(
        NULL,
        (__bridge CFURLRef) [[server.destination ftpURLForPort:server.port]
            URLByAppendingPathComponent:fileName]);
    And(success, (readStream != NULL));
    Check(success);
    self.serverReadStream = (__bridge_transfer NSInputStream *) readStream;

    And(success,
        [self.serverReadStream setProperty:server.username
                                    forKey:(id) kCFStreamPropertyFTPUserName]);
    And(success,
        [self.serverReadStream setProperty:server.password
                                    forKey:(id) kCFStreamPropertyFTPPassword]);
    And(success, [self.serverReadStream
                     setProperty:[NSNumber numberWithBool:YES]
                          forKey:(id) kCFStreamPropertyFTPFetchResourceInfo]);
    Check(success);

    self.bufferOffset = 0;
    self.bufferLimit = 0;
    currentRunLoop = CFRunLoopGetCurrent();
    self.serverReadStream.delegate = self;
    [self.serverReadStream open];
    [self.serverReadStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                     forMode:NSDefaultRunLoopMode];
    CFRunLoopRun();
    And(success, streamSuccess);
    if (!success &&
        [[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        // if the download fails, we try to delete the empty file created by the
        // stream.
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    }
    return success;
}

- (BOOL)_checkACDFTPServer:(ACDFTPServer *)server {
    BOOL success = YES;
    AndV(success, (server != nil),
         @"ACDFTPServer check failed: server cannot be nil");
    Check(success);
    AndV(success, (server.destination != nil),
         @"ACDFTPServer check failed: destination cannot be nil");
    AndV(success, (server.username != nil),
         @"ACDFTPServer check failed: username cannot be nil");
    AndV(success, (server.password != nil),
         @"ACDFTPServer check failed: password cannot be nil");
    AndV(success, (server.port > 0),
         @"ACDFTPServer check failed: port cannot be negative");
    return success;
}

- (NSArray *)_createListingArrayFromDirectoryListingData:(NSMutableData *)data {
    NSMutableArray *listingArray = [NSMutableArray array];
    NSUInteger offset = 0;
    do {
        CFIndex bytesConsumed;
        CFDictionaryRef thisEntry = NULL;
        bytesConsumed = CFFTPCreateParsedResourceListing(
            NULL, &((const uint8_t *) self.directoryListingData.bytes)[offset],
            self.directoryListingData.length - offset, &thisEntry);
        if (bytesConsumed > 0) {
            if (thisEntry != NULL) {
                NSMutableDictionary *entry = [NSMutableDictionary
                    dictionaryWithDictionary:(__bridge NSDictionary *)
                                                 thisEntry];
                // Converting kCFFTPResourceName entry to UTF8 to fix errors
                // with Non-ASCII chars
                NSString *nameEntry;
                if ((nameEntry = entry[(id) kCFFTPResourceName])) {
                    entry[(id) kCFFTPResourceName] = [[NSString alloc]
                        initWithData:[nameEntry dataUsingEncoding:
                                                    NSMacOSRomanStringEncoding
                                             allowLossyConversion:YES]
                            encoding:NSUTF8StringEncoding];
                }
                [listingArray addObject:entry];
            }
            offset += bytesConsumed;
        }
        if (thisEntry != NULL) {
            CFRelease(thisEntry);
        }
        if (bytesConsumed == 0) {
            break;
        } else if (bytesConsumed < 0) {
            return nil;
        }
    } while (YES);
    return listingArray;
}

- (void)_streamDidEndWithSuccess:(BOOL)success
                   failureReason:(ACDStreamFailureReason)failureReason {
    if (!currentRunLoop) return;
    CFRunLoopRef runloop = currentRunLoop;
    currentRunLoop = NULL;
    action = ACDCurrentActionNone;
    streamSuccess = success;
    if (!streamSuccess) {
        switch (failureReason) {
            case ACDStreamFailureReasonReadError:
                NSLog(@"ftp stream failed: error while reading data");
                break;
            case ACDStreamFailureReasonWriteError:
                NSLog(@"ftp stream failed: error while writing data");
                break;
            case ACDStreamFailureReasonGeneralError:
                NSLog(@"ftp stream failed: general stream error (check "
                      @"credentials?)");
                break;
            default:
                break;
        }
    }
    if (self.serverStream) {
        [self.serverStream removeFromRunLoop:[NSRunLoop currentRunLoop]
                                     forMode:NSDefaultRunLoopMode];
        self.serverStream.delegate = nil;
        [self.serverStream close];
        self.serverStream = nil;
    }
    if (self.serverReadStream) {
        [self.serverReadStream removeFromRunLoop:[NSRunLoop currentRunLoop]
                                         forMode:NSDefaultRunLoopMode];
        self.serverReadStream.delegate = nil;
        [self.serverReadStream close];
        self.serverReadStream = nil;
    }
    if (self.fileReader) {
        [self.fileReader close];
        self.fileReader = nil;
    }
    if (self.fileWriter) {
        [self.fileWriter close];
        self.fileWriter = nil;
    }
    CFRunLoopStop(runloop);
}

#pragma mark - Public Methods
- (BOOL)uploadData:(NSData *)data
      withFileName:(NSString *)fileName
          toServer:(ACDFTPServer *)server {
    if (![self _checkACDFTPServer:server]) {
        return NO;
    }
    if (!data) {
        return NO;
    }
    return RunInSeparateThread(
        [self _uploadData:data withFileName:fileName toServer:server]);
}

- (BOOL)uploadFile:(NSURL *)fileURL toServer:(ACDFTPServer *)server {
    if (![self _checkACDFTPServer:server]) {
        return NO;
    }
    if (!fileURL) {
        return NO;
    }
    BOOL isDir;
    if (![[NSFileManager defaultManager] fileExistsAtPath:fileURL.path
                                              isDirectory:&isDir] ||
        isDir) {
        return NO;
    }
    return RunInSeparateThread([self _uploadFile:fileURL toServer:server]);
}

- (BOOL)createNewFolder:(NSString *)folderName atServer:(ACDFTPServer *)server {
    if (![self _checkACDFTPServer:server]) {
        return NO;
    }
    if (!folderName) {
        return NO;
    }
    if ([folderName isEqualToString:@""]) {
        return NO;
    }
    return RunInSeparateThread(
        [self _createNewFolder:folderName atServer:server]);
}

- (BOOL)deleteFileNamed:(NSString *)fileName fromServer:(ACDFTPServer *)server {
    if (![self _checkACDFTPServer:server]) {
        return NO;
    }
    if (!fileName) {
        return NO;
    }
    NSString *cmd;
    if ([fileName rangeOfString:@"."].location != NSNotFound) {
        // probably a file
        cmd = @"DELE";
    } else {
        // probably a directory (this will only succeed if the dir is empty)
        cmd = @"RMD";
    }
    return RunInSeparateThread([self
        _ftpActionForServer:server
                    command:[NSString
                                stringWithFormat:@"%@ %@", cmd, fileName]]);
}

- (BOOL)chmodFileNamed:(NSString *)fileName
                    to:(int)mode
              atServer:(ACDFTPServer *)server {
    if (![self _checkACDFTPServer:server]) {
        return NO;
    }
    if (!fileName) {
        return NO;
    }
    if (mode < 0 || mode > 777) {
        return NO;
    }
    return RunInSeparateThread([self
        _ftpActionForServer:server
                    command:[NSString stringWithFormat:@"SITE CHMOD %i %@",
                                                       mode, fileName]]);
}

- (NSArray *)contentsOfServer:(ACDFTPServer *)server {
    if (![self _checkACDFTPServer:server]) {
        return nil;
    }
    return RunInSeparateThread([self _contentsOfServer:server]);
}

- (BOOL)downloadFile:(NSString *)fileName
         toDirectory:(NSURL *)directoryURL
          fromServer:(ACDFTPServer *)server {
    if (![self _checkACDFTPServer:server]) {
        return NO;
    }
    if (!fileName) {
        return NO;
    }
    if ([fileName isEqualToString:@""]) {
        return NO;
    }
    if (!directoryURL) {
        return NO;
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:directoryURL.path]) {
        return NO;
    }
    return RunInSeparateThread([self _downloadFile:fileName
                                       toDirectory:directoryURL
                                        fromServer:server]);
}

- (BOOL)checkLogin:(ACDFTPServer *)server {
    if (![self _checkACDFTPServer:server]) {
        return NO;
    }
    return RunInSeparateThread([self _ftpActionForServer:server command:nil]);
}

- (NSMutableDictionary *)progress {
    // this does only work with uploadFile and downloadFile.
    NSStream *currentStream;
    switch (action) {
        case ACDCurrentActionUploadFile:
            currentStream = self.serverStream;
            break;
        case ACDCurrentActionDownloadFile:
            currentStream = self.serverReadStream;
            break;
        default:
            break;
    }

    if (!currentStream || fileSize == 0) {
        return nil;
    }

    NSMutableDictionary *returnValues = [[NSMutableDictionary alloc] init];

    [returnValues setValue:[NSNumber numberWithUnsignedLongLong:fileSize]
                    forKey:kFMProcessInfoFileSize];
    [returnValues setValue:[NSNumber numberWithUnsignedLongLong:bytesProcessed]
                    forKey:kFMProcessInfoBytesProcessed];
    [returnValues
        setValue:[NSNumber numberWithUnsignedLongLong:fileSizeProcessed]
          forKey:kFMProcessInfoFileSizeProcessed];
    [returnValues setValue:[NSNumber numberWithFloat:(float) fileSizeProcessed /
                                                     (float) fileSize]
                    forKey:kFMProcessInfoProgress];
    return returnValues;
}

- (void)abort {
    NSStream *currentStream;
    switch (action) {
        case ACDCurrentActionUploadFile:
            currentStream = self.serverStream;
            break;
        case ACDCurrentActionDownloadFile:
            currentStream = self.serverReadStream;
            break;
        case ACDCurrentActionCreateNewFolder:
            currentStream = self.serverStream;
            break;
        case ACDCurrentActionContentsOfServer:
            currentStream = self.serverReadStream;
            break;
        default:
            break;
    }
    if (!currentStream) {
        return;
    }
    [self _streamDidEndWithSuccess:YES
                     failureReason:ACDStreamFailureReasonAborted];
    [currentStream close];
}

#pragma mark - NSStream Delegate

- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
    switch (streamEvent) {
        case NSStreamEventOpenCompleted:
            if (action == ACDCurrentActionDownloadFile) {
                fileSize = [[theStream
                    propertyForKey:(id) kCFStreamPropertyFTPResourceSize]
                    longLongValue];
                if (self.delegate &&
                    [self.delegate
                        respondsToSelector:
                            @selector(ftpManagerDownloadProgressDidChange:)]) {
                    [self.delegate
                        ftpManagerDownloadProgressDidChange:[self progress]];
                }
            }
            break;
        case NSStreamEventHasBytesAvailable:
            if (action == ACDCurrentActionContentsOfServer) {
                NSInteger bytesRead;
                bytesRead = [self.serverReadStream read:self.buffer
                                              maxLength:kSendBufferSize];
                if (bytesRead == -1) {
                    [self _streamDidEndWithSuccess:NO
                                     failureReason:
                                         ACDStreamFailureReasonReadError];
                } else if (bytesRead == 0) {
                    [self _streamDidEndWithSuccess:YES
                                     failureReason:ACDStreamFailureReasonNone];
                } else {
                    [self.directoryListingData appendBytes:self.buffer
                                                    length:bytesRead];
                }
            } else if (action == ACDCurrentActionDownloadFile) {
                if (self.bufferOffset == self.bufferLimit) {
                    // fill buffer with data from server
                    NSInteger bytesRead;
                    bytesRead = [self.serverReadStream read:self.buffer
                                                  maxLength:kSendBufferSize];
                    if (bytesRead == -1) {
                        [self _streamDidEndWithSuccess:NO
                                         failureReason:
                                             ACDStreamFailureReasonReadError];
                    } else if (bytesRead == 0) {
                        [self _streamDidEndWithSuccess:YES
                                         failureReason:
                                             ACDStreamFailureReasonNone];
                    } else {
                        self.bufferOffset = 0;
                        self.bufferLimit = bytesRead;
                        fileSizeProcessed += bytesRead;
                        bytesProcessed = bytesRead;
                        if (self.delegate &&
                            [self.delegate
                                respondsToSelector:
                                    @selector(
                                        ftpManagerDownloadProgressDidChange:
                                            )]) {
                            [self.delegate ftpManagerDownloadProgressDidChange:
                                               [self progress]];
                        }
                    }
                }
                if (self.bufferOffset != self.bufferLimit) {
                    // fill file with buffer
                    NSInteger bytesWritten;
                    bytesWritten = [self.fileWriter
                            write:&self.buffer[self.bufferOffset]
                        maxLength:self.bufferLimit - self.bufferOffset];
                    if (bytesWritten == -1 || bytesWritten == 0) {
                        [self _streamDidEndWithSuccess:NO
                                         failureReason:
                                             ACDStreamFailureReasonWriteError];
                    } else {
                        self.bufferOffset += bytesWritten;
                    }
                }
            } else {
                // something went wrong here...
                [self _streamDidEndWithSuccess:NO
                                 failureReason:
                                     ACDStreamFailureReasonGeneralError];
            }
            break;
        case NSStreamEventHasSpaceAvailable:
            if (action == ACDCurrentActionUploadFile) {
                if (self.bufferOffset == self.bufferLimit) {
                    // read process
                    // fill buffer with data
                    NSInteger bytesRead;
                    bytesRead = [self.fileReader read:self.buffer
                                            maxLength:kSendBufferSize];
                    if (bytesRead == -1) {
                        [self _streamDidEndWithSuccess:NO
                                         failureReason:
                                             ACDStreamFailureReasonReadError];
                    } else if (bytesRead == 0) {
                        [self _streamDidEndWithSuccess:YES
                                         failureReason:
                                             ACDStreamFailureReasonNone];
                    } else {
                        self.bufferOffset = 0;
                        self.bufferLimit = bytesRead;
                    }
                }
                if (self.bufferOffset != self.bufferLimit) {
                    // write process
                    // write data out of buffer to server
                    NSInteger bytesWritten;
                    bytesWritten = [self.serverStream
                            write:&self.buffer[self.bufferOffset]
                        maxLength:self.bufferLimit - self.bufferOffset];
                    if (bytesWritten == -1 || bytesWritten == 0) {
                        [self _streamDidEndWithSuccess:NO
                                         failureReason:
                                             ACDStreamFailureReasonWriteError];
                    } else {
                        self.bufferOffset += bytesWritten;
                        fileSizeProcessed += bytesWritten;
                        bytesProcessed = bytesWritten;
                        if (self.delegate &&
                            [self.delegate
                                respondsToSelector:
                                    @selector(
                                        ftpManagerUploadProgressDidChange:)]) {
                            [self.delegate ftpManagerUploadProgressDidChange:
                                               [self progress]];
                        }
                    }
                }
            } else {
                // something went wrong here...
                [self _streamDidEndWithSuccess:NO
                                 failureReason:
                                     ACDStreamFailureReasonGeneralError];
            }
            break;
        case NSStreamEventErrorOccurred:
            [self _streamDidEndWithSuccess:NO
                             failureReason:ACDStreamFailureReasonGeneralError];
            break;
        case NSStreamEventEndEncountered:
            if (action == ACDCurrentActionCreateNewFolder) {
                [self _streamDidEndWithSuccess:YES
                                 failureReason:ACDStreamFailureReasonNone];
            }
            break;
        default:
            break;
    }
}

#pragma mark - Sockets
// These are some functions written in C. They use sockets to communicate with a
// FTP server.
// We use this for deletion and chmod.
- (NSString *)_listenLoopForSocket:(int)sockfd {
    NSString *answer = @"";
    char buffer[256];
    ssize_t n = 1;
    while (n > 0) {
        bzero(buffer, 256);
        n = read(sockfd, buffer, 255);
        if (n < 0) {
            NSLog(@"Error reading from socket!");
        } else {
            NSString *b = [NSString stringWithCString:buffer
                                             encoding:NSUTF8StringEncoding];
            answer = [NSString stringWithFormat:@"%@\n%@", answer, b];
#ifdef FMSOCKET_VERBOSE
            NSLog(@"%s", buffer);
#endif
        }
    }
    return answer;
}

- (BOOL)_checkAnswers:(NSString *)a {
    NSArray *answers = [a componentsSeparatedByString:@"\n"];
    // we are interested in the first character of the answer.
    // if this is a 4 or 5, the corresponding command failed.
    for (NSString *answer in answers) {
        const char *canswer =
            [answer cStringUsingEncoding:NSUTF8StringEncoding];
        char first = *canswer;
        if (first == '4' || first == '5') {
            return NO;
        }
    }
    return YES;
}

- (BOOL)_ftpActionForServer:(ACDFTPServer *)server
                    command:(NSString *)fullCommand {
    // At first, we send all the commands, then we fetch the answers
    // to find out whether we were successful.
    action = ACDCurrentActionSOCKET;
    const char *host =
        [[server.destination fmhost] cStringUsingEncoding:NSUTF8StringEncoding];
    const char *user =
        [server.username cStringUsingEncoding:NSUTF8StringEncoding];
    const char *pass =
        [server.password cStringUsingEncoding:NSUTF8StringEncoding];
    NSString *wdirs = [server.destination fmdir];
    const char *wdir;
    BOOL chdir = NO;
    if (wdirs && wdirs.length > 0) {
        wdir = [wdirs cStringUsingEncoding:NSUTF8StringEncoding];
        chdir = YES;
    }
    char cmd[256];
    ssize_t n;
    struct sockaddr_in serv_addr;
    struct hostent *srv;
    int sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) {
        NSLog(@"could not open socket!");
        return NO;
    }
    srv = gethostbyname(host);
    if (srv == NULL) {
        NSLog(@"host error!");
        return NO;
    }
    bzero((char *) &serv_addr, sizeof(serv_addr));
    serv_addr.sin_family = AF_INET;
    bcopy((char *) srv->h_addr, (char *) &serv_addr.sin_addr.s_addr,
          srv->h_length);
    serv_addr.sin_port = htons(server.port);
    if (connect(sockfd, (struct sockaddr *) &serv_addr, sizeof(serv_addr)) <
        0) {
        NSLog(@"error connecting.");
        return NO;
    }
    // it is very easy to connect to the control connection of an ftp server,
    // as it is based on the Telnet protocol.

    // at this point, there is a connection.
    // we now send login commands
    sprintf(cmd, "USER %s\r\n", user);
    n = write(sockfd, cmd, strlen(cmd));
    if (n < 0) return NO;
    bzero(cmd, 256);
    sprintf(cmd, "PASS %s\r\n", pass);
    n = write(sockfd, cmd, strlen(cmd));
    if (n < 0) return NO;
    // logged in!
    if (fullCommand) {
        if (chdir) {
            // switch into the working directory:
            bzero(cmd, 256);
            sprintf(cmd, "CWD %s\r\n", wdir);
            n = write(sockfd, cmd, strlen(cmd));
            if (n < 0) return NO;
        }
#ifdef FMSOCKET_VERBOSE
        // if verbose, print out location:
        bzero(cmd, 256);
        sprintf(cmd, "PWD\r\n");
        n = write(sockfd, cmd, strlen(cmd));
        if (n < 0) return NO;
#endif
        // now send the command:
        bzero(cmd, 256);
        sprintf(cmd, "%s\r\n",
                [fullCommand cStringUsingEncoding:NSUTF8StringEncoding]);
        n = write(sockfd, cmd, strlen(cmd));
        if (n < 0) return NO;
    }
    // and say goodbye:
    bzero(cmd, 256);
    sprintf(cmd, "QUIT\r\n");
    n = write(sockfd, cmd, strlen(cmd));
    if (n < 0) return NO;
    // --------
    // now, fetch the answers:
    NSString *answer = [self _listenLoopForSocket:sockfd];
    close(sockfd);
    streamSuccess = [self _checkAnswers:answer];
    action = ACDCurrentActionNone;
    return streamSuccess;
}

#pragma mark - Access Methods

- (uint8_t *)buffer {
    return self->_buffer;
}

@end
