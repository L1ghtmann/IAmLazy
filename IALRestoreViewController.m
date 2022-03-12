//
//	IALRestoreViewController.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import <AudioToolbox/AudioToolbox.h>
#import "IALAppDelegate.h"
#import "IALProgressViewController.h"
#import "IALRestoreViewController.h"
#import "IALTableViewCell.h"
#import "IALManager.h"
#import "Common.h"

static IALManager *manager;

@implementation IALRestoreViewController

-(instancetype)init{
	self = [super initWithStyle:UITableViewStyleGrouped];

	if(self){
		manager = [IALManager sharedInstance];
		[manager setRootVC:self];
	}

	return self;
}

-(void)loadView{
	[super loadView];

	[self.tableView setScrollEnabled:NO];

	// setup top nav bar
	[self.navigationItem setTitleView:[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"AppIcon40x40@2x-clear"]]];

	UIBarButtonItem *srcItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"line.horizontal.3"] style:UIBarButtonItemStylePlain target:self action:@selector(openSrc)];
	[self.navigationItem setLeftBarButtonItem:srcItem];

	UIBarButtonItem *infoItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"info.circle.fill"] style:UIBarButtonItemStylePlain target:self action:@selector(popInfo)];
	[self.navigationItem setRightBarButtonItem:infoItem];
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
			sectionName = @"Deb Restore";
			break;
		case 1:
			sectionName = @"List Restore";
			break;
		default:
			sectionName = @"";
			break;
	}
	return sectionName;
}

-(void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
	UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
	header.textLabel.textColor = [UIColor whiteColor];
	header.textLabel.font = [UIFont systemFontOfSize:20 weight:0.56];
	header.textLabel.text = [header.textLabel.text capitalizedString];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
	static NSString *cellIdentifier = @"cell";
	IALTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

	NSString *type;
	NSString *function;
	NSString *functionDescriptor;

	if(indexPath.section == 0){
		type = @"deb";
		functionDescriptor = @" Backup";
	}
	else{
		type = @"list";
		functionDescriptor = @" List";
	}

	if(indexPath.row == 0){
		function = @"latest-restore";
		functionDescriptor = [@"From Latest" stringByAppendingString:functionDescriptor];
	}
	else{
		function = @"specific-restore";
		functionDescriptor = [@"From Specific" stringByAppendingString:functionDescriptor];
	}

	if(!cell){
		cell = [[IALTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier type:type function:function functionDescriptor:functionDescriptor];
	}

	return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
	return cellHeight/4;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
	AudioServicesPlaySystemSound(1520); // haptic feedback

	BOOL latest;
	if(indexPath.row == 0) latest = YES;
	else latest = NO;

	if(indexPath.section == 0){
		[self selectedRestoreWithFormat:@"deb" andLatest:latest];
	}
	else{
		[self selectedRestoreWithFormat:@"list" andLatest:latest];
	}

	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

-(void)selectedRestoreWithFormat:(NSString *)format andLatest:(BOOL)latest{
	if([format isEqualToString:@"deb"]){
		[self restoreDebBackupWithLatest:latest];
	}
	else{
		[self restoreListBackupWithLatest:latest];
	}
}

-(void)restoreDebBackupWithLatest:(BOOL)latest{
	if(latest){
		NSString *backupName = [[manager getBackups] firstObject];
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:[NSString stringWithFormat:@"Are you sure that you want to restore from %@?", backupName] preferredStyle:UIAlertControllerStyleAlert];

		UIAlertAction *yes = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
			[self restoreFromBackup:backupName];
		}];

		UIAlertAction *no = [UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
			[self dismissViewControllerAnimated:YES completion:nil];
		}];

		[alert addAction:yes];
		[alert addAction:no];

		[self presentViewController:alert animated:YES completion:nil];
	}
	else{
		// get (sorted) backup filenames
		NSArray *backupNames = [manager getBackups];

		// get backup creation dates
		NSMutableArray *backupDates = [NSMutableArray new];
		NSDateFormatter *formatter =  [[NSDateFormatter alloc] init];
		[formatter setDateFormat:@"MMM dd, yyyy"];
		for(NSString *backup in backupNames){
			NSString *dateString = nil;

			NSError *readError = NULL;
			NSString *path = [backupDir stringByAppendingPathComponent:backup];
			NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&readError];
			if(readError){
				NSLog(@"[IAmLazyLog] Failed to get attributes for %@! Error: %@", path, readError.localizedDescription);
				dateString = @"Error";
			}
			else{
				NSDate *creationDate = [fileAttributes fileCreationDate];
				dateString = [formatter stringFromDate:creationDate];
			}

			[backupDates addObject:dateString];
		}

		// post list of available backups
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:@"Choose the backup you'd like to restore from:" preferredStyle:UIAlertControllerStyleAlert];

		// make each available backup its own action
		for(int i = 0; i < [backupNames count]; i++){
			NSString *backupName = backupNames[i];
			NSString *backupDate = backupDates[i];
			NSString *backup = [NSString stringWithFormat:@"%@ [%@]", backupName, backupDate];
			UIAlertAction *action = [UIAlertAction actionWithTitle:backup style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
				UIAlertController *subalert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:[NSString stringWithFormat:@"Are you sure that you want to restore from %@?", backupName] preferredStyle:UIAlertControllerStyleAlert];

				UIAlertAction *yes = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
					[self restoreFromBackup:backupName];
				}];

				UIAlertAction *no = [UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
					[self dismissViewControllerAnimated:YES completion:nil];
				}];

				[subalert addAction:yes];
				[subalert addAction:no];

				[self presentViewController:subalert animated:YES completion:nil];
			}];

			[alert addAction:action];
		}

		UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
			[self dismissViewControllerAnimated:YES completion:nil];
		}];

		[alert addAction:cancel];

		[self presentViewController:alert animated:YES completion:nil];
	}
}

