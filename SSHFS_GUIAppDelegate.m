//
//  SSHFS_GUIAppDelegate.m
//  SSHFS GUI
//
//  Created by Юрий Насретдинов on 10.01.10.
//  Copyright 2010 МФТИ. All rights reserved.
//

#include <stdio.h>
#include <unistd.h>
#include <signal.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <util.h>
#include <math.h>

#include "shared.h"

#import "SSHFS_GUIAppDelegate.h"

#import <CoreFoundation/CoreFoundation.h>
#import <Security/Security.h>

@implementation SSHFS_GUIAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
#ifndef RELEASE
	NSLog(@"Debugging");
	NSLog(@"applicationDidFinishLaunching\n");
#endif
	
	// it was really stupid for me to have only one pipe
	// and try to estabilish bi-directional connection to
	// asker utility
	
	// of course, one would need at least two pipes, otherwise
	// you would write something to the pipe and then read all data
	// you wrote there immediately, while waiting for data... how stupid :)
	
	pipe(pipes_read);
	pipe(pipes_write);

#ifndef RELEASE
	NSLog(@"pipes ids: read=%d,%d ; write=%d,%d\n", pipes_read[0], pipes_read[1], pipes_write[0], pipes_write[1]);
#endif
	
	[NSThread detachNewThreadSelector:@selector(passwordTeller) toTarget:self withObject:nil];
}

- (void)passwordTeller
{
	//NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	unsigned long length;
	int tmp, action;
	char *str = "", buf[1025];
	
	NSMutableString *msg;
	
	// zero or less read bytes probably means that pipe is
	// broken (it also could mean that read was interrupted
	// by a signal, but there are no signals which we would
	// respond without app termination, so just ignore it)
	
	while( read(pipes_read[0], &action, sizeof(action)) > 0 )
	{
		switch (action)
		{
			case ACTION_ASK_PASSWORD:
				str = (char*) [[password stringValue] UTF8String]; // even though access to UI elements is not thread-safe, when the connection is initialized, all input fields are explicitly set to read-only, so we are safe at least to READ the values directly from UI elements
				break;
			case ACTION_AUTHENTICITY_CHECK:
				msg = [[NSMutableString alloc] initWithUTF8String:""];
				
				read(pipes_read[0], &length, sizeof(length));
				while( (tmp = (int) read(pipes_read[0], buf, length >= sizeof(buf)-1 ? sizeof(buf)-1 : length)) > 0 )
				{
					buf[tmp] = 0;
					length -= tmp;
					
					[msg appendFormat:@"%s", buf];
					
					if(length <= 0) break;
				}
				
				// msg is retained by this thread, so it safe to pass NSMutableString and not to worry about some memory going to AutoreleasePool of another thread
				[self performSelectorOnMainThread:@selector(askMessage:) withObject:msg waitUntilDone:YES];
				
				//printf("\n");
				
				str = (char*) [msg UTF8String]; // get an autoreleased UTF8String copy of the MutableString
				
				[msg release];
				
				break;
		}
		
		length = strlen(str);
		
		write(pipes_write[1], &length, sizeof(length));
		write(pipes_write[1], str, length);
		
		//[pool release];
		//pool = [[NSAutoreleasePool alloc] init];
	} 
}

