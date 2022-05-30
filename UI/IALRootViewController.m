//
//	IALRootViewController.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "../Managers/IALGeneralManager.h"
#import "../Managers/IALBackupManager.h"
#import <AudioToolbox/AudioToolbox.h>
#import "IALProgressViewController.h"
#import "IALRootViewController.h"
#import "IALTableViewCell.h"
#import "../Common.h"

@implementation IALRootViewController

#pragma mark Setup

-(instancetype)init{
	self = [super initWithStyle:UITableViewStyleGrouped];

	if(self){
		_manager = [IALGeneralManager sharedManager];
		[_manager setRootVC:self];

		// set tabbar item
		UITabBarItem *create = [[UITabBarItem alloc] initWithTitle:@"Create" image:[UIImage systemImageNamed:@"plus.app"] tag:0];
		[create setTitlePositionAdjustment:UIOffsetMake(0.0, -2.0)];
		[self setTabBarItem:create];
	}

	return self;
}

-(void)loadView{
	[super loadView];
	[self.tableView setScrollEnabled:NO];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
	return 2;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
	return 2;
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
	NSString *sectionName;
	switch(section){
		case 0:
			sectionName = @"Deb Backup";
			break;
		case 1:
			sectionName = @"List Backup";
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
	static NSString *identifier = @"cell";
	IALTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];

	NSInteger type = indexPath.section; // 0 = deb | 1 = list
	NSInteger function = indexPath.row; // 0 = filtered | 1 = unfiltered
	NSString *functionDescriptor;

	// eval section
	if(indexPath.section == 0){
		functionDescriptor = @"Backup";
	}
	else{
		functionDescriptor = @"List";
	}

	// eval row
	if(indexPath.row == 0){
		functionDescriptor = [NSString stringWithFormat:@"Standard %@", functionDescriptor];
	}
	else{
		functionDescriptor = [NSString stringWithFormat:@"Unfiltered %@", functionDescriptor];
	}

	if(!cell){
		cell = [[IALTableViewCell alloc] initWithIdentifier:identifier purpose:0 type:type function:function functionDescriptor:functionDescriptor];
	}

	return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
	return cellHeight;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
	AudioServicesPlaySystemSound(1520); // haptic feedback

	BOOL filter = !indexPath.row;

	[self selectedBackupOfType:indexPath.section withFilter:filter];

	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark Functionality

-(void)selectedBackupOfType:(NSInteger)type withFilter:(BOOL)filter{
	UIAlertController *alert = [UIAlertController
								alertControllerWithTitle:@"IAmLazy"
								message:@"Please confirm that you have adequate free storage before proceeding"
								preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *confirm = [UIAlertAction
								actionWithTitle:@"Confirm"
								style:UIAlertActionStyleDefault
								handler:^(UIAlertAction *action){
									[self makeBackupOfType:type withFilter:filter];
								}];

	UIAlertAction *cancel = [UIAlertAction
								actionWithTitle:@"Cancel"
								style:UIAlertActionStyleDefault
								handler:^(UIAlertAction *action){
									[self dismissViewControllerAnimated:YES completion:nil];
								}];

	[alert addAction:confirm];
	[alert addAction:cancel];

	[self presentViewController:alert animated:YES completion:nil];
}

-(void)makeBackupOfType:(NSInteger)type withFilter:(BOOL)filter{
	UIApplication *app = [UIApplication sharedApplication];
	[self presentViewController:[[IALProgressViewController alloc] initWithPurpose:0 ofType:type withFilter:filter] animated:YES completion:nil];
	[app setIdleTimerDisabled:YES]; // disable idle timer (screen dim + lock)
	[_manager makeBackupOfType:type withFilter:filter];
	[app setIdleTimerDisabled:NO]; // reenable idle timer
	if(![_manager encounteredError]){
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
			[self dismissViewControllerAnimated:YES completion:^{
				[self popPostBackup];
			}];
		});
	}
}

#pragma mark Popups

-(void)popPostBackup{
	UIAlertController *alert = [UIAlertController
								alertControllerWithTitle:@"IAmLazy Notice:"
								message:[NSString stringWithFormat:@"Tweak backup completed successfully in %@ seconds!\n\nYour backup can be found in\n%@", [_manager.backupManager getDuration], backupDir]
								preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *export = [UIAlertAction
								actionWithTitle:@"Export"
								style:UIAlertActionStyleDefault
								handler:^(UIAlertAction *action){
									// Note: to export a local file, need to use an NSURL
									NSURL *fileURL = [NSURL fileURLWithPath:[backupDir stringByAppendingPathComponent:[[_manager getBackups] firstObject]]];

									UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
									[activityViewController setModalTransitionStyle:UIModalTransitionStyleCoverVertical];

									[self presentViewController:activityViewController animated:YES completion:nil];
								}];

	UIAlertAction *okay = [UIAlertAction
							actionWithTitle:@"Okay"
							style:UIAlertActionStyleDefault
							handler:^(UIAlertAction *action){
								[self dismissViewControllerAnimated:YES completion:nil];
							}];

	[alert addAction:export];
	[alert addAction:okay];

 	[self presentViewController:alert animated:YES completion:nil];
}

@end