-(void)restoreListBackupWithLatest:(BOOL)latest{
	// TODO
}

-(void)restoreFromBackup:(NSString *)backupName{
	[self presentViewController:[[IALProgressViewController alloc] initWithPurpose:@"restore"] animated:YES completion:nil];
	[[UIApplication sharedApplication] setIdleTimerDisabled:YES]; // disable idle timer (screen dim + lock)
	[manager restoreFromBackup:backupName];
	[[UIApplication sharedApplication] setIdleTimerDisabled:NO]; // reenable idle timer
	if(![manager encounteredError]){
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
			[self dismissViewControllerAnimated:YES completion:^{
				[self popPostRestore];
			}];
		});
	}
}

-(void)popPostRestore{
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:@"Choose a post-restore command:" preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *uicache = [UIAlertAction actionWithTitle:@"UICache" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
		NSTask *task = [[NSTask alloc] init];
		[task setLaunchPath:@"/usr/bin/uicache"];
		[task setArguments:@[@"-a"]];
		[task launch];
	}];

	UIAlertAction *respring = [UIAlertAction actionWithTitle:@"Respring" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
		NSTask *task = [[NSTask alloc] init];
		[task setLaunchPath:@"/usr/bin/sbreload"];
		[task launch];
	}];

	UIAlertAction *both = [UIAlertAction actionWithTitle:@"UICache & Respring" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
		NSTask *task = [[NSTask alloc] init];
		[task setLaunchPath:@"/usr/bin/uicache"];
		[task setArguments:@[@"-a", @"-r"]];
		[task launch];
	}];

	UIAlertAction *none = [UIAlertAction actionWithTitle:@"None" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
		[self dismissViewControllerAnimated:YES completion:nil];
	}];

	[alert addAction:uicache];
	[alert addAction:respring];
	[alert addAction:both];
	[alert addAction:none];

 	[self presentViewController:alert animated:YES completion:nil];
}

-(void)openSrc{
	UIAlertController *alert = [UIAlertController
						alertControllerWithTitle:@"URL Open Request"
						message:@"IAmLazy.app is requesting to open 'https://github.com/L1ghtmann/IAmLazy'\n\nWould you like to proceed?"
						preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *yes = [UIAlertAction
							   actionWithTitle:@"Yes"
							   style:UIAlertActionStyleDefault
							   handler:^(UIAlertAction * action) {
									[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/L1ghtmann/IAmLazy"] options:@{} completionHandler:nil];
							   }];

	UIAlertAction *no = [UIAlertAction
							   actionWithTitle:@"No"
							   style:UIAlertActionStyleDefault
							   handler:^(UIAlertAction * action) {
									[self dismissViewControllerAnimated:YES completion:nil];
							   }];

	[alert addAction:yes];
	[alert addAction:no];

	[self presentViewController:alert animated:YES completion:nil];
}

-(void)popInfo{
	UIAlertController *alert = [UIAlertController
							alertControllerWithTitle:@"General Info"
							message:@"IAmLazy.app\nVersion: 2.0.0\n\nMade by Lightmann"
							preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *okay = [UIAlertAction
							   actionWithTitle:@"Okay"
							   style:UIAlertActionStyleDefault
							   handler:^(UIAlertAction * action) {
									[self dismissViewControllerAnimated:YES completion:nil];
							   }];

	[alert addAction:okay];

	[self presentViewController:alert animated:YES completion:nil];
}

@end