- (void)awakeFromNib
{
#ifndef RELEASE
	NSLog(@"awakeFromNib\n");
#endif
	
	[command setEditable:FALSE];
	
	NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
	
#if 0
//#ifndef RELEASE
	 NSDictionary *dict = [def dictionaryRepresentation];
	 
	 for(NSString *key in dict)
	 {
		 NSLog(@"%@ = %@\n", key, [dict objectForKey:key]);
	 }
#endif	 
	
	NSFileManager *mng = [NSFileManager defaultManager];
	BOOL wasLaunched = [def boolForKey:@"wasLaunched"];
	
#ifndef RELEASE
	NSLog(@"wasLaunched = %d\n", wasLaunched);
#endif
	
	if(!wasLaunched)
	{
		// need to determine, what is installed, and if it is installed
		// if nothing is installed, show "Nothing found" message and quit
		
		if( [mng fileExistsAtPath:@"/Library/Frameworks/MacFUSE.framework"] )
		{
			[def setObject:@"MacFUSE" forKey:@"implementation"];
		}else if( [mng fileExistsAtPath:@"/Applications/sshfs/bin/mount_sshfs"] )
		{
			[def setObject:@"pqrs.org" forKey:@"implementation"];
		}else
		{
			NSAlert *alert = [NSAlert alertWithMessageText:@"SSHFS is not available" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@"No implementations found\n(either one at http://pqrs.org/macosx/sshfs/ or MacFUSE at http://code.google.com/p/macfuse/).\n\nClick OK to quit the application"];
			
			[alert runModal];
			
			[currentApp terminate:nil];
		}
		
		
		[def setBool:YES forKey:@"compression"];
		[def setBool:YES forKey:@"wasLaunched"];
		[def setBool:YES forKey:@"useKeychain"];
		
	}	
	
	if(![def stringForKey:@"login"])
	{
		[login setStringValue:[NSString stringWithUTF8String:getenv("USER")]];
	}
	
	if(!recentServersDataSource) recentServersDataSource = [[RecentServersProvider alloc] init];
	[recentServersView setDataSource:recentServersDataSource];
	
	[command setStringValue:[self getCommandPreview]];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	if(stopButton && [stopButton isEnabled])
	{
		printf("Caught applicationShouldTerminate notification. Cancelling last connection attempt.\n");
		
		//currentApp = sender;
		shouldTerminate = YES;
		
		[self stopButtonClicked:nil];
		
		return NSTerminateLater;
		
		// there could be some processes left, which also
		// will be killed after system("mount_ssfhs / sshfs-static-leopard ...") call fails
		// because of ourselves killing all child processes,
		// including mount_sshfs / sshfs-static-leopard launched by system()
	}
	
	return NSTerminateNow;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	return YES;
}

- (IBAction)addServerToRecents:(id)sender
{
	[recentServersDataSource addEntryWithServer:[server stringValue] port:[port intValue] login:[login stringValue] directory:[directory stringValue] cmdOpt:[cmdLineOptions stringValue]];
}

- (IBAction)removeButtonClicked:(id)sender
{
	// TODO: take care about deleting passwords from KeyChain
	
	NSInteger rowIndex = [recentServersView selectedRow];
	if( rowIndex < 0 ) return; // nothing is actually selected...
	
	[recentServersDataSource deleteDictAtIndex:rowIndex];
	[recentServersView reloadData];
	
	if([recentServersView selectedRow] < 0) [removeButton setEnabled:NO];
}

- (IBAction)cellAction:(id)sender
{
	NSInteger rowIndex;
	
	if( (rowIndex = [recentServersView selectedRow]) >= 0 )
	{
		[removeButton setEnabled:YES];
		
		NSDictionary *row = [recentServersDataSource getDictAtIndex:rowIndex];
				
		NSString *log  = [row objectForKey:@"login"];
		NSString *host = [row objectForKey:@"server"];
		
		[login  setStringValue:log];
		[server setStringValue:host];
		[port setStringValue:[row objectForKey:@"port"]];
		
		NSString *remoteDir = [row objectForKey:@"dir"];
		NSString *arguments = [row objectForKey:@"arguments"];
		
		[directory setStringValue:remoteDir];
		[cmdLineOptions setStringValue:arguments];
		
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"useKeychain"])
		{
			const char *serverName = [host UTF8String];
			UInt32 serverNameLength = (UInt32) strlen(serverName);
			
			const char *accountName = [[login stringValue] UTF8String];
			UInt32 accountNameLength = (UInt32) strlen(accountName);
			
			const char *path;
			
			if([remoteDir length] > 0) path = [remoteDir UTF8String];
			else path = "/~";
			
			UInt32 pathLength = (UInt32) strlen(path);
			
			UInt32 passwordLength;
			void *passwordData;
			
#ifndef RELEASE
			NSLog(@"Using KeyChain to retrieve password for %s@%s:%@%s", accountName, serverName, [port stringValue], path);
#endif
			
			OSStatus retVal;
			
			if( (retVal = SecKeychainFindInternetPassword(NULL, serverNameLength, serverName, 0, NULL, accountNameLength, accountName, pathLength, path, [port intValue], kSecProtocolTypeSSH, kSecAuthenticationTypeDefault, &passwordLength, &passwordData, NULL)) == 0)
			{
#ifndef RELEASE				
				NSLog(@"Found the password in KeyChain");
#endif
				
				// the thing is that passwordData is (void *) and is NOT nul-terminated string,
				// so in order to use it as a string we need to manually copy it
				NSString *passValue = [[NSString alloc] initWithBytes:passwordData length:passwordLength encoding:NSUTF8StringEncoding];
				
				[password setStringValue:passValue];
				
				SecKeychainItemFreeContent(NULL, passwordData);
				[passValue release];
			}else
			{
#ifndef RELEASE				
				NSString *errmsg = (NSString*)SecCopyErrorMessageString(retVal, NULL);
				
				NSLog(@"Could not fetch info from KeyChain, recieved code %d with following explanation: %@", retVal, errmsg);
				
				[errmsg release];
#endif
				
				[password setStringValue:@""];
				//[password selectText:nil];
			}

			
		}
		
	}
	else
	{
		[removeButton setEnabled:NO];
	}
}

