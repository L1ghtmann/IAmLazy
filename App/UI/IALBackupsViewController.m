//
//	IALBackupsViewController.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "../../Shared/Managers/IALGeneralManager.h"
#import <UniformTypeIdentifiers/UTCoreTypes.h>
#import <AudioToolbox/AudioServices.h>
#import "IALProgressViewController.h"
#import "IALBackupsViewController.h"
#import "IALHeaderView.h"
#import <objc/runtime.h>
#import "../../Common.h"
#import "../../Task.h"

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

-(void)viewDidLoad{
	[super viewDidLoad];

	// tableview background gradient
	MTMaterialView *matView = [objc_getClass("MTMaterialView") materialViewWithRecipe:2 configuration:1 initialWeighting:1];
	[self.tableView addSubview:matView];

	[matView setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[matView.topAnchor constraintEqualToAnchor:self.tableView.topAnchor constant:-30] setActive:YES];
	[[matView.bottomAnchor constraintEqualToAnchor:self.tableView.bottomAnchor] setActive:YES];
	[[matView.leadingAnchor constraintEqualToAnchor:self.tableView.leadingAnchor] setActive:YES];
	[[matView.trailingAnchor constraintEqualToAnchor:self.tableView.trailingAnchor] setActive:YES];
	[[matView.centerXAnchor constraintEqualToAnchor:self.tableView.centerXAnchor] setActive:YES];
	[[matView.centerYAnchor constraintEqualToAnchor:self.tableView.centerYAnchor] setActive:YES];

	[self.tableView setBackgroundView:matView];
	[self.tableView setBackgroundColor:[UIColor clearColor]];
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

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section{
    return (85.5 * hScaleFactor);
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section{
    static NSString *headerIdentifier = @"header";
    IALHeaderView *header = [tableView dequeueReusableHeaderFooterViewWithIdentifier:headerIdentifier];

    if (!header) {
        header = [[IALHeaderView alloc] initWithReuseIdentifier:headerIdentifier];
        [header.import addTarget:self action:@selector(importBackup) forControlEvents:UIControlEventTouchUpInside];
    }

    return header;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
	static NSString *cellIdentifier = @"cell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

	if(!cell){
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];

		[cell setBackgroundColor:[UIColor clearColor]];
		[cell.textLabel setText:_backups[indexPath.row]];
		[cell.textLabel setFont:[UIFont systemFontOfSize:[UIFont labelFontSize] weight:UIFontWeightBold]];
		[cell.detailTextLabel setText:_backups[indexPath.row]];
		[cell.detailTextLabel setTextColor:[UIColor systemGrayColor]];

		UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:30];
		[cell.imageView setImage:[UIImage systemImageNamed:@"folder.fill" withConfiguration:config]];
		[cell.imageView setTintColor:[UIColor colorWithHue:0.6 saturation:(0.5 + (arc4random_uniform(128) / 255.0))
                                              brightness:(0.5 + (arc4random_uniform(128) / 255.0)) alpha:1.0]];

		[cell setSeparatorInset:UIEdgeInsetsZero];
		[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	}

	return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
	// cell height
	return (100 * hScaleFactor);
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
	AudioServicesPlaySystemSound(1520); // haptic feedback
    NSString *backupName = [tableView cellForRowAtIndexPath:indexPath].textLabel.text;
    [self confirmRestoreFromBackup:backupName];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    // export backup
    NSString *backupName = [tableView cellForRowAtIndexPath:indexPath].textLabel.text;

    // Note: to export a local file, need to use an NSURL
    NSURL *fileURL = [NSURL fileURLWithPath:[backupDir stringByAppendingString:backupName]];

    UIContextualAction *action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"Export" handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
		AudioServicesPlaySystemSound(1520);
        UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
        [activityViewController setModalTransitionStyle:UIModalTransitionStyleCoverVertical];
        [activityViewController.popoverPresentationController setSourceView:tableView];
        [activityViewController.popoverPresentationController setSourceRect:CGRectMake(0, 0, kWidth, (kHeight/2))];
        [self presentViewController:activityViewController animated:YES completion:nil];
        completionHandler(YES);
    }];
    [action setImage:[UIImage systemImageNamed:@"square.and.arrow.up"]];
    [action setBackgroundColor:[UIColor systemBlueColor]];

    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    return [UISwipeActionsConfiguration configurationWithActions:@[action]];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    // delete backup
    NSString *backupName = [tableView cellForRowAtIndexPath:indexPath].textLabel.text;
    NSString *filePath = [backupDir stringByAppendingPathComponent:backupName];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    UIContextualAction *action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"Delete" handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
		AudioServicesPlaySystemSound(1520);
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
                completionHandler(NO);
            }
			[tableView beginUpdates];
			[self refreshTable];
			[tableView endUpdates];
			completionHandler(YES);
        }
		else {
            NSString *msg = [NSString stringWithFormat:localize(@"%@ cannot be deleted?!"), filePath];
            [self displayErrorWithMessage:msg];
            completionHandler(NO);
        }
    }];
    [action setImage:[UIImage systemImageNamed:@"trash"]];

    return [UISwipeActionsConfiguration configurationWithActions:@[action]];
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
	#pragma clang diagnostic push
	#pragma clang diagnostic ignored "-Wunguarded-availability-new"
	#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"14")){
			importer = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeGZIP] asCopy:YES];
		}
		else{
			importer = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"org.gnu.gnu-zip-archive"] inMode:UIDocumentPickerModeImport];
		}
	#pragma clang diagnostic pop
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

