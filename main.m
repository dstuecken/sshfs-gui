//
//  main.m
//  SSHFS GUI
//
//  Created by Юрий Насретдинов on 10.01.10.
//  Copyright 2010 МФТИ. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#include <unistd.h>
#include <fcntl.h>

int main(int argc, char *argv[])
{
#ifndef RELEASE
//#if 0
	
	//test behaviour when there are no shared defaults
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	unlink( [[@"~/Library/Preferences/org.YNProducts.SSHFS-GUI.plist" stringByExpandingTildeInPath] UTF8String] );
	
	[pool release];
	
#endif
	
	if(isatty(0))
	{
		printf("Actually, this application MUST NOT be run from a terminal. You will probably have to enter your password from console (sorry...)!\n");
		
		// as I said, program works incorrectly when input is a TTY (SSH_ASKPASS utility is ignored)
		// and next methods do not seem to influence SSH utility behaviour,
		// but they do influence the Console of XCode, so it cannot read any debug output from the application :)
		// that is why the next part is commented
		
		/* 
		int i = 0;
		
		for(i = 0; i < 3; i++)
		{
			close(i);
			open("/dev/null", O_RDWR);
		}
		
		putenv("TERM_PROGRAM=");
		putenv("TERM=");
		putenv("SHELL=");
		putenv("SHLVL=");
		putenv("LOGNAME=");
		 */
	}

    return NSApplicationMain(argc,  (const char **) argv);
}