- (IBAction)connectButtonClicked:(id)sender
{
	[self setConnectingState:YES];
	
	[NSThread detachNewThreadSelector:@selector(connectToServer:) toTarget:self withObject:nil];
}

- (IBAction)stopButtonClicked:(id)sender
{
	// kill the spawned applications, so that the thread will terminate
	
	NSString *cmd = [NSString stringWithFormat:@"/bin/ps -ajx | /usr/bin/awk '{ if($3 == %d) print $2; }'", getpid()];
	
	//printf("%s\n", [cmd UTF8String]);
	
	FILE *pp = popen([cmd UTF8String], "r");
	
	if(pp)
	{
		char buf[22]; // absolute expected maximum for PID length :)
		
		while(!feof(pp))
		{
			fread(buf, 1, sizeof(buf)-1, pp);
			//printf("%s", buf);
			kill(atoi(buf), SIGTERM);
		}
		
		pclose(pp);
	}
	
	[self setConnectingState:NO];
}

- (IBAction)showAboutPanel:(id)sender
{
	const char *credits_html = "<div style='font-family: \"Lucida Grande\"; font-size: 10px;' align='center'>Project is located at <br><a href='https://github.com/dstuecken/sshfs-gui'>https://github.com/dstuecken/sshfs-gui</a></div>";
	
	NSData *HTML = [[NSData alloc] initWithBytes:credits_html length:strlen(credits_html)];
	NSAttributedString *credits = [[NSAttributedString alloc] initWithHTML:HTML documentAttributes:NULL];
	
	
	NSString *version = @"1.2";
	NSString *applicationVersion = [NSString stringWithFormat:@"Version %@", version];
	
	NSArray *keys = [NSArray arrayWithObjects:@"Credits", @"Version", @"ApplicationVersion", nil];
	NSArray *objects = [NSArray arrayWithObjects:credits, @"", applicationVersion, nil];
	NSDictionary *options = [NSDictionary dictionaryWithObjects:objects forKeys:keys];
	
	[HTML release];
	[credits release];
	
	[currentApp orderFrontStandardAboutPanelWithOptions:options];
}

- (IBAction)showPreferencesPane:(id)sender
{
	[preferencesWindow setIsVisible:YES];
}


// reads the message from NSMutableString *msg and puts either @"yes" or @"no" back

- (void)askMessage:(id)msg
{
	NSMutableString *buf = msg;
	
	NSAlert *alert = [NSAlert alertWithMessageText:@"Authenticity check" defaultButton:@"Accept key" alternateButton:@"Dismiss key" otherButton:nil informativeTextWithFormat:@"%@", buf];
	
	long response = [alert runModal];
	
	if(response == NSAlertDefaultReturn)
	{
		[buf setString:@"yes"];
	}else
	{
		// of course, mount_sshfs / sshfs-static-leopard would raise an error
		// when connecting, but we can skip this error and do not show the error
		// message to user, because it is not really an error, just a notice
		// that you refused SSH authentity check
		
		[buf setString:@"no"];
		shouldSkipConnectionError = YES;
	}
}

-(int) getPort
{
	int intPort = [port intValue];
	if (!intPort) intPort = 22;

	// cut the port from domain name (can be in form "example.com:port_number")
	NSRange rng = [[server stringValue] rangeOfString:@":"];
	if(rng.location != NSNotFound )
	{
		return [[[server stringValue] substringFromIndex:rng.location+1] intValue];
	}
	
	return intPort;
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
	[command setStringValue:[self getCommandPreview]];
	
	return YES;
}

