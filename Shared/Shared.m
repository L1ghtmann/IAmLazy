#import <Common.h>

NSMutableArray<NSString *>* itemDescriptionsForPurposeWithFilter(NSInteger purpose, BOOL filter) {
    NSMutableArray *itemDescs = [NSMutableArray new];

	/*
		purpose: 0 = backup | 1 = restore
	*/

	if(purpose == 0){
		if(filter){
			[itemDescs addObject:localize(@"Determining user packages")];
		}
		else {
			[itemDescs addObject:localize(@"Determining installed packages")];
		}
		[itemDescs addObject:localize(@"Gathering files for packages")];
		[itemDescs addObject:localize(@"Building debs from files")];
		[itemDescs addObject:localize(@"Creating backup from debs")];
	}
	else{
		[itemDescs addObject:localize(@"Completing pre-restore checks")];
		[itemDescs addObject:localize(@"Unpacking backup")];
		[itemDescs addObject:localize(@"Refreshing APT sources")];
		[itemDescs addObject:localize(@"Installing debs")];
	}

	return itemDescs;
}
