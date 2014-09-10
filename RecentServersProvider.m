//
//  RecentServersProvider.m
//  SSHFS GUI
//
//  Created by Юрий Насретдинов on 07.02.10.
//  Copyright 2010 МФТИ. All rights reserved.
//

#import "RecentServersProvider.h"


@implementation RecentServersProvider

- (id)init
{
	NSArray *oldEntries;
	NSMutableArray *newEntries;
	
	NSMutableDictionary *row;
	
	self = [super init];
	
	_def = [[NSUserDefaults standardUserDefaults] retain];
	
	oldEntries = [_def objectForKey:@"recentServers"];
	
	if(oldEntries)
	{
		NSString *oldEntry;
		
		newEntries = [NSMutableArray array];
		
		for(int i = 0; i < [oldEntries count]; i++)
		{
			oldEntry = [oldEntries objectAtIndex:i];
			
			NSString *srv = oldEntry;
			NSRange rng;
			
			rng = [srv rangeOfString:@":"];
			
			int port = 22;
			
			if(rng.location != NSNotFound )
			{
				port = [[srv substringFromIndex:rng.location+1] intValue];
				srv = [srv substringToIndex:rng.location];
			}
			
			rng = [srv rangeOfString:@"@"];
			
			NSString *log  = [srv substringToIndex:rng.location];
			NSString *host = [srv substringFromIndex:rng.location+1];
			
			row = [NSMutableDictionary dictionary];
			
			[row setValue:host forKey:@"server"];
			[row setValue:[NSNumber numberWithInt:port] forKey:@"port"];
			[row setValue:log forKey:@"login"];
			[row setValue:@"" forKey:@"dir"];
			[row setValue:@"" forKey:@"arguments"];
			
			[newEntries insertObject:row atIndex:i];
		}
		
		//NSLog(@"%@", newEntries);
		
		[_def removeObjectForKey:@"recentServers"];
		
		[_def setObject:newEntries forKey:@"servers"];
	}
	
	if(![_def objectForKey:@"servers"])
	{
		[_def setObject:[NSArray array] forKey:@"servers"];
	}
	
//	if(! (_entries = [_def 
	
	return self;
}

- (NSDictionary *)getDictAtIndex:(NSUInteger)rowIndex
{
	return [[_def objectForKey:@"servers"] objectAtIndex:rowIndex];
}

- (void)deleteDictAtIndex:(NSUInteger)rowIndex
{
	NSMutableArray *servers = [NSMutableArray arrayWithArray:[_def objectForKey:@"servers"]];
	[servers removeObjectAtIndex:rowIndex];
	[_def setObject:servers forKey:@"servers"];
}

- (void)addEntryWithServer:(NSString *)server port:(int)port login:(NSString *)login directory:(NSString *)directory cmdOpt:(NSString *)cmdOpt
{
	NSMutableArray *servers = [NSMutableArray arrayWithArray:[_def objectForKey:@"servers"]];
	
	NSMutableDictionary *row = [NSMutableDictionary dictionary];
	
	[row setValue:server forKey:@"server"];
	[row setValue:[NSNumber numberWithInt:port] forKey:@"port"];
	[row setValue:login forKey:@"login"];
	[row setValue:directory forKey:@"dir"];
	[row setValue:cmdOpt forKey:@"arguments"];
	
	[servers removeObject:row];
	[servers insertObject:row atIndex:0];
	
	[_def setObject:servers forKey:@"servers"];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [[_def objectForKey:@"servers"] count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	//NSLog(@"rowIndex — %d\n", rowIndex);
	// numbering starts with 0
	
	NSDictionary *dict = [self getDictAtIndex:rowIndex];
	
	NSMutableString *str = [NSMutableString stringWithString:@""];
	
	NSString *login = [dict objectForKey:@"login"];
	NSString *server = [dict objectForKey:@"server"];
	
	[str appendFormat:@"%@@%@", login, server];
	
	int port = [[dict objectForKey:@"port"] intValue];
	
	if(port != 22) [str appendFormat:@":%d", port];
	
	NSString *dir = [dict objectForKey:@"dir"];
	if([dir length] > 0)
	{
		if([dir characterAtIndex:0] == '/') [str appendFormat:@"%@", dir];
		else [str appendFormat:@" on %@", dir];
	}
	
	return str;
}

- (void)dealloc
{
	[_def dealloc];
	
	[super dealloc];
}

@end