-(NSString*) getCommandPreview
{
	NSString *srv  = [server stringValue];
	NSString *log  = [login stringValue];
	int intPort = [self getPort];
	
	NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
	compression = [def boolForKey:@"compression"];
	useKeychain = [def boolForKey:@"useKeychain"];
	
	if( [[def stringForKey:@"implementation"] isEqualToString:@"MacFUSE"] ) implementation = IMPLEMENTATION_MACFUSE;
	else                                                                    implementation = IMPLEMENTATION_PRQSORG;
	
	// prepare variables for execution of mount_sshfs
	
	NSString *mnt_loc = [NSString stringWithFormat:@"/Volumes/%@@%@", log, srv];
	NSString *cmd;
	
	NSString *remote_dir = [directory stringValue];
	
	NSString *cmdlnOpt = [cmdLineOptions stringValue];
	
	switch(implementation)
	{
		case IMPLEMENTATION_PRQSORG:
			cmd = [NSString stringWithFormat:@"/Applications/sshfs/bin/mount_sshfs -p %d %@ '%@@%@:%@' '%@'", intPort, cmdlnOpt, log, srv, remote_dir, mnt_loc];
			break;
		case IMPLEMENTATION_MACFUSE:
			chdir( [[[NSBundle mainBundle] bundlePath] UTF8String] );
			cmd = [NSString stringWithFormat:@"sshfs '%@@%@:%@' '%@' -p %d %@ -o workaround=nonodelay -ovolname='%@@%@' -oNumberOfPasswordPrompts=1 -o transform_symlinks -o idmap=user %@", log, srv, remote_dir, mnt_loc, intPort, cmdlnOpt, log, srv, compression ? @" -C" : @""];
			break;
	}
	
	return cmd;
}

