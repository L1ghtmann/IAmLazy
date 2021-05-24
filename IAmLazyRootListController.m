#include "IAmLazyRootListController.h"
#import "IAmLazyViewController.h"
#import "IAmLazyManager.h"
#import "Common.h"
#import <AudioToolbox/AudioToolbox.h>

static IAmLazyManager *manager;

@implementation IAmLazyRootListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}

	return _specifiers;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSInteger lastSectionIndex = [tableView numberOfSections]-1;
	NSInteger lastRowIndex = [tableView numberOfRowsInSection:lastSectionIndex]-1;
	NSIndexPath *pathToLastRow = [NSIndexPath indexPathForRow:lastRowIndex inSection:lastSectionIndex];
	// custom cell height
	if(indexPath != pathToLastRow){
		return cellHeight; 
	}
	// for text cell (last cell), use a smaller height
	else{
		return cellHeight/3;
	}
}

- (instancetype)init {
	self = [super init];

	if(self){
		manager = [NSClassFromString(@"IAmLazyManager") sharedInstance];
		[manager setRootVC:self];
	}
	
	return self;
}

- (void)makeTweakBackup:(id)sender {
	AudioServicesPlaySystemSound(1520); // haptic feedback

	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:@"Please confirm that you have adequate free storage before proceeding" preferredStyle:UIAlertControllerStyleActionSheet];

	UIAlertAction *confirm = [UIAlertAction actionWithTitle:@"Confirm" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
		[self presentViewController:[[IAmLazyViewController alloc] initWithPurpose:@"backup"] animated:YES completion:nil];
		[[UIApplication sharedApplication] setIdleTimerDisabled:YES]; // disable idle timer (screen dim + lock)
		[manager makeTweakBackup];
		[[UIApplication sharedApplication] setIdleTimerDisabled:NO]; // reenable idle timer 
		if(![manager encounteredError]){
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
				[self dismissViewControllerAnimated:YES completion:^ {
					[self popPostBackup];
				}];
			});
		}
	}];

	UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
		[self dismissViewControllerAnimated:YES completion:nil];
	}];

	[alert addAction:confirm];
    [alert addAction:cancel];

	[self presentViewController:alert animated:YES completion:nil];
}

