//
//	IALRestoreViewController.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "../Managers/IALGeneralManager.h"
#import <AudioToolbox/AudioToolbox.h>
#import "IALProgressViewController.h"
#import "IALRestoreViewController.h"
#import "IALTableViewCell.h"
#import "../Common.h"
#import <NSTask.h>

@implementation IALRestoreViewController

#pragma mark Setup

-(instancetype)init{
	self = [super initWithStyle:UITableViewStyleGrouped];

	if(self){
		_manager = [IALGeneralManager sharedInstance];
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

-(void)tableView:(UITableView *)tableView willDisplayHeaderView:(UITableViewHeaderFooterView *)header forSection:(NSInteger)section {
	[header.textLabel setTextColor:[UIColor whiteColor]];
	[header.textLabel setFont:[UIFont systemFontOfSize:20 weight:0.56]];
	[header.textLabel setText:[header.textLabel.text capitalizedString]];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
	static NSString *identifier = @"cell";
	IALTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];

	NSInteger purpose = 1; // restore
	NSInteger type; // 0 = deb | 1 = list
	NSInteger function; // 0 = latest | 1 = specific
	NSString *functionDescriptor;

	// eval sections
	if(indexPath.section == 0){
		type = 0;
		functionDescriptor = @" Backup";
	}
	else{
		type = 1;
		functionDescriptor = @" List";
	}

	// eval rows
	if(indexPath.row == 0){
		function = 0;
		functionDescriptor = [@"From Latest" stringByAppendingString:functionDescriptor];
	}
	else{
		function = 1;
		functionDescriptor = [@"From Specific" stringByAppendingString:functionDescriptor];
	}

	if(!cell){
		cell = [[IALTableViewCell alloc] initWithIdentifier:identifier purpose:purpose type:type function:function functionDescriptor:functionDescriptor];
	}

	return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
	return cellHeight;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
	AudioServicesPlaySystemSound(1520); // haptic feedback

	NSInteger type = 0;
	if(indexPath.section != 0) type = 1;

	BOOL latest = YES;
	if(indexPath.row != 0) latest = NO;

	[self restoreLatestBackup:latest ofType:type];

	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark Functionality

-(void)restoreLatestBackup:(BOOL)latest ofType:(NSInteger)type{
	// set extension based on type
	NSString *extension;
	switch(type){
		case 0:
			extension = @".tar.gz";
			break;
		case 1:
			extension = @".txt";
			break;
		default:
			extension = @"";
			break;
	}

	NSArray *backups = [_manager getBackups];

	if(latest){
		// get latest backup
		__block NSString *backupName;
		[backups enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
			NSString *name = (NSString*)obj;
			if([name containsString:extension]){
				backupName = name;
				*stop = YES; // stop enumerating
				return;
			}
		}];

		// get confirmation before proceeding
		UIAlertController *alert = [UIAlertController
									alertControllerWithTitle:@"IAmLazy"
									message:[NSString stringWithFormat:@"Are you sure that you want to restore from %@?", backupName]
									preferredStyle:UIAlertControllerStyleAlert];

		UIAlertAction *yes = [UIAlertAction
								actionWithTitle:@"Yes"
								style:UIAlertActionStyleDefault
								handler:^(UIAlertAction *action){
									[self restoreFromBackup:backupName ofType:type];
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
	else{
		// get (sorted) backup filenames
		NSMutableArray *backupNames = [NSMutableArray new];
		for(NSString *name in backups){
			if([name containsString:extension]){
				[backupNames addObject:name];
			}
		}

		// get backup creation dates
		NSMutableArray *backupDates = [NSMutableArray new];
		NSDateFormatter *formatter =  [[NSDateFormatter alloc] init];
		[formatter setDateFormat:@"MMM dd, yyyy"];
		NSMutableCharacterSet *set = [NSMutableCharacterSet alphanumericCharacterSet];
		[set addCharactersInString:@"+-."];
		for(NSString *backup in backupNames){
			BOOL valid = [[backup stringByTrimmingCharactersInSet:set] isEqualToString:@""];
			if(valid){
				NSString *dateString;

				NSError *readError = nil;
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
		}

		// post list of available backups
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:@"Choose the backup you'd like to restore from:" preferredStyle:UIAlertControllerStyleAlert];

		// make each available backup its own action
		for(int i = 0; i < [backupNames count]; i++){
			NSString *backupName = backupNames[i];

			BOOL valid = [[backupName stringByTrimmingCharactersInSet:set] isEqualToString:@""];
			if(valid){
				NSString *backupDate = backupDates[i];
				NSString *backup = [NSString stringWithFormat:@"%@ [%@]", backupName, backupDate];
				// get confirmation before proceeding
				UIAlertAction *action = [UIAlertAction
											actionWithTitle:backup
											style:UIAlertActionStyleDefault
											handler:^(UIAlertAction *action){
												UIAlertController *subalert = [UIAlertController
																				alertControllerWithTitle:@"IAmLazy"
																				message:[NSString stringWithFormat:@"Are you sure that you want to restore from %@?", backupName]
																				preferredStyle:UIAlertControllerStyleAlert];

												UIAlertAction *yes = [UIAlertAction
																		actionWithTitle:@"Yes"
																		style:UIAlertActionStyleDefault
																		handler:^(UIAlertAction *action){
																			[self restoreFromBackup:backupName ofType:type];
																		}];

												UIAlertAction *no = [UIAlertAction
																		actionWithTitle:@"No"
																		style:UIAlertActionStyleDefault
																		handler:^(UIAlertAction *action){
																			[self dismissViewControllerAnimated:YES completion:nil];
																		}];

												[subalert addAction:yes];
												[subalert addAction:no];

												[self presentViewController:subalert animated:YES completion:nil];
											}];

				[alert addAction:action];
			}
		}

		UIAlertAction *cancel = [UIAlertAction
									actionWithTitle:@"Cancel"
									style:UIAlertActionStyleDefault
									handler:^(UIAlertAction *action){
										[self dismissViewControllerAnimated:YES completion:nil];
									}];

		[alert addAction:cancel];

		[self presentViewController:alert animated:YES completion:^{
			// allow us to dismiss a UIAlertControllerStyleAlert when
			// the user touches anywhere out of bounds of the view
			[alert.view.superview setUserInteractionEnabled:YES];
			[alert.view.superview addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(alertOOBTap)]];
		}];
	}
}

-(void)alertOOBTap{
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)restoreFromBackup:(NSString *)backupName ofType:(NSInteger)type{
	[self presentViewController:[[IALProgressViewController alloc] initWithPurpose:1 ofType:type withFilter:nil] animated:YES completion:nil];
	[[UIApplication sharedApplication] setIdleTimerDisabled:YES]; // disable idle timer (screen dim + lock)
	[_manager restoreFromBackup:backupName ofType:type];
	[[UIApplication sharedApplication] setIdleTimerDisabled:NO]; // reenable idle timer
	if(![_manager encounteredError]){
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
			[self dismissViewControllerAnimated:YES completion:^{
				[self popPostRestore];
			}];
		});
	}
}

#pragma mark Popups

-(void)popPostRestore{
	UIAlertController *alert = [UIAlertController
								alertControllerWithTitle:@"IAmLazy"
								message:@"Choose a post-restore command:"
								preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *uicache = [UIAlertAction
								actionWithTitle:@"UICache"
								style:UIAlertActionStyleDefault
								handler:^(UIAlertAction *action){
									NSTask *task = [[NSTask alloc] init];
									[task setLaunchPath:@"/usr/bin/uicache"];
									[task setArguments:@[@"-a"]];
									[task launch];
								}];

	UIAlertAction *respring = [UIAlertAction
								actionWithTitle:@"Respring"
								style:UIAlertActionStyleDefault
								handler:^(UIAlertAction *action){
									NSTask *task = [[NSTask alloc] init];
									[task setLaunchPath:@"/usr/bin/sbreload"];
									[task launch];
								}];

	UIAlertAction *both = [UIAlertAction
							actionWithTitle:@"UICache & Respring"
							style:UIAlertActionStyleDefault
							handler:^(UIAlertAction *action){
								NSTask *task = [[NSTask alloc] init];
								[task setLaunchPath:@"/usr/bin/uicache"];
								[task setArguments:@[@"-a", @"-r"]];
								[task launch];
							}];

	UIAlertAction *none = [UIAlertAction
							actionWithTitle:@"None"
							style:UIAlertActionStyleDefault
							handler:^(UIAlertAction *action){
								[self dismissViewControllerAnimated:YES completion:nil];
							}];

	[alert addAction:uicache];
	[alert addAction:respring];
	[alert addAction:both];
	[alert addAction:none];

 	[self presentViewController:alert animated:YES completion:nil];
}

@end