// the connection to the server itself is run on a separate thread to prevent application UI blocking
- (void)connectToServer:(id)data
{
	//NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSFileManager *mng = [NSFileManager defaultManager];
	
	NSAlert *alert;
	
	NSString *srv  = [server stringValue];
	NSString *log  = [login stringValue];
	int intPort = [self getPort];
	
	NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
	compression = [def boolForKey:@"compression"];
	useKeychain = [def boolForKey:@"useKeychain"];
	
	if( [[def stringForKey:@"implementation"] isEqualToString:@"MacFUSE"] ) implementation = IMPLEMENTATION_MACFUSE;
	else                                                                    implementation = IMPLEMENTATION_PRQSORG;
	
	// prepare variables for execution of mount_sshfs
	
	NSString *mnt_loc = [NSString stringWithFormat:@"/Volumes/%@@%@", log, srv];
	NSString *cmd;
	
	NSString *remote_dir = [directory stringValue];
	
	NSString *cmdlnOpt = [cmdLineOptions stringValue];
	
	switch(implementation)
	{
		case IMPLEMENTATION_PRQSORG:
			cmd = [NSString stringWithFormat:@"/Applications/sshfs/bin/mount_sshfs -p %d %@ '%@@%@:%@' '%@' >%s 2>&1", intPort, cmdlnOpt, log, srv, remote_dir, mnt_loc, ERR_TMPFILE];
			break;
		case IMPLEMENTATION_MACFUSE:
			chdir( [[[NSBundle mainBundle] bundlePath] UTF8String] );
			cmd = [NSString stringWithFormat:@"./Contents/Resources/sshfs-static-leopard '%@@%@:%@' '%@' -p %d %@ -o workaround=nonodelay -ovolname='%@@%@' -oNumberOfPasswordPrompts=1 -o transform_symlinks -o idmap=user %@ >%s 2>&1", log, srv, remote_dir, mnt_loc, intPort, cmdlnOpt, log, srv, compression ? @" -C" : @"", ERR_TMPFILE];
			break;
	}
	
	//NSLog(@"%@", cmd);
	
	// check for errors in input parameters
	
	NSString *errorText = @"";
	
	BOOL canContinue = YES;
	
	int opcode = -1;
	
	if([srv rangeOfString:@" "].location != NSNotFound )
	{
		canContinue = NO;
		
		errorText = @"Domain name cannot contain spaces";
	}
	
	else if(![srv length])
	{
		canContinue = NO;
		
		errorText = @"Domain name cannot be empty";
	}
	
	else if( [log rangeOfString:@" "].location != NSNotFound )
	{
		canContinue = NO;
		
		errorText = @"Login cannot contain spaces";
	}
	
	else if(![log length])
	{
		canContinue = NO;
		
		errorText = @"Login cannot be empty";
	}else if([[NSFileManager defaultManager] fileExistsAtPath:mnt_loc])
	{
		alert = [NSAlert alertWithMessageText:@"Already mounted" defaultButton:@"No" alternateButton:@"Yes" otherButton:nil informativeTextWithFormat:@"It looks like you have already mounted this volume. It is strongly recommended to unmount it first.\n\nIf you continue, you might experience undesired side effects, especially if you have just switched the SSHFS implementation.\n\nDo you want to continue?"];
		
		long response = [alert runModal];
		
		if(response == NSAlertDefaultReturn) canContinue = NO;
		shouldSkipConnectionError = YES;
	}else if(implementation == IMPLEMENTATION_PRQSORG && ![mng fileExistsAtPath:@"/Applications/sshfs/bin/mount_sshfs"])
	{
		alert = [NSAlert alertWithMessageText:@"SSHFS console utility missing" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"You do not seem to have SSHFS console utility from pqrs.org installed.\n\nPlease download and install it either from\nhttp://pqrs.org/macosx/sshfs/\n\nor from SSHFS GUI project at\n\nhttp://code.google.com/p/sshfs-gui/"];
	
		[alert runModal];
		
		//[pool release];
		
		[self stopButtonClicked:nil];
		
		return;
	}
	
	// if all parameters are correct, we can launch the utility itself
	
	if(canContinue)
	{
		mkdir([mnt_loc UTF8String], 0755);
		
		if(!getenv("DISPLAY")) putenv("DISPLAY=NONE"); // need to set something DISPLAY variable in order SSH_ASKPASS to activate
		putenv((char*)[[NSString stringWithFormat:@"SSHFS_PIPES=%d,%d;%d,%d", pipes_write[0], pipes_write[1], pipes_read[0], pipes_read[1]] UTF8String]);
		putenv((char*)[[NSString stringWithFormat:@"SSH_ASKPASS=%@/Contents/Resources/asker", [[NSBundle mainBundle] bundlePath]] UTF8String]);
		
		//printf("Preparing to make a system call\n");
		
		opcode = system([cmd UTF8String]);
		
		errorText = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:ERR_TMPFILE] encoding:NSUTF8StringEncoding error:NULL];
		unlink(ERR_TMPFILE);
		
		//printf("opcode: %d\n", opcode);
		
		if([errorText hasPrefix:@"Permission denied"])
		{
			errorText = @"Permission denied. Please verify your login and password.";
		}
	}

	NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
	 mnt_loc,                                   @"mountPoint",
	 errorText,                                 @"errorText",
	 [NSString stringWithFormat:@"%d", opcode], @"opcode",
	 [NSString stringWithFormat:@"%d", intPort],@"port",
	 srv,                                       @"server",
	 remote_dir,                                @"remote_dir",
     cmdlnOpt,                                  @"arguments",
	nil];
	
	[self performSelectorOnMainThread:@selector(finishConnectToServer:) withObject:dictionary waitUntilDone:NO];
	
	//[pool release];
}

- (void)killByPattern:(NSString *)patt, ...
{
	va_list argumentList;
	va_start(argumentList, patt);
	
	NSString *cmd_patt = [NSString stringWithFormat:@"/bin/kill `/bin/ps -ax | /usr/bin/grep '%@' | /usr/bin/awk '{print $1;}'`", patt];
	NSString *cmd = [[NSString alloc] initWithFormat:cmd_patt arguments:argumentList];
	
	system([cmd UTF8String]);
	
	[cmd release];
	
	va_end(argumentList);
}

