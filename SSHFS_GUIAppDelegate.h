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
#define IMPLEMENTATION_CUSTOM  3

@interface SSHFS_GUIAppDelegate : NSObject <NSControlTextEditingDelegate, NSWindowDelegate, NSTableViewDelegate>
{
    NSWindow *__weak window;
	IBOutlet NSWindow *preferencesWindow;
	IBOutlet NSTextField *preferencesWindowSshfsPath;
	
	IBOutlet NSTextField *server;
	IBOutlet NSTextField *login;
	IBOutlet NSTextField *port;
	IBOutlet NSSecureTextField *password;
	
	IBOutlet NSPathControl* pathControl;
	
	IBOutlet NSTextField *directory;
	IBOutlet NSTextField *localDirectory;
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
	NSString *sshfsPath;
	// / shared user defaults cache
	
	RecentServersProvider *recentServersDataSource;
	
	int pipes_read[2], pipes_write[2];
}

@property (weak) IBOutlet NSWindow *window;

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;

- (void)windowWillClose:(NSNotification *)notification;

- (IBAction)connectButtonClicked:(id)sender;
- (IBAction)stopButtonClicked:(id)sender;
- (IBAction)removeButtonClicked:(id)sender;
- (IBAction)addServerToRecents:(id)sender;

- (IBAction)cellAction:(id)sender;
- (IBAction)openFileDialog:(id)sender;

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication;

- (IBAction)showAboutPanel:(id)sender;
- (IBAction)showPreferencesPane:(id)sender;

- (void)setConnectingState:(BOOL)connecting;
- (void)askMessage:(id)msg;
- (void)passwordTeller;

- (void)killByPattern:(NSString *)patt, ...;

- (void)awakeFromNib;

- (void) loadRecentServerSelection;

@end
