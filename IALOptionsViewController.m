//
//	IALOptionsViewController.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import <AudioToolbox/AudioToolbox.h>
#import "IALOptionsViewController.h"
#import "IALTableViewCell.h"
#import "IALManager.h"
#import "Common.h"

@implementation IALOptionsViewController

-(void)loadView{
	[super loadView];

	[self setTitle:@"Options"];

	UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"xmark"] style:UIBarButtonItemStylePlain target:self action:@selector(returnToMain)];
	[self.navigationItem setLeftBarButtonItem:backButton];
}

-(void)returnToMain{
	[self dismissViewControllerAnimated:YES completion:nil];
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
		function = @"export";
		functionDescriptor = @"Export A Backup";
	}
	else if(indexPath.row == 1){
		function = @"delete";
		functionDescriptor = @"Delete A Backup";
	}
	else{
		function = @"";
		functionDescriptor = @"Made By Lightmann";
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
	// last cell ("made by" cell)
	else{
		return cellHeight/3;
	}
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
	AudioServicesPlaySystemSound(1520); // haptic feedback

	if(indexPath.row == 0){ // export cell
		[self exportBackup];
	}
	else if(indexPath.row == 1){ // delete cell
		[self deleteBackup];
	}
	else{
	}

	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark Secondary Options

-(void)exportBackup{
	// post list of available backups
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:@"Choose the backup you'd like to export:" preferredStyle:UIAlertControllerStyleAlert];

	// get backup filenames
	NSArray *backupNames = [[IALManager sharedInstance] getBackups];

	// make each available backup its own action
	for(int i = 0; i < [backupNames count]; i++){
		NSString *backupName = backupNames[i];
		UIAlertAction *action = [UIAlertAction actionWithTitle:backupName style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
			NSString *localPath = [NSString stringWithFormat:@"file:/%@%@", backupDir, backupName];
			NSURL *fileURL = [NSURL URLWithString:localPath]; // to actually export the file, needs to be an NSURL

			UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
			[activityViewController setModalTransitionStyle:UIModalTransitionStyleCoverVertical];

			[self presentViewController:activityViewController animated:YES completion:nil];
		}];

		[alert addAction:action];
	}

	UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
		[alert dismissViewControllerAnimated:YES completion:nil]; // since this is a presented vc, we have to tell the alert to dismiss itself
	}];

	[alert addAction:cancel];

	[self presentViewController:alert animated:YES completion:nil];
}

-(void)deleteBackup{
	// post list of available backups
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:@"Choose the backup you'd like to delete:" preferredStyle:UIAlertControllerStyleAlert];

	// get backup filenames
	NSArray *backupNames = [[IALManager sharedInstance] getBackups];

	// make each available backup its own action
	for(int i = 0; i < [backupNames count]; i++){
		NSString *backupName = backupNames[i];
		UIAlertAction *action = [UIAlertAction actionWithTitle:backupName style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
			UIAlertController *subalert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:[NSString stringWithFormat:@"Are you sure that you want to delete %@?", backupName] preferredStyle:UIAlertControllerStyleAlert];

			UIAlertAction *yes = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
				// remove backup
				NSString *filePath = [NSString stringWithFormat:@"%@%@", backupDir, backupName];
				if([[NSFileManager defaultManager] isDeletableFileAtPath:filePath]){
					NSError *error = NULL;
					BOOL success = [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
					 if(success){
						NSString *text = [NSString stringWithFormat:@"Successfully deleted %@!", backupName];

						UIAlertController *subsubalert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:text preferredStyle:UIAlertControllerStyleAlert];
						UIAlertAction *okay = [UIAlertAction actionWithTitle:@"Okay" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
							[subsubalert dismissViewControllerAnimated:YES completion:nil];
						}];
						[subsubalert addAction:okay];
						[self presentViewController:subsubalert animated:YES completion:nil];
					}
					else{
						NSString *text = [NSString stringWithFormat:@"An error occured and %@ was not deleted! \n\nError: %@", backupName, error.localizedDescription];

						UIAlertController *subsubalert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:text preferredStyle:UIAlertControllerStyleAlert];
						UIAlertAction *okay = [UIAlertAction actionWithTitle:@"Okay" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
							[subsubalert dismissViewControllerAnimated:YES completion:nil];
						}];
						[subsubalert addAction:okay];
						[self presentViewController:subsubalert animated:YES completion:nil];

						NSLog(@"[IAmLazyLog] %@", text);
					}
				}
				else{
					NSString *text = [NSString stringWithFormat:@"%@ cannot be deleted?!", filePath];

					UIAlertController *subsubalert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:text preferredStyle:UIAlertControllerStyleAlert];
					UIAlertAction *okay = [UIAlertAction actionWithTitle:@"Okay" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
						[subsubalert dismissViewControllerAnimated:YES completion:nil];
					}];
					[subsubalert addAction:okay];
					[self presentViewController:subsubalert animated:YES completion:nil];

					NSLog(@"[IAmLazyLog] %@", text);
				}
			}];

			UIAlertAction *no = [UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
				[subalert dismissViewControllerAnimated:YES completion:nil];
			}];

			[subalert addAction:yes];
			[subalert addAction:no];

			[self presentViewController:subalert animated:YES completion:nil];
		}];

		[alert addAction:action];
	}

	UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
		[alert dismissViewControllerAnimated:YES completion:nil];
	}];

	[alert addAction:cancel];

	[self presentViewController:alert animated:YES completion:nil];
}

@end