- (void)finishConnectToServer:(id)dictionary
{
	NSDictionary *dict = dictionary;
	
	NSString *mountPoint = [dict valueForKey:@"mountPoint"];
	NSString *errorText = [dict valueForKey:@"errorText"];
	int opcode = [[dict valueForKey:@"opcode"] intValue];
	int intPort = [[dict valueForKey:@"port"] intValue];
	NSString *srv = [dict valueForKey:@"server"];
	
	NSString *remote_dir = [dict valueForKey:@"remote_dir"];
	NSString *arguments = [dict valueForKey:@"arguments"];
	
	if(opcode == 0)
	{
		system([[NSString stringWithFormat:@"open '%@'", mountPoint] UTF8String]);
		
		//NSString *serverStr = [NSString stringWithFormat:@"%@@%@%@", [login stringValue], srv, intPort != 22 ? [NSString stringWithFormat:@":%d", intPort] : @"" ];
		
		//[recentServersDataSource addEntry:serverStr];
		[recentServersDataSource addEntryWithServer:srv port:intPort login:[login stringValue] directory:remote_dir cmdOpt:arguments];
		
		if(useKeychain)
		{
			SecKeychainItemRef itemRef;
			
			const char *serverName = [srv UTF8String];
			UInt32 serverNameLength = (UInt32) strlen(serverName);
			
			const char *accountName = [[login stringValue] UTF8String];
			UInt32 accountNameLength = (UInt32) strlen(accountName);
			
			//char *path = "/~"; // do you have any other options which would mean a home directory (the directory mounted by SSHFS is by default HOME directory, not root) :)?
			const char *path;
			
			if([remote_dir length] > 0) path = [remote_dir UTF8String];
			else path = "/~";
			
			UInt32 pathLength = (UInt32) strlen(path);
			
			const char *passwordData = [[password stringValue] UTF8String];
			UInt32 passwordLength = (UInt32) strlen(passwordData);
			
			if(SecKeychainFindInternetPassword(NULL, serverNameLength, serverName, 0, NULL, accountNameLength, accountName, pathLength, path, intPort, kSecProtocolTypeSSH, kSecAuthenticationTypeDefault, NULL, NULL, &itemRef) == 0 /* means all is ok */)
			{
				// It is said in documentation that we should use ItemModify if you want to modify content, bla-bla-bla...
				// You can rewrite this part, so it will use the other "good" approach and send me a patch, if you want
				SecKeychainItemDelete(itemRef);
				
				CFRelease(itemRef);
			}
			
			OSStatus retVal;
			
			retVal = SecKeychainAddInternetPassword(NULL, serverNameLength, serverName, 0, NULL, accountNameLength, accountName, pathLength, path, intPort, kSecProtocolTypeSSH, kSecAuthenticationTypeDefault, passwordLength, passwordData, NULL);
			
#ifndef RELEASE			
			if(retVal != 0)
			{
		
				NSString *errmsg = (NSString*)SecCopyErrorMessageString(retVal, NULL);
				
				NSLog(@"Could not store info to KeyChain, recieved code %d with following explanation: %@", retVal, errmsg);
				
				[errmsg release];

				
			}
#endif
			
		}
		
		[recentServersView reloadData];
		
	}
	else if(opcode != SIGTERM && !shouldSkipConnectionError) // if error code is SIGTERM, this means our app killed the process by ourselves (look at stopButtonClicked: code)
	{
		NSAlert *alert = [NSAlert alertWithMessageText:@"Could not connect" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:errorText];
		
		[alert runModal];
		
#ifndef RELEASE
		NSLog(@"mount finished at %@ with code %d and error text: %@\n", mountPoint, opcode, errorText);
#endif
	}else if(opcode == SIGTERM)
	{
		// unfortunately, some processes are left after we terminate all our direct children processes, so we will kill all the rest hanging processes manually
		
		if(implementation == IMPLEMENTATION_PRQSORG)      [self killByPattern:@"/Applications/sshfs/bin/mount_sshfs -p %d %@@%@", intPort, [login stringValue], srv];
		else if(implementation == IMPLEMENTATION_MACFUSE) [self killByPattern:@"./Contents/Resources/sshfs-static-leopard %@@%@:", [login stringValue], srv];
		
		[self killByPattern:@"ssh .* %@@%@ -s sftp", [login stringValue], srv];
		
		if(shouldTerminate) [currentApp replyToApplicationShouldTerminate:YES];
	}

	if(opcode) rmdir([mountPoint UTF8String]);
	
	[self setConnectingState:NO];
}

- (void)setConnectingState:(BOOL)connecting
{
	BOOL cs = connecting ? NO  : YES; // connect [controls] state (enabled or disabled)
	BOOL ss = connecting ? YES : NO;  // stop    [button]   state (enabled or disabled)
	
	if(connecting) [progress startAnimation:nil];
	else           [progress stopAnimation:nil];
	
	[server   setEditable:cs];
	[login    setEditable:cs];
	[password setEditable:cs];
	
	[connectButton setEnabled:cs];
	[stopButton    setEnabled:ss];
}

@end
