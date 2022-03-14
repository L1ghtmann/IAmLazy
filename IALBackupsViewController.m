//
//	IALBackupsViewController.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import <UniformTypeIdentifiers/UTCoreTypes.h>
#import <AudioToolbox/AudioToolbox.h>
#import "IALBackupsViewController.h"
#import "IALManager.h"
#import "Common.h"

// https://stackoverflow.com/a/5337804
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

@implementation IALBackupsViewController

#pragma mark Setup

-(instancetype)init{
	self = [super initWithStyle:UITableViewStyleGrouped];

	if(self){
		_backups = [[[IALManager sharedInstance] getBackups] mutableCopy];
	}

	return self;
}

-(void)loadView{
	[super loadView];

	// setup top nav bar
	[self.navigationItem setTitleView:[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"AppIcon40x40@2x-clear"]]];

	UIBarButtonItem *srcItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"line.horizontal.3"] style:UIBarButtonItemStylePlain target:self action:@selector(openSrc)];
	[self.navigationItem setLeftBarButtonItem:srcItem];

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
	NSString *localPath = [NSString stringWithFormat:@"file://%@%@", backupDir, backupName];
	NSURL *fileURL = [NSURL URLWithString:localPath]; // to actually export the file, needs to be an NSURL

	UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
	[activityViewController setModalTransitionStyle:UIModalTransitionStyleCoverVertical];

	[self presentViewController:activityViewController animated:YES completion:nil];

	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath{
	AudioServicesPlaySystemSound(1520); // haptic feedback

	if(editingStyle == UITableViewCellEditingStyleDelete){
		// remove backup
		NSString *backupName = [tableView cellForRowAtIndexPath:indexPath].textLabel.text;
		NSString *filePath = [NSString stringWithFormat:@"%@%@", backupDir, backupName];
		if([[NSFileManager defaultManager] isDeletableFileAtPath:filePath]){
			NSError *deleteError = NULL;
			BOOL success = [[NSFileManager defaultManager] removeItemAtPath:filePath error:&deleteError];
			if(!success){
				NSString *reason = [NSString stringWithFormat:@"An error occured and %@ was not deleted! \n\nError: %@", backupName, deleteError.localizedDescription];
				[self popErrorAlertWithReason:reason];
				return;
			}
		}
		else{
			NSString *reason = [NSString stringWithFormat:@"%@ cannot be deleted?!", filePath];
			[self popErrorAlertWithReason:reason];
			return;
		}

		[_backups removeObjectAtIndex:indexPath.row];

		[tableView beginUpdates];
		[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
		[tableView endUpdates];
	}
}

-(BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath{
	return YES;
}

-(void)refreshTable{
	if(self.tableView.refreshControl.refreshing){
		[self.tableView.refreshControl endRefreshing];
	}
	[self getBackups];
	[self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
}

-(void)getBackups{
	_backups = [[[IALManager sharedInstance] getBackups] mutableCopy];
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
	NSURL *url = [urls firstObject];

	// Note: need to have the path be /destDir/filename.extension otherwise it'll try to overwrite the destDir??
	NSString *localPath = [NSString stringWithFormat:@"file://%@%@", backupDir, [url lastPathComponent]];
	NSURL *backupDirURL = [NSURL URLWithString:localPath];

	NSError *writeError = NULL;
	BOOL success = [[NSFileManager defaultManager] copyItemAtURL:url toURL:backupDirURL error:&writeError];
	if(!success){
		NSString *reason = [NSString stringWithFormat:@"An error occured and %@ could not be imported! \n\nError: %@", [url absoluteString], writeError.localizedDescription];
		[self popErrorAlertWithReason:reason];
	}

	[self refreshTable];
}

#pragma mark Popups

-(void)openSrc{
	UIAlertController *alert = [UIAlertController
								alertControllerWithTitle:@"URL Open Request"
								message:@"IAmLazy.app is requesting to open 'https://github.com/L1ghtmann/IAmLazy'\n\nWould you like to proceed?"
								preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *yes = [UIAlertAction
							actionWithTitle:@"Yes"
							style:UIAlertActionStyleDefault
							handler:^(UIAlertAction *action){
								[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/L1ghtmann/IAmLazy"] options:@{} completionHandler:nil];
							}];

	UIAlertAction *no = [UIAlertAction
							actionWithTitle:@"No"
							style:UIAlertActionStyleDefault
							handler:^(UIAlertAction *action){
								[self dismissViewControllerAnimated:YES completion:nil];
							}];

	[alert addAction:yes];
	[alert addAction:no];

	[self presentViewController:alert animated:YES completion:nil];
}

-(void)popErrorAlertWithReason:(NSString *)reason{
	UIAlertController *alert = [UIAlertController
								alertControllerWithTitle:@"IAmLazy Error:"
								message:reason
								preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *okay = [UIAlertAction
							actionWithTitle:@"Okay"
							style:UIAlertActionStyleDefault
							handler:^(UIAlertAction * action) {
								[alert dismissViewControllerAnimated:YES completion:nil];
							}];

	[alert addAction:okay];

	[self presentViewController:alert animated:YES completion:nil];

	NSLog(@"[IAmLazyLog] %@", [reason stringByReplacingOccurrencesOfString:@"\n" withString:@""]);
}

@end
