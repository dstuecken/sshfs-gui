//
//  SSHFS_GUIAppDelegate.h
//  SSHFS GUI
//
//  Created by Юрий Насретдинов on 10.01.10.
//  Copyright 2010 МФТИ. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "Foundation/Foundation.h"

#import "RecentServersProvider.h"

#define IMPLEMENTATION_NONE    0
#define IMPLEMENTATION_MACFUSE 1
#define IMPLEMENTATION_PRQSORG 2

@interface SSHFS_GUIAppDelegate : NSObject <NSControlTextEditingDelegate>
{
    NSWindow *window;
	IBOutlet NSWindow *preferencesWindow;
	
	IBOutlet NSTextField *server;
	IBOutlet NSTextField *login;
	IBOutlet NSTextField *port;
	IBOutlet NSSecureTextField *password;
	
	IBOutlet NSTextField *directory;
	IBOutlet NSTextField *cmdLineOptions;
	IBOutlet NSTextField *command;
	
	IBOutlet NSProgressIndicator *progress;
	
	IBOutlet NSButton *connectButton;
	IBOutlet NSButton *stopButton;
	IBOutlet NSButton *removeButton;
	
	IBOutlet NSTableView *recentServersView;
	
	IBOutlet NSApplication *currentApp;
	
	BOOL shouldTerminate;
	BOOL shouldSkipConnectionError;
	
	// shared user defaults cache
	int implementation;
	BOOL compression;
	BOOL useKeychain;
	// / shared user defaults cache
	
	RecentServersProvider *recentServersDataSource;
	
	int pipes_read[2], pipes_write[2];
}

@property (assign) IBOutlet NSWindow *window;

- (IBAction)connectButtonClicked:(id)sender;
- (IBAction)stopButtonClicked:(id)sender;
- (IBAction)removeButtonClicked:(id)sender;
- (IBAction)addServerToRecents:(id)sender;

- (IBAction)cellAction:(id)sender;

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication;

- (IBAction)showAboutPanel:(id)sender;
- (IBAction)showPreferencesPane:(id)sender;

- (void)setConnectingState:(BOOL)connecting;
- (void)askMessage:(id)msg;
- (void)passwordTeller;

- (void)killByPattern:(NSString *)patt, ...;

- (void)awakeFromNib;

@end