- (void)restoreFromBackup:(id)sender {
	AudioServicesPlaySystemSound(1520); // haptic feedback 
	
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:@"Choose how you'd like to restore:" preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *latest = [UIAlertAction actionWithTitle:@"From Latest Backup" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
		[self presentViewController:[[IAmLazyViewController alloc] initWithPurpose:@"restore"] animated:YES completion:nil];
		[[UIApplication sharedApplication] setIdleTimerDisabled:YES]; // disable idle timer (screen dim + lock)
		[manager restoreFromBackup];
		[[UIApplication sharedApplication] setIdleTimerDisabled:NO]; // reenable idle timer 
		if(![manager encounteredError]){
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
				[self dismissViewControllerAnimated:YES completion:^ {
					[self popPostRestore];
				}];
			});
		}
	}];

	UIAlertAction *specific = [UIAlertAction actionWithTitle:@"From A Specific Backup" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {		
		NSMutableDictionary *backupInfo = [NSMutableDictionary new];							

		// get backup file names							
		NSArray *backupNames = [manager getBackups];

		NSDateFormatter *formatter =  [[NSDateFormatter alloc] init];
		[formatter setDateFormat:@"MMM dd, yyyy"];

		// get backup creation dates
		NSMutableArray *backupDates = [NSMutableArray new];
		for(NSString *backup in backupNames){
			NSString *path = [backupDir stringByAppendingPathComponent:backup];
			NSDictionary *fileAttribs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
			NSDate *creationDate = [fileAttribs fileCreationDate]; 
			NSString *dateString = [formatter stringFromDate:creationDate];
			[backupDates addObject:dateString];
			[backupInfo setObject:dateString forKey:backup];
		}

		// sort backup info (https://stackoverflow.com/a/43096808)
		NSSortDescriptor *nameDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES comparator:^NSComparisonResult(id obj1, id obj2) {
			return - [(NSString *)obj1 compare:(NSString *)obj2 options:NSNumericSearch]; // note: "-" == NSOrderedDescending
		}];
		NSArray *sortedBackupNames = [[backupInfo allKeys] sortedArrayUsingDescriptors:@[nameDescriptor]];
		NSArray *sortedBackupDates = [backupInfo objectsForKeys:sortedBackupNames notFoundMarker:[NSNull null]];

		// post list of available backups 
		UIAlertController *subalert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:@"Choose the backup you'd like to restore from:" preferredStyle:UIAlertControllerStyleAlert];
		
		// make each available backup its own action 
		for(int i = 0; i < [backupNames count]; i++){
			NSString *backupName = sortedBackupNames[i];
			NSString *backupDate = sortedBackupDates[i];
			NSString *backup = [NSString stringWithFormat:@"%@ [%@]", backupName, backupDate];
			UIAlertAction *action = [UIAlertAction actionWithTitle:backup style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
				[self presentViewController:[[IAmLazyViewController alloc] initWithPurpose:@"restore"] animated:YES completion:nil];
				[[UIApplication sharedApplication] setIdleTimerDisabled:YES]; // disable idle timer (screen dim + lock)
				[manager restoreFromBackup:backupName];
				[[UIApplication sharedApplication] setIdleTimerDisabled:NO]; // reenable idle timer 
				if(![manager encounteredError]){
					dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
						[self dismissViewControllerAnimated:YES completion:^ {
							[self popPostRestore];
						}];
					});
				}
			}];

			[subalert addAction:action];
		}

		// add a cancel action to the end of the list 
		UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
			[self dismissViewControllerAnimated:YES completion:nil];
		}];

		[subalert addAction:cancel];

		[self presentViewController:subalert animated:YES completion:nil];
	}];

	UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
		[self dismissViewControllerAnimated:YES completion:nil];
	}];

	[alert addAction:latest];
	[alert addAction:specific];
    [alert addAction:cancel];

	[self presentViewController:alert animated:YES completion:nil];
}

-(void)popPostBackup{
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:[NSString stringWithFormat:@"Tweak backup completed successfully in %@ seconds!", [[NSClassFromString(@"IAmLazyManager") sharedInstance] getDuration]] preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *okay = [UIAlertAction actionWithTitle:@"Okay" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
		[self dismissViewControllerAnimated:YES completion:nil];
	}];

    [alert addAction:okay];

 	[self presentViewController:alert animated:YES completion:nil];
}

-(void)popPostRestore{
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:@"Choose a post-restore command:" preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *uicache = [UIAlertAction actionWithTitle:@"UICache" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
		NSTask *task = [[NSTask alloc] init];
		[task setLaunchPath:@"/usr/bin/uicache"];
		[task setArguments:@[@"-a"]];  
		[task launch];
	}];

    UIAlertAction *respring = [UIAlertAction actionWithTitle:@"Respring" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
		NSTask *task = [[NSTask alloc] init];
		[task setLaunchPath:@"/usr/bin/sbreload"];  
		[task launch];
	}];

    UIAlertAction *both = [UIAlertAction actionWithTitle:@"UICache & Respring" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
		NSTask *task = [[NSTask alloc] init];
		[task setLaunchPath:@"/usr/bin/uicache"];
		[task setArguments:@[@"-a", @"--respring"]];  
		[task launch];
	}];

    UIAlertAction *none = [UIAlertAction actionWithTitle:@"None" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
		[self dismissViewControllerAnimated:YES completion:nil];
	}];

    [alert addAction:uicache];
	[alert addAction:respring];
    [alert addAction:both];
	[alert addAction:none];

 	[self presentViewController:alert animated:YES completion:nil];
}

@end
