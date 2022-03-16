//
//	IALRootViewController.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import <AudioToolbox/AudioToolbox.h>
#import "IALProgressViewController.h"
#import "IALRootViewController.h"
#import "../Managers/IALGeneralManager.h"
#import "../Managers/IALBackupManager.h"
#import "IALTableViewCell.h"
#import "../IALAppDelegate.h"
#import "../Common.h"

@implementation IALRootViewController

#pragma mark Setup

-(instancetype)init{
	self = [super initWithStyle:UITableViewStyleGrouped];

	if(self){
		_manager = [IALGeneralManager sharedInstance];
		[_manager setRootVC:self];
	}

	return self;
}

-(void)loadView{
	[super loadView];

	[self.tableView setScrollEnabled:NO];

	// setup bottom tab bar
	UITabBar *bottomBar = [[UITabBar alloc] initWithFrame:CGRectMake(0, kHeight-self.navigationController.navigationBar.frame.size.height-5, kWidth, self.navigationController.navigationBar.frame.size.height)];
	[[[[UIApplication sharedApplication] windows] firstObject] addSubview:bottomBar];
	[bottomBar setDelegate:self];

	NSMutableArray *tabBarItems = [[NSMutableArray alloc] init];

	UITabBarItem *create = [[UITabBarItem alloc] initWithTitle:@"Create" image:[UIImage systemImageNamed:@"plus.app"] tag:0];
	UITabBarItem *backups = [[UITabBarItem alloc] initWithTitle:@"Backups" image:[UIImage systemImageNamed:@"folder.fill"] tag:1];
	UITabBarItem *restore = [[UITabBarItem alloc] initWithTitle:@"Restore" image:[UIImage systemImageNamed:@"arrow.counterclockwise.circle"] tag:2];

	[create setTitlePositionAdjustment:UIOffsetMake(0.0, -2.0)];
	[backups setTitlePositionAdjustment:UIOffsetMake(0.0, -2.0)];
	[restore setTitlePositionAdjustment:UIOffsetMake(0.0, -2.0)];

	[tabBarItems addObject:create];
	[tabBarItems addObject:backups];
	[tabBarItems addObject:restore];

	[bottomBar setItems:tabBarItems];
	[bottomBar setSelectedItem:[tabBarItems objectAtIndex:0]];
}

-(void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item{
	NSInteger selectedTag = tabBar.selectedItem.tag;

	IALAppDelegate *delegate = (IALAppDelegate *)[[UIApplication sharedApplication] delegate];

	if (selectedTag == 0){
		[delegate.tabBarController setSelectedViewController:delegate.rootViewController];
	}
	else if(selectedTag == 1){
		[delegate.tabBarController setSelectedViewController:delegate.backupsViewController];
	}
	else{
		[delegate.tabBarController setSelectedViewController:delegate.restoreViewController];
	}
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
	static NSString *cellIdentifier = @"cell";
	IALTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

	NSString *type;
	NSString *function;
	NSString *functionDescriptor;

	// eval section
	if(indexPath.section == 0){
		type = @"deb";
		functionDescriptor = @" Backup";
	}
	else{
		type = @"list";
		functionDescriptor = @" List";
	}

	// eval row
	if(indexPath.row == 0){
		function = @"standard-backup";
		functionDescriptor = [@"Standard" stringByAppendingString:functionDescriptor];
	}
	else{
		function = @"unfiltered-backup";
		functionDescriptor = [@"Unfiltered" stringByAppendingString:functionDescriptor];
	}

	if(!cell){
		cell = [[IALTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier type:type function:function functionDescriptor:functionDescriptor];
	}

	return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
	return cellHeight/3.25;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
	AudioServicesPlaySystemSound(1520); // haptic feedback

	BOOL filter = NO;
	if(indexPath.row == 0) filter = YES;

	if(indexPath.section == 0){
		[self selectedBackupOfType:0 withFilter:filter];
	}
	else{
		[self selectedBackupOfType:1 withFilter:filter];
	}

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
								handler:^(UIAlertAction * action){
									[self makeBackupOfType:type withFilter:filter];
								}];

	UIAlertAction *cancel = [UIAlertAction
								actionWithTitle:@"Cancel"
								style:UIAlertActionStyleDefault
								handler:^(UIAlertAction * action){
									[self dismissViewControllerAnimated:YES completion:nil];
								}];

	[alert addAction:confirm];
	[alert addAction:cancel];

	[self presentViewController:alert animated:YES completion:nil];
}

-(void)makeBackupOfType:(NSInteger)type withFilter:(BOOL)filter{
	[self presentViewController:[[IALProgressViewController alloc] initWithPurpose:0 ofType:type withFilter:filter] animated:YES completion:nil];
	[[UIApplication sharedApplication] setIdleTimerDisabled:YES]; // disable idle timer (screen dim + lock)
	[_manager makeBackupOfType:type withFilter:filter];
	[[UIApplication sharedApplication] setIdleTimerDisabled:NO]; // reenable idle timer
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
								alertControllerWithTitle:@"IAmLazy"
								message:[NSString stringWithFormat:@"Tweak backup completed successfully in %@ seconds! \n\nYour backup can be found in\n %@", [_manager.backupManager getDuration], backupDir]
								preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *export = [UIAlertAction
								actionWithTitle:@"Export"
								style:UIAlertActionStyleDefault
								handler:^(UIAlertAction * action){
									NSString *localPath = [NSString stringWithFormat:@"file://%@%@", backupDir, [[_manager getBackups] firstObject]];
									NSURL *fileURL = [NSURL URLWithString:localPath]; // to actually export the file, needs to be an NSURL

									UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
									[activityViewController setModalTransitionStyle:UIModalTransitionStyleCoverVertical];

									[self presentViewController:activityViewController animated:YES completion:nil];
								}];

	UIAlertAction *okay = [UIAlertAction
							actionWithTitle:@"Okay"
							style:UIAlertActionStyleDefault
							handler:^(UIAlertAction * action){
								[self dismissViewControllerAnimated:YES completion:nil];
							}];

	[alert addAction:export];
	[alert addAction:okay];

 	[self presentViewController:alert animated:YES completion:nil];
}

@end
