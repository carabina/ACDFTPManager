//
//  AppDelegate.m
//  FTPManager
//
//  Created by onedotM on 16/3/13.
//  Copyright © 2016年 onedotM. All rights reserved.
//

#import "ACDFTPServer.h"
#import "AppDelegate.h"

@implementation AppDelegate
@synthesize createDirectoryField = _createDirectoryField;
@synthesize directoryField = _directoryField;
@synthesize directoryPanel = _directoryPanel;
@synthesize downloadFileField = _downloadFileField;
@synthesize downloadFilePanel = _downloadFilePanel;
@synthesize actionProgressField = _actionProgressField;
@synthesize actionProgressBar = _actionProgressBar;
@synthesize actionPanel = _actionPanel;
@synthesize fileListOutputField = _fileListOutputField;
@synthesize fileListOutputPanel = _fileListOutputPanel;
@synthesize loginPasswordField = _loginPasswordField;
@synthesize loginUserField = _loginUserField;
@synthesize serverURLField = _serverURLField;
@synthesize window = _window;

#pragma mark -

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
}

- (void)didEndSheet:(NSWindow *)sheet
         returnCode:(NSInteger)returnCode
        contextInfo:(void *)contextInfo {
    [sheet orderOut:self];
}

#pragma mark - Progress

- (void)reloadProgress {
    if (ftpManager) {
        NSDictionary *progress = [ftpManager progress];
        if (progress) {
            NSNumber *prog =
                [progress objectForKey:(id) kFMProcessInfoProgress];
            [self.actionProgressBar setDoubleValue:[prog doubleValue]];
            NSNumber *bytesProcessed =
                [progress objectForKey:(id) kFMProcessInfoFileSizeProcessed];
            NSNumber *fileSize =
                [progress objectForKey:(id) kFMProcessInfoFileSize];
            [self.actionProgressField
                setStringValue:[NSString
                                   stringWithFormat:@"%i bytes of %i bytes",
                                                    [bytesProcessed intValue],
                                                    [fileSize intValue]]];
        }
    }
}

#pragma mark - Processing Files List

- (NSString *)processDict:(NSDictionary *)dict {
    NSString *name = [dict objectForKey:(id) kCFFTPResourceName];
    NSNumber *size = [dict objectForKey:(id) kCFFTPResourceSize];
    NSDate *mod = [dict objectForKey:(id) kCFFTPResourceModDate];
    NSNumber *type = [dict objectForKey:(id) kCFFTPResourceType];
    NSNumber *mode = [dict objectForKey:(id) kCFFTPResourceMode];
    NSString *isFolder = ([type intValue] == 4) ? @"(folder) " : @"";
    return [NSString
        stringWithFormat:@"%@ %@--- size %i bytes - mode:%i - modDate: %@\n",
                         name, isFolder, [size intValue], [mode intValue],
                         [mod description]];
}

- (void)processSData:(NSArray *)data {
    NSString *str = @"";
    for (NSDictionary *d in data) {
        str = [str stringByAppendingString:[self processDict:d]];
    }
    [self.fileListOutputField setString:str];
    [NSApp beginSheet:self.fileListOutputPanel
        modalForWindow:self.window
         modalDelegate:self
        didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
           contextInfo:nil];
}

#pragma mark - FTPManager interaction
- (void)endRunAction:(NSArray *)optionalServerData {
    [NSApp endSheet:self.actionPanel];
    if (progressTimer) {
        [progressTimer invalidate];
        progressTimer = nil;
    }
    [self.actionProgressBar stopAnimation:self];
    if (!aborted) {
        if (optionalServerData) {
            [self processSData:optionalServerData];
        } else {
            if (success) {
                NSBeginInformationalAlertSheet(
                    @"Success", @"Close", nil, nil, self.window, self, nil, nil,
                    nil, @"Action completed successfully.");
            } else {
                NSBeginAlertSheet(@"Error", @"Close", nil, nil, self.window,
                                  self, nil, nil, nil, @"An error occurred.");
            }
        }
    }
}

- (void)_runAction {
    ftpManager = [[ACDFTPManager alloc] init];
    ftpManager.delegate = self;
    success = NO;
    NSArray *serverData = nil;
    ACDFTPServer *srv = [ACDFTPServer
        serverWithDestination:
            [self.serverURLField.stringValue
                stringByAppendingPathComponent:self.directoryField.stringValue]
                     username:self.loginUserField.stringValue
                     password:self.loginPasswordField.stringValue];
    srv.port = self.portField.intValue;
    switch (action) {
        case acd_upload:
            success = [ftpManager uploadFile:fileURL toServer:srv];
            break;
        case acd_download:
            success = [ftpManager
                downloadFile:self.downloadFileField.stringValue
                 toDirectory:[NSURL fileURLWithPath:NSHomeDirectory()]
                  fromServer:srv];
            break;
        case acd_newfolder:
            success = [ftpManager
                createNewFolder:self.createDirectoryField.stringValue
                       atServer:srv];
            break;
        case acd_list:
            serverData = [ftpManager contentsOfServer:srv];
            break;
        case acd_del:
            success =
                [ftpManager deleteFileNamed:self.deleteFileField.stringValue
                                 fromServer:srv];
            break;
        case acd_chmod:
            success = [ftpManager chmodFileNamed:self.chmodFileField.stringValue
                                              to:self.chmodModeField.intValue
                                        atServer:srv];
            break;
        default:
            break;
    }
    [self performSelectorOnMainThread:@selector(endRunAction:)
                           withObject:serverData
                        waitUntilDone:NO];
    action = acd_nothing;
}

