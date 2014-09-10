//
//  RecentServersProvider.h
//  SSHFS GUI
//
//  Created by Юрий Насретдинов on 07.02.10.
//  Copyright 2010 МФТИ. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface RecentServersProvider : NSObject <NSTableViewDataSource> {
	
	NSUserDefaults *_def;
}

- (id)init;
- (void)dealloc;

- (void)addEntryWithServer:(NSString *)server port:(int)port login:(NSString *)login directory:(NSString *)directory cmdOpt:(NSString *)cmdOpt;
- (NSDictionary *)getDictAtIndex:(NSUInteger)rowIndex;
- (void)deleteDictAtIndex:(NSUInteger)rowIndex;

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;

@end
