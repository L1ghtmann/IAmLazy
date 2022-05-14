//
//	IALBackupsViewController.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import <UniformTypeIdentifiers/UTCoreTypes.h>
#import "../Managers/IALGeneralManager.h"
#import <AudioToolbox/AudioToolbox.h>
#import "IALBackupsViewController.h"
#import "../Common.h"

// https://stackoverflow.com/a/5337804
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

@implementation IALBackupsViewController

#pragma mark Setup

-(instancetype)init{
	self = [super initWithStyle:UITableViewStyleGrouped];

	if(self){
		_generalManager = [IALGeneralManager sharedManager];
		[self getBackups];
	}

	return self;
}

-(void)loadView{
	[super loadView];

	[self.tableView setSeparatorInset:UIEdgeInsetsZero];

	// replace info nav bar button with import button
	UIBarButtonItem *importItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"plus.circle.fill"] style:UIBarButtonItemStylePlain target:self action:@selector(importBackup)];
	[self.navigationItem setRightBarButtonItem:importItem];

	// setup pull to refresh
	UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
	[refreshControl addTarget:self action:@selector(refreshTable) forControlEvents:UIControlEventValueChanged];
	[self.tableView setRefreshControl:refreshControl];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
	return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
	return [_backups count];
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
	NSString *sectionName;
	switch(section){
		case 0:
			sectionName = @"Backups";
			break;
		default:
			sectionName = @"";
			break;
	}
	return sectionName;
}

-(void)tableView:(UITableView *)tableView willDisplayHeaderView:(UITableViewHeaderFooterView *)header forSection:(NSInteger)section {
	[header.textLabel setTextColor:[UIColor whiteColor]];
	[header.textLabel setFont:[UIFont systemFontOfSize:20 weight:0.56]];
	[header.textLabel setText:[header.textLabel.text capitalizedString]];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
	static NSString *cellIdentifier = @"cell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

	if(!cell){
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
	}

	[cell.textLabel setText:_backups[indexPath.row]];

	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
	AudioServicesPlaySystemSound(1520); // haptic feedback

	// export backup
	NSString *backupName = [tableView cellForRowAtIndexPath:indexPath].textLabel.text;

	// Note: to export a local file, need to use an NSURL
	NSURL *fileURL = [NSURL fileURLWithPath:[backupDir stringByAppendingString:backupName]];

	UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
	[activityViewController setModalTransitionStyle:UIModalTransitionStyleCoverVertical];

	[self presentViewController:activityViewController animated:YES completion:nil];

	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

// requried for method below
-(BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath{
	return YES;
}

-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath{
	AudioServicesPlaySystemSound(1520); // haptic feedback

	if(editingStyle == UITableViewCellEditingStyleDelete){
		// remove backup
		NSString *backupName = [tableView cellForRowAtIndexPath:indexPath].textLabel.text;
		NSString *filePath = [backupDir stringByAppendingPathComponent:backupName];
		NSFileManager *fileManager = [NSFileManager defaultManager];
		if([fileManager isDeletableFileAtPath:filePath]){
			NSError *deleteError = nil;
			[fileManager removeItemAtPath:filePath error:&deleteError];
			if(deleteError){
				NSString *msg = [NSString stringWithFormat:@"An error occured and %@ was not deleted!\n\nError: %@", backupName, deleteError];
				[_generalManager displayErrorWithMessage:msg];
				return;
			}
		}
		else{
			NSString *msg = [NSString stringWithFormat:@"%@ cannot be deleted?!", filePath];
			[_generalManager displayErrorWithMessage:msg];
			return;
		}

		[_backups removeObjectAtIndex:indexPath.row];

		[tableView beginUpdates];
		[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
		[tableView endUpdates];
	}
}

-(void)refreshTable{
	if(self.tableView.refreshControl.refreshing){
		[self.tableView.refreshControl endRefreshing];
	}
	[self getBackups];
	[self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
}

-(void)getBackups{
	_backups = [[_generalManager getBackups] mutableCopy];
}

#pragma mark Functionality

-(void)importBackup{
	UIDocumentPickerViewController *importer;
	if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"14")){
		importer = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeGZIP, UTTypePlainText] asCopy:YES];
	}
	else{
		importer = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"org.gnu.gnu-zip-archive, public.plain-text"] inMode:UIDocumentPickerModeImport];
	}
	[importer setDelegate:self];

	[self presentViewController:importer animated:YES completion:nil];
}

-(void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls{
	// url array count will be >= 1
	NSURL *url = [urls firstObject];

	// Note: need to have the path be /destDir/filename.extension otherwise it'll try to overwrite the destDir??
	NSURL *backupDirURL = [NSURL fileURLWithPath:[backupDir stringByAppendingPathComponent:[url lastPathComponent]]];

	NSError *writeError = nil;
	[[NSFileManager defaultManager] copyItemAtURL:url toURL:backupDirURL error:&writeError];
	if(!writeError){
		NSString *msg = [NSString stringWithFormat:@"An error occured and %@ could not be imported! \n\nError: %@", [url absoluteString], writeError];
		[_generalManager displayErrorWithMessage:msg];
	}

	[self refreshTable];
}

@end
