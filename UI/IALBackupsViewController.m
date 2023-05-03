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

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending) // https://stackoverflow.com/a/5337804

@implementation IALBackupsViewController

#pragma mark Setup

-(instancetype)init{
	self = [super initWithStyle:UITableViewStyleGrouped];

	if(self){
		_manager = [IALGeneralManager sharedManager];
	}

	return self;
}

-(void)loadView{
	[super loadView];

	// get data to present
	[self getBackups];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
	return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
	return [_backups count];
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
	return localize(@"Backups");
}

-(void)tableView:(UITableView *)tableView willDisplayHeaderView:(UITableViewHeaderFooterView *)header forSection:(NSInteger)section{
	[header.textLabel setTextColor:[UIColor labelColor]];
	[header.textLabel setFont:[UIFont systemFontOfSize:(20 * scaleFactor) weight:0.56]];
	[header.textLabel setText:[header.textLabel.text capitalizedString]];

	// add import "+" button to header
	UIButton *import = [UIButton buttonWithType:UIButtonTypeSystem];
	[header addSubview:import];

	[import setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[import.widthAnchor constraintEqualToConstant:50] setActive:YES];
	[[import.heightAnchor constraintEqualToConstant:50] setActive:YES];
	[[import.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-5] setActive:YES];
	[[import.topAnchor constraintEqualToAnchor:header.topAnchor constant:5] setActive:YES];

	[import setImage:[UIImage systemImageNamed:@"plus.circle.fill"] forState:UIControlStateNormal];
	[import addTarget:self action:@selector(importBackup) forControlEvents:UIControlEventTouchUpInside];
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
	AudioServicesPlaySystemSound(1520);

	if(editingStyle == UITableViewCellEditingStyleDelete){
		// delete backup
		NSString *backupName = [tableView cellForRowAtIndexPath:indexPath].textLabel.text;
		NSString *filePath = [backupDir stringByAppendingPathComponent:backupName];
		NSFileManager *fileManager = [NSFileManager defaultManager];
		if([fileManager isDeletableFileAtPath:filePath]){
			NSError *deleteError = nil;
			[fileManager removeItemAtPath:filePath error:&deleteError];
			if(deleteError){
				NSString *msg = [NSString stringWithFormat:[[localize(@"An error occured and %@ was not deleted!")
																stringByAppendingString:@"\n\n"]
																stringByAppendingString:localize(@"Info: %@")],
																backupName,
																deleteError.localizedDescription];
				[self displayErrorWithMessage:msg];
				return;
			}
		}
		else{
			NSString *msg = [NSString stringWithFormat:localize(@"%@ cannot be deleted?!"), filePath];
			[self displayErrorWithMessage:msg];
			return;
		}

		// [_backups removeObjectAtIndex:indexPath.row];

		[tableView beginUpdates];
		// the method below causes the section header to shift up?? Not sure why, but just refreshing works fine
		// [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
		[self refreshTable];
		[tableView endUpdates];
	}
}

#pragma mark Functionality

-(void)refreshTable{
	[self getBackups];
	[self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
}

-(void)getBackups{
	_backups = [[_manager getBackups] mutableCopy];
}

-(void)importBackup{
	UIDocumentPickerViewController *importer;
	if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"14")){
		importer = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeGZIP] asCopy:YES];
	}
	else{
		importer = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"org.gnu.gnu-zip-archive"] inMode:UIDocumentPickerModeImport];
	}
	[importer setDelegate:self];

	[self presentViewController:importer animated:YES completion:nil];
}

-(void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls{
	// 'urls' count will always be 1
	NSURL *url = [urls firstObject];

	// Note: need to have the path be /destDir/filename.extension otherwise it'll try to overwrite the destDir??
	NSURL *backupDirURL = [NSURL fileURLWithPath:[backupDir stringByAppendingPathComponent:[url lastPathComponent]]];

	NSError *writeError = nil;
	[[NSFileManager defaultManager] copyItemAtURL:url toURL:backupDirURL error:&writeError];
	if(writeError){
		NSString *msg = [NSString stringWithFormat:[[localize(@"An error occured and %@ could not be imported!")
														stringByAppendingString:@"\n\n"]
														stringByAppendingString:localize(@"Info: %@")],
														[url absoluteString],
														writeError.localizedDescription];
		[self displayErrorWithMessage:msg];
		return;
	}

	[self refreshTable];
}

#pragma mark Popups

-(void)displayErrorWithMessage:(NSString *)msg{
	UIAlertController *alert = [UIAlertController
								alertControllerWithTitle:localize(@"IAmLazy Error:")
								message:msg
								preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *okay = [UIAlertAction
							actionWithTitle:localize(@"Okay")
							style:UIAlertActionStyleDefault
							handler:nil];

	[alert addAction:okay];

	[self presentViewController:alert animated:YES completion:nil];
}

@end
