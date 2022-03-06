//
//	IALRootViewController.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import <AudioToolbox/AudioToolbox.h>
#import "IALProgressViewController.h"
#import "IALOptionsViewController.h"
#import "IALRootViewController.h"
#import "IALTableViewCell.h"
#import "IALManager.h"
#import "Common.h"

static IALManager *manager;

@implementation IALRootViewController

-(instancetype)init{
	self = [super init];

	if(self){
		manager = [IALManager sharedInstance];
		[manager setRootVC:self];
	}

	return self;
}

-(void)loadView{
	[super loadView];

	[self.navigationItem setTitleView:[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"AppIcon40x40@2x-clear"]]];

	UIBarButtonItem *menuItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"line.horizontal.3"] style:UIBarButtonItemStylePlain target:self action:@selector(popMenu)];
	[self.navigationItem setLeftBarButtonItem:menuItem];

	UIBarButtonItem *infoItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"info.circle.fill"] style:UIBarButtonItemStylePlain target:self action:@selector(popInfo)];
	[self.navigationItem setRightBarButtonItem:infoItem];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
	return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
	return 3;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
	static NSString *cellIdentifier = @"cell";
	IALTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

	NSString *function;
	NSString *functionDescriptor;

	if(indexPath.row == 0){
		function = @"backup";
		functionDescriptor = @"Make Tweak Backup";
	}
	else if(indexPath.row == 1){
		function = @"restore";
		functionDescriptor = @"Restore From Backup";
	}
	else{
		function = @"";
		functionDescriptor = @"Options";
	}

	if(!cell){
		cell = [[IALTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier function:function functionDescriptor:functionDescriptor];
	}

	return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
	// first two cells
	if(indexPath.row < 2){
		return cellHeight;
	}
	// last cell (options cell)
	else{
		return cellHeight/3;
	}
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
	AudioServicesPlaySystemSound(1520); // haptic feedback

	if(indexPath.row == 0){ // backup cell
		[self showBackupSelection];
	}
	else if(indexPath.row == 1){ // restore cell
		[self showRestoreSelection];
	}
	else{ // options cell
		[self showOptions];
	}

	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark Root Options

-(void)showBackupSelection{
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:@"Choose how you'd like to backup:" preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *standard = [UIAlertAction actionWithTitle:@"Standard Backup" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
		UIAlertController *subalert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:@"Please confirm that you have adequate free storage before proceeding" preferredStyle:UIAlertControllerStyleAlert];

		UIAlertAction *confirm = [UIAlertAction actionWithTitle:@"Confirm" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
			[self makeTweakBackupWithFilter:YES];
		}];

		UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
			[self dismissViewControllerAnimated:YES completion:nil];
		}];

		[subalert addAction:confirm];
		[subalert addAction:cancel];

		[self presentViewController:subalert animated:YES completion:nil];
	}];

	UIAlertAction *unfiltered = [UIAlertAction actionWithTitle:@"Unfiltered Backup" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
		UIAlertController *subalert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:@"Please confirm that you have adequate free storage before proceeding" preferredStyle:UIAlertControllerStyleAlert];

		UIAlertAction *confirm = [UIAlertAction actionWithTitle:@"Confirm" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
			[self makeTweakBackupWithFilter:NO];
		}];

		UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
			[self dismissViewControllerAnimated:YES completion:nil];
		}];

		[subalert addAction:confirm];
		[subalert addAction:cancel];

		[self presentViewController:subalert animated:YES completion:nil];
	}];

	UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
		[self dismissViewControllerAnimated:YES completion:nil];
	}];

	[alert addAction:standard];
	[alert addAction:unfiltered];
	[alert addAction:cancel];

	[self presentViewController:alert animated:YES completion:nil];
}

-(void)makeTweakBackupWithFilter:(BOOL)filter{
	if(filter) [self presentViewController:[[IALProgressViewController alloc] initWithPurpose:@"standard-backup"] animated:YES completion:nil];
	else [self presentViewController:[[IALProgressViewController alloc] initWithPurpose:@"unfiltered-backup"] animated:YES completion:nil];
	[[UIApplication sharedApplication] setIdleTimerDisabled:YES]; // disable idle timer (screen dim + lock)
	[manager makeTweakBackupWithFilter:filter];
	[[UIApplication sharedApplication] setIdleTimerDisabled:NO]; // reenable idle timer
	if(![manager encounteredError]){
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
			[self dismissViewControllerAnimated:YES completion:^{
				[self popPostBackup];
			}];
		});
	}
}

-(void)popPostBackup{
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:[NSString stringWithFormat:@"Tweak backup completed successfully in %@ seconds! \n\nYour backup can be found in\n %@", [manager getDuration], backupDir] preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *export = [UIAlertAction actionWithTitle:@"Export" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
		NSString *localPath = [NSString stringWithFormat:@"file:/%@%@", backupDir, [[manager getBackups] firstObject]];
		NSURL *fileURL = [NSURL URLWithString:localPath]; // to actually export the file, needs to be an NSURL

		UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
		[activityViewController setModalTransitionStyle:UIModalTransitionStyleCoverVertical];

		[self presentViewController:activityViewController animated:YES completion:nil];
	}];

	UIAlertAction *okay = [UIAlertAction actionWithTitle:@"Okay" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
		[self dismissViewControllerAnimated:YES completion:nil];
	}];

	[alert addAction:export];
	[alert addAction:okay];

 	[self presentViewController:alert animated:YES completion:nil];
}

-(void)showRestoreSelection{
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:@"Choose how you'd like to restore:" preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *latest = [UIAlertAction actionWithTitle:@"From The Latest Backup" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
		NSString *backupName = [[manager getBackups] firstObject];

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

	UIAlertAction *specific = [UIAlertAction actionWithTitle:@"From A Specific Backup" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
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
		UIAlertController *subalert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:@"Choose the backup you'd like to restore from:" preferredStyle:UIAlertControllerStyleAlert];

		// make each available backup its own action
		for(int i = 0; i < [backupNames count]; i++){
			NSString *backupName = backupNames[i];
			NSString *backupDate = backupDates[i];
			NSString *backup = [NSString stringWithFormat:@"%@ [%@]", backupName, backupDate];
			UIAlertAction *action = [UIAlertAction actionWithTitle:backup style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
				UIAlertController *subsubalert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:[NSString stringWithFormat:@"Are you sure that you want to restore from %@?", backupName] preferredStyle:UIAlertControllerStyleAlert];

				UIAlertAction *yes = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
					[self restoreFromBackup:backupName];
				}];

				UIAlertAction *no = [UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
					[self dismissViewControllerAnimated:YES completion:nil];
				}];

				[subsubalert addAction:yes];
				[subsubalert addAction:no];

				[self presentViewController:subsubalert animated:YES completion:nil];
			}];

			[subalert addAction:action];
		}

		UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
			[self dismissViewControllerAnimated:YES completion:nil];
		}];

		[subalert addAction:cancel];

		[self presentViewController:subalert animated:YES completion:nil];
	}];

	UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
		[self dismissViewControllerAnimated:YES completion:nil];
	}];

	[alert addAction:latest];
	[alert addAction:specific];
	[alert addAction:cancel];

	[self presentViewController:alert animated:YES completion:nil];
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

-(void)showOptions{
	UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:[[IALOptionsViewController alloc] init]];
 	[navigationController setModalPresentationStyle:UIModalPresentationFullScreen];
	[self presentViewController:navigationController animated:YES completion:nil];
}

@end
