//
//	util.m
//	IAmLazy-CLI
//
//	Created by Lightmann
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <Shared.h>
#import "util.h"

NSArray *getOpts(){
	@autoreleasepool{
		NSArray *opts = @[
			@"-h",
			@"--help",
			@"-b",
			@"--backup",
			@"-r",
			@"--restore",
			@"-l",
			@"--list"
		];
		return opts;
	}
}

NSString *getHelp(){
	@autoreleasepool{
		NSString *msg = @"\
Usage: ial [options]\n\
Options:\n\
  [-b|--backup]       Create a backup\n\
  [-r|--restore]      Restore from a backup\n\
  [-l|--list]         List available backups\n\
  [-h|--help]         Display this page";
		return msg;
	}
}

// https://stackoverflow.com/a/25753918
NSString *getInput(){
	@autoreleasepool{
		NSString *input = [[NSString alloc] initWithData:[[NSFileHandle fileHandleWithStandardInput] availableData] encoding:NSUTF8StringEncoding];
		NSString *cleanInput = [input stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
		return [cleanInput stringByReplacingOccurrencesOfString:@" " withString:@""];
	}
}

NSString *prompt(NSArray<NSString *> *items, NSInteger upperBound){
	@autoreleasepool{
		__block NSString *input = nil;
		do {
			for(NSString *item in items){
				print(item);
			}
			input = getInput();
			if([input length] == 1 && [input intValue] <= upperBound){
				break;
			}
		} while(true);
		return input;
	}
}

void handleObserverForPurposeWithFilter(NSInteger purpose, BOOL filter){
	NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
	[notifCenter addObserverForName:@"updateItemStatus" object:nil queue:nil usingBlock:^(NSNotification *notification) {
		CGFloat item = [(NSString *)notification.object floatValue];
		NSInteger itemInt = ceil(item);
		NSArray *itemDescriptions = itemDescriptionsForPurposeWithFilter(purpose,filter);
		NSString *msg = [@"[!] " stringByAppendingString:itemDescriptions[itemInt]];
		puts([msg UTF8String]);
	}];
	[notifCenter addObserverForName:@"updateItemProgress" object:nil queue:nil usingBlock:^(NSNotification *notification) {
		CGFloat progress = [(NSString *)notification.object floatValue];
		NSString *msg = [NSString stringWithFormat:@"%.02f%%", (progress * 100)];
		puts([msg UTF8String]);
	}];
}