- (void)runAction {
    aborted = NO;
    [NSApp beginSheet:self.actionPanel
        modalForWindow:self.window
         modalDelegate:self
        didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
           contextInfo:nil];
    if (action != acd_nothing) {
        [self performSelectorInBackground:@selector(_runAction) withObject:nil];
        [self.actionProgressField setStringValue:@""];
        [self.actionProgressBar setMaxValue:1.0];
        if (action == acd_download || action == acd_upload) {
            [self.actionProgressBar setIndeterminate:NO];
            [self.actionProgressBar setDoubleValue:0.0];
            progressTimer = [NSTimer
                scheduledTimerWithTimeInterval:0.1
                                        target:self
                                      selector:@selector(reloadProgress)
                                      userInfo:nil
                                       repeats:YES];
        } else {
            [self.actionProgressBar startAnimation:self];
            [self.actionProgressBar setIndeterminate:YES];
        }
    }
}

#pragma mark - View things

- (IBAction)pushUploadAFile:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseFiles:YES];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setResolvesAliases:YES];
    [openPanel setPrompt:@"Upload"];
    [openPanel setDirectoryURL:[NSURL fileURLWithPath:NSHomeDirectory()]];
    [openPanel beginSheetModalForWindow:self.window
                      completionHandler:^(NSInteger result) {
                          [openPanel close];
                          if (result == NSFileHandlingPanelOKButton) {
                              fileURL = [[openPanel URLs] objectAtIndex:0];
                              action = acd_upload;
                              [self runAction];
                          } else {
                              action = acd_nothing;
                          }
                      }];
}

- (IBAction)pushDownloadAFile:(id)sender {
    [NSApp beginSheet:self.downloadFilePanel
        modalForWindow:self.window
         modalDelegate:self
        didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
           contextInfo:nil];
}

- (IBAction)downloadAFile:(id)sender {
    [NSApp endSheet:self.downloadFilePanel];
    //    [self.downloadFilePanel close];
    //    [self.downloadFilePanel orderOut:self];
    action = acd_download;
    [self runAction];
}

- (IBAction)pushListFiles:(id)sender {
    action = acd_list;
    [self runAction];
}

- (IBAction)pushCreateADirectory:(id)sender {
    [NSApp beginSheet:self.directoryPanel
        modalForWindow:self.window
         modalDelegate:self
        didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
           contextInfo:nil];
}

- (IBAction)createADirectory:(id)sender {
    [NSApp endSheet:self.directoryPanel];
    action = acd_newfolder;
    [self runAction];
}
- (IBAction)pushDeleteAFile:(id)sender {
    [NSApp beginSheet:self.deletePanel
        modalForWindow:self.window
         modalDelegate:self
        didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
           contextInfo:nil];
}
- (IBAction)confirmDeleteAFile:(id)sender {
    [NSApp endSheet:self.deletePanel];
    action = acd_del;
    [self runAction];
}
- (IBAction)pushChmod:(id)sender {
    [NSApp beginSheet:self.chmodPanel
        modalForWindow:self.window
         modalDelegate:self
        didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
           contextInfo:nil];
}
- (IBAction)confirmChmod:(id)sender {
    [NSApp endSheet:self.chmodPanel];
    action = acd_chmod;
    [self runAction];
}

- (IBAction)abort:(id)sender {
    if (ftpManager) {
        aborted = YES;
        [ftpManager abort];
    }
}

#pragma mark - dismiss panels

- (IBAction)dismissDownloadPanel:(id)sender {
    [NSApp endSheet:self.downloadFilePanel];
}
- (IBAction)dismissDirectoryPanel:(id)sender {
    [NSApp endSheet:self.directoryPanel];
}
- (IBAction)dismissFolderOutputPanel:(id)sender {
    [NSApp endSheet:self.fileListOutputPanel];
}
- (IBAction)dismissDeletePanel:(id)sender {
    [NSApp endSheet:self.deletePanel];
}
- (IBAction)dismissChmodPanel:(id)sender {
    [NSApp endSheet:self.chmodPanel];
}

- (void)hasError:(Boolean)hasError {
    NSLog(@"%hhu", hasError);
}

@end
