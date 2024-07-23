//
//	IALBackupsViewController.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import <UniformTypeIdentifiers/UTCoreTypes.h>
#import <AudioToolbox/AudioServices.h>
#import "IALProgressViewController.h"
#import "IALBackupsViewController.h"
#import "IALRootViewController.h"
#import <IALGeneralManager.h>
#import "IALHeaderView.h"
#import <objc/runtime.h>
#import <Common.h>
#import <Task.h>

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending) // https://stackoverflow.com/a/5337804

@implementation IALBackupsViewController

#pragma mark Setup

-(instancetype)init{
	self = [super initWithStyle:UITableViewStyleGrouped];

	if(self){
		_manager = [IALGeneralManager sharedManager];
		_rootVC = (IALRootViewController *)_manager.rootVC;
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
    return (85 * hScaleFactor);
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section{
    static NSString *headerIdentifier = @"header";
    IALHeaderView *header = [tableView dequeueReusableHeaderFooterViewWithIdentifier:headerIdentifier];

    if (!header) {
        NSString *subtitle = localize(@"Swipe or tap desired backup");
        UIImage *button = [UIImage systemImageNamed:@"plus.circle.fill"];
        header = [[IALHeaderView alloc] initWithReuseIdentifier:headerIdentifier subtitle:subtitle andButtonImage:button];
        [header.import addTarget:self action:@selector(importBackup) forControlEvents:UIControlEventTouchUpInside];
    }

    return header;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
	static NSString *cellIdentifier = @"cell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

	if(!cell){
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
		[cell setSeparatorInset:UIEdgeInsetsZero];
		[cell setBackgroundColor:[UIColor clearColor]];
		[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
		// [cell setSelectionStyle:UITableViewCellSelectionStyleNone]; // TODO: maybe?

		[cell.textLabel setFont:[UIFont systemFontOfSize:[UIFont labelFontSize] weight:UIFontWeightBold]];

		UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:25];
		[cell.imageView setImage:[UIImage systemImageNamed:@"folder.fill" withConfiguration:config]];
	}

	NSString *backup = _backups[indexPath.row];
	[cell.textLabel setText:backup];

	NSString *type = [backup hasSuffix:@"u.tar.gz"] ? localize(@"Developer") : localize(@"Standard");
	[cell.detailTextLabel setText:[NSString stringWithFormat:localize(@"Type: %@"), type]];

	UIColor *typeColor = [backup containsString:@"u"] ? [_rootVC IALBlue] : [_rootVC IALYellow];
	[cell.textLabel setTextColor:typeColor];
	[cell.imageView setTintColor:typeColor];

	return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
	// cell height
	return (75 * hScaleFactor);
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
    NSURL *fileURL = [NSURL fileURLWithPath:[backupDir stringByAppendingPathComponent:backupName]];

    UIContextualAction *action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:localize(@"Export") handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
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

    UIContextualAction *action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:localize(@"Delete") handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
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
																[_rootVC dismissViewControllerAnimated:YES completion:^{
																	[_rootVC restoreFromBackup:backup];
																}];
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
									[_rootVC dismissViewControllerAnimated:YES completion:^{
										[_rootVC restoreFromBackup:backup];
									}];
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
