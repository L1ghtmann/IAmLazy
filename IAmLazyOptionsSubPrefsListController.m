#import "IAmLazyOptionsSubPrefsListController.h"
#import "IAmLazyManager.h"
#import "Common.h"

// Lightmann
// Made during covid
// IAmLazy

@implementation IAmLazyOptionsSubPrefsListController

- (NSArray *)specifiers {
    return _specifiers;
}

- (void)loadFromSpecifier:(PSSpecifier *)specifier {
    NSString *sub = [specifier propertyForKey:@"IAmLazySub"];
    NSString *title = [specifier name];

    _specifiers = [self loadSpecifiersFromPlistName:sub target:self];

    [self setTitle:title];
    [self.navigationItem setTitle:title];
}

- (void)setSpecifier:(PSSpecifier *)specifier {
	[self loadFromSpecifier:specifier];
	[super setSpecifier:specifier];
}

-(void)exportBackup:(id)sender{
    // post list of available backups
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:@"Choose the backup you'd like to export:" preferredStyle:UIAlertControllerStyleAlert];

    // get backup filenames
    NSArray *backupNames = [[IAmLazyManager sharedInstance] getBackups];

    // make each available backup its own action
    for(int i = 0; i < [backupNames count]; i++){
        NSString *backupName = backupNames[i];
        UIAlertAction *action = [UIAlertAction actionWithTitle:backupName style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            NSString *localPath = [NSString stringWithFormat:@"file://%@%@", backupDir, backupName];
            NSURL *fileURL = [NSURL URLWithString:localPath]; // to actually export the file, needs to be an NSURL

            UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
            activityViewController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;

            [self presentViewController:activityViewController animated:YES completion:nil];
        }];

        [alert addAction:action];
    }

    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }];

    [alert addAction:cancel];

	[self presentViewController:alert animated:YES completion:nil];
}

-(void)deleteBackup:(id)sender{
    // post list of available backups
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:@"Choose the backup you'd like to delete:" preferredStyle:UIAlertControllerStyleAlert];

    // get backup filenames
    NSArray *backupNames = [[IAmLazyManager sharedInstance] getBackups];

    // make each available backup its own action
    for(int i = 0; i < [backupNames count]; i++){
        NSString *backupName = backupNames[i];
        UIAlertAction *action = [UIAlertAction actionWithTitle:backupName style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            UIAlertController *subalert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:[NSString stringWithFormat:@"Are you sure that you want to delete %@?", backupName] preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction *yes = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                // remove backup
                NSString *filePath = [NSString stringWithFormat:@"%@%@", backupDir, backupName];
                [[NSFileManager defaultManager] removeItemAtPath:filePath error:NULL];

                // if success
                if(![[NSFileManager defaultManager] fileExistsAtPath:filePath]){
                    NSString *text = [NSString stringWithFormat:@"Successfully deleted %@!", backupName];

                    UIAlertController *subsubalert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:text preferredStyle:UIAlertControllerStyleAlert];
                     UIAlertAction *okay = [UIAlertAction actionWithTitle:@"Okay" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                        [self dismissViewControllerAnimated:YES completion:nil];
                    }];
                    [subsubalert addAction:okay];
                    [self presentViewController:subsubalert animated:YES completion:nil];

                    NSLog(@"IAmLazyLog %@", text);
                }
                // if failure
                else{
                    NSString *text = [NSString stringWithFormat:@"An error occured and %@ was not deleted!", backupName];

                    UIAlertController *subsubalert = [UIAlertController alertControllerWithTitle:@"IAmLazy" message:text preferredStyle:UIAlertControllerStyleAlert];
                     UIAlertAction *okay = [UIAlertAction actionWithTitle:@"Okay" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                        [self dismissViewControllerAnimated:YES completion:nil];
                    }];
                    [subsubalert addAction:okay];
                    [self presentViewController:subsubalert animated:YES completion:nil];

                    NSLog(@"IAmLazyLog %@", text);
                }
            }];

            UIAlertAction *no = [UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                [self dismissViewControllerAnimated:YES completion:nil];
            }];

            [subalert addAction:yes];
            [subalert addAction:no];

            [self presentViewController:subalert animated:YES completion:nil];
        }];

        [alert addAction:action];
    }

    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }];

    [alert addAction:cancel];

	[self presentViewController:alert animated:YES completion:nil];
}

- (BOOL)shouldReloadSpecifiersOnResume {
    return NO;
}

@end