-(void)confirmRestoreFromBackup:(NSString *)backup{
	// get confirmation before proceeding
	UIAlertController *alert = [UIAlertController
								alertControllerWithTitle:@"IAmLazy"
								message:[NSString stringWithFormat:localize(@"Are you sure that you want to restore from %@?"), backup]
								preferredStyle:UIAlertControllerStyleActionSheet];

	UIAlertAction *yes = [UIAlertAction
							actionWithTitle:localize(@"Yes")
							style:UIAlertActionStyleDefault
							handler:^(UIAlertAction *action){
								if([backup hasSuffix:@"u.tar.gz"]){
									// get *extra* confirmation before proceeding
									UIAlertController *subalert = [UIAlertController
																alertControllerWithTitle:localize(@"Please note:")
																message:[[localize(@"You have chosen to restore from a developer backup. This backup includes bootstrap packages.")
																			stringByAppendingString:@"\n\n"]
																			stringByAppendingString:localize(@"Please confirm that you understand this and still wish to proceed with the restore")]
																preferredStyle:UIAlertControllerStyleActionSheet];

									UIAlertAction *subyes = [UIAlertAction
															actionWithTitle:localize(@"Confirm")
															style:UIAlertActionStyleDestructive
															handler:^(UIAlertAction *action){
																[self restoreFromBackup:backup];
															}];

									UIAlertAction *subno = [UIAlertAction
															actionWithTitle:localize(@"Cancel")
															style:UIAlertActionStyleDefault
															handler:^(UIAlertAction *action){
																[self dismissViewControllerAnimated:YES completion:nil];
															}];

									[subalert addAction:subyes];
									[subalert addAction:subno];

									[[subalert popoverPresentationController] setSourceView:self.view];

									[self presentViewController:subalert animated:YES completion:nil];
								}
								else{
									[self restoreFromBackup:backup];
								}
							}];

	UIAlertAction *no = [UIAlertAction
							actionWithTitle:localize(@"No")
							style:UIAlertActionStyleDefault
							handler:^(UIAlertAction *action){
								[self dismissViewControllerAnimated:YES completion:nil];
							}];

	[alert addAction:yes];
	[alert addAction:no];

	[[alert popoverPresentationController] setSourceView:self.view];

	[self presentViewController:alert animated:YES completion:nil];
}

-(void)restoreFromBackup:(NSString *)backup{
	[self presentViewController:[[IALProgressViewController alloc] initWithPurpose:1 withFilter:nil] animated:YES completion:nil];

	UIApplication *app = [UIApplication sharedApplication];
	[app setIdleTimerDisabled:YES]; // disable idle timer (screen dim + lock)

	[_manager restoreFromBackup:backup withCompletion:^(BOOL completed){
		dispatch_async(dispatch_get_main_queue(), ^(void){
			[app setIdleTimerDisabled:NO]; // re-enable idle timer regardless of completion status
			if(completed){
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
					[self dismissViewControllerAnimated:YES completion:^{
						[self popPostRestore];
					}];
				});
			}
		});
	}];
}


#pragma mark Popups

-(void)popPostRestore{
	AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);

	UIAlertController *alert = [UIAlertController
								alertControllerWithTitle:@"IAmLazy"
								message:localize(@"Choose a post-restore command:")
								preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *respring = [UIAlertAction
								actionWithTitle:@"Respring"
								style:UIAlertActionStyleDefault
								handler:^(UIAlertAction *action){
									const char *args[] = {
										ROOT_PATH("/usr/bin/sbreload"),
										NULL
									};
									task(args);
								}];

	UIAlertAction *uicache = [UIAlertAction
								actionWithTitle:@"UICache & Respring"
								style:UIAlertActionStyleDefault
								handler:^(UIAlertAction *action){
									const char *args[] = {
										ROOT_PATH("/usr/bin/uicache"),
										"-a",
										"-r",
										NULL
									};
									task(args);
								}];

	UIAlertAction *none = [UIAlertAction
							actionWithTitle:localize(@"None")
							style:UIAlertActionStyleDefault
							handler:^(UIAlertAction *action){
								[self dismissViewControllerAnimated:YES completion:nil];
							}];

	[alert addAction:respring];
	[alert addAction:uicache];
	[alert addAction:none];

 	[self presentViewController:alert animated:YES completion:nil];
}

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
