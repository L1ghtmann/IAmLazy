//
//	IALRootViewController.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import <SafariServices/SFSafariViewController.h>
#import "../Managers/IALGeneralManager.h"
#import <AudioToolbox/AudioToolbox.h>
#import "IALProgressViewController.h"
#import "IALBackupsViewController.h"
#import "IALRootViewController.h"
#import "../Common.h"
#import <NSTask.h>

@implementation IALRootViewController

#pragma mark Setup

-(instancetype)init{
	self = [super init];

	if(self){
		_manager = [IALGeneralManager sharedManager];
		[_manager setRootVC:self];
	}

	return self;
}

-(void)loadView{
	[super loadView];

	[self makeMainScreen];
	[self makeControlPanel];
}

-(void)makeMainScreen{
	// Setup main background
	// TODO: do this with constraints(?)
	_mainView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kWidth, ((kHeight/4) * 3))];
	[self.view addSubview:_mainView];

	CAGradientLayer *gradient = [CAGradientLayer layer];
	[gradient setFrame:_mainView.bounds];
	[gradient setColors:@[(id)[self IALBlue].CGColor,
						(id)[UIColor colorWithRed:252.0f/255.0f green:251.0f/255.0f blue:216.0f/255.0f alpha:1.0f].CGColor]];
	[_mainView.layer insertSublayer:gradient atIndex:0];

	// Setup IAL icon
	UIImageView *imgView = [[UIImageView alloc] init];
	[_mainView addSubview:imgView];

	[imgView setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[imgView.centerXAnchor constraintEqualToAnchor:_mainView.centerXAnchor] setActive:YES];
	[[imgView.centerYAnchor constraintEqualToAnchor:_mainView.centerYAnchor constant:-85] setActive:YES];

	[imgView setImage:[UIImage imageNamed:@"Assets/AppIcon250-Clear"]];
	[imgView setUserInteractionEnabled:NO];

	// Setup primary function buttons
	// Backup
	UIButton *backup = [UIButton buttonWithType:UIButtonTypeCustom];
	[_mainView addSubview:backup];

	[backup setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[backup.widthAnchor constraintEqualToConstant:((kWidth/3) * 2)] setActive:YES];
	[[backup.heightAnchor constraintEqualToConstant:55] setActive:YES];
	[[backup.centerXAnchor constraintEqualToAnchor:_mainView.centerXAnchor] setActive:YES];
	[[backup.centerYAnchor constraintEqualToAnchor:_mainView.centerYAnchor constant:75] setActive:YES];

	[backup setTag:0];
	[backup setClipsToBounds:YES];
	[backup.layer setCornerRadius:10];
	[backup setTitle:@"Backup" forState:UIControlStateNormal];
	[backup.titleLabel setFont:[UIFont systemFontOfSize:[UIFont labelFontSize] weight:0.56]];
	[backup setTintColor:[self IALBlue]];
	[backup setTitleColor:[self IALBlue] forState:UIControlStateNormal];
	if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [backup setBackgroundColor:[UIColor systemGray6Color]];
	else [backup setBackgroundColor:[UIColor whiteColor]];
	[backup setAdjustsImageWhenHighlighted:NO];
	[backup setImage:[UIImage systemImageNamed:@"plus.app"] forState:UIControlStateNormal];
	[backup addTarget:self action:@selector(mainButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

	// Restore
	UIButton *restore = [UIButton buttonWithType:UIButtonTypeCustom];
	[_mainView addSubview:restore];

	[restore setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[restore.widthAnchor constraintEqualToConstant:((kWidth/3) * 2)] setActive:YES];
	[[restore.heightAnchor constraintEqualToConstant:55] setActive:YES];
	[[restore.centerXAnchor constraintEqualToAnchor:_mainView.centerXAnchor] setActive:YES];
	[[restore.centerYAnchor constraintEqualToAnchor:_mainView.centerYAnchor constant:150] setActive:YES];

	[restore setTag:1];
	[restore setClipsToBounds:YES];
	[restore.layer setCornerRadius:10];
	[restore setTitle:@"Restore" forState:UIControlStateNormal];
	[restore.titleLabel setFont:[UIFont systemFontOfSize:[UIFont labelFontSize] weight:0.56]];
	[restore setTintColor:[self IALBlue]];
	[restore setTitleColor:[self IALBlue] forState:UIControlStateNormal];
	if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [restore setBackgroundColor:[UIColor systemGray6Color]];
	else [restore setBackgroundColor:[UIColor whiteColor]];
	[restore setAdjustsImageWhenHighlighted:NO];
	[restore setImage:[UIImage systemImageNamed:@"arrow.counterclockwise.circle"] forState:UIControlStateNormal];
	[restore addTarget:self action:@selector(mainButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
}

-(void)makeControlPanel{
	// Setup control panel background
	_controlPanelView = [[UIView alloc] init];
	[self.view addSubview:_controlPanelView];

	[_controlPanelView setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[_controlPanelView.widthAnchor constraintEqualToConstant:kWidth] setActive:YES];
	[[_controlPanelView.heightAnchor constraintEqualToConstant:kHeight/4] setActive:YES];
	[[_controlPanelView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor] setActive:YES];

	if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [_controlPanelView setBackgroundColor:[UIColor colorWithRed:16.0f/255.0f green:16.0f/255.0f blue:16.0f/255.0f alpha:1.0f]];
	else [_controlPanelView setBackgroundColor:[UIColor colorWithRed:247.0f/255.0f green:249.0f/255.0f blue:250.0f/255.0f alpha:1.0f]];

	[self makePanelOne];
	[self makePanelTwo];
	_controlPanelState = 0;
}

-(void)makePanelOne{
	// Create container for buttons
	_panelOneContainer = [[UIView alloc] init];
	[_panelOneContainer setBackgroundColor:[UIColor clearColor]];
	[_controlPanelView addSubview:_panelOneContainer];

	[_panelOneContainer setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[_panelOneContainer.topAnchor constraintEqualToAnchor:_controlPanelView.topAnchor] setActive:YES];
	[[_panelOneContainer.bottomAnchor constraintEqualToAnchor:_controlPanelView.bottomAnchor] setActive:YES];
	[[_panelOneContainer.leadingAnchor constraintEqualToAnchor:_controlPanelView.leadingAnchor] setActive:YES];
	[[_panelOneContainer.trailingAnchor constraintEqualToAnchor:_controlPanelView.trailingAnchor] setActive:YES];

	// Src
	UIButton *src = [UIButton buttonWithType:UIButtonTypeSystem];
	[_panelOneContainer addSubview:src];

	[src setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[src.widthAnchor constraintEqualToConstant:(kWidth/2)] setActive:YES];
	[[src.heightAnchor constraintEqualToConstant:45] setActive:YES];
	[[src.leadingAnchor constraintEqualToAnchor:_panelOneContainer.leadingAnchor constant:25] setActive:YES];
	[[src.bottomAnchor constraintEqualToAnchor:_panelOneContainer.bottomAnchor constant:-35] setActive:YES];

	[src setTag:0];
	[src setClipsToBounds:YES];
	[src.layer setCornerRadius:10];
	[src setTitle:@"Source" forState:UIControlStateNormal];
	[src.titleLabel setFont:[UIFont systemFontOfSize:[UIFont labelFontSize] weight:0.40]];
	[src setTintColor:[self IALBlue]];
	if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [src setBackgroundColor:[UIColor systemGray6Color]];
	else [src setBackgroundColor:[UIColor whiteColor]];
	[src addTarget:self action:@selector(subButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

	// Backups
	UIButton *backups = [UIButton buttonWithType:UIButtonTypeSystem];
	[_panelOneContainer addSubview:backups];

	[backups setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[backups.widthAnchor constraintEqualToConstant:(kWidth/2)] setActive:YES];
	[[backups.heightAnchor constraintEqualToConstant:45] setActive:YES];
	[[backups.trailingAnchor constraintEqualToAnchor:_panelOneContainer.trailingAnchor constant:-25] setActive:YES];
	[[backups.bottomAnchor constraintEqualToAnchor:_panelOneContainer.bottomAnchor constant:-35] setActive:YES];

	[backups setTag:1];
	[backups setClipsToBounds:YES];
	[backups.layer setCornerRadius:10];
	[backups setTitle:@"Backups" forState:UIControlStateNormal];
	[backups.titleLabel setFont:[UIFont systemFontOfSize:[UIFont labelFontSize] weight:0.40]];
	[backups setTintColor:[self IALBlue]];
	if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [backups setBackgroundColor:[UIColor systemGray6Color]];
	else [backups setBackgroundColor:[UIColor whiteColor]];
	[backups addTarget:self action:@selector(subButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

	// Me
	UIButton *me = [UIButton buttonWithType:UIButtonTypeSystem];
	[_panelOneContainer addSubview:me];

	[me setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[me.widthAnchor constraintEqualToConstant:(kWidth - 50)] setActive:YES];
	[[me.heightAnchor constraintEqualToConstant:45] setActive:YES];
	[[me.leadingAnchor constraintEqualToAnchor:_panelOneContainer.leadingAnchor constant:25] setActive:YES];
	[[me.topAnchor constraintEqualToAnchor:_panelOneContainer.topAnchor constant:30] setActive:YES];

	[me setTag:2];
	[me setClipsToBounds:YES];
	[me.layer setCornerRadius:10];
	[me setTitle:@"Created by Lightmann | v2.0.0" forState:UIControlStateNormal];
	[me.titleLabel setFont:[UIFont systemFontOfSize:[UIFont labelFontSize] weight:0.40]];
	[me setTintColor:[self IALBlue]];
	if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [me setBackgroundColor:[UIColor systemGray6Color]];
	else [me setBackgroundColor:[UIColor whiteColor]];
}

-(void)makePanelTwo{
	// Create container for buttons
	_panelTwoContainer = [[UIView alloc] init];
	[_panelTwoContainer setBackgroundColor:[UIColor clearColor]];
	[_controlPanelView addSubview:_panelTwoContainer];

	[_panelTwoContainer setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[_panelTwoContainer.topAnchor constraintEqualToAnchor:_controlPanelView.topAnchor] setActive:YES];
	[[_panelTwoContainer.bottomAnchor constraintEqualToAnchor:_controlPanelView.bottomAnchor] setActive:YES];
	[[_panelTwoContainer.leadingAnchor constraintEqualToAnchor:_controlPanelView.leadingAnchor] setActive:YES];
	[[_panelTwoContainer.trailingAnchor constraintEqualToAnchor:_controlPanelView.trailingAnchor] setActive:YES];

	// Hide until needed
	[_panelTwoContainer setAlpha:0];

	// Go
	UIButton *go = [UIButton buttonWithType:UIButtonTypeSystem];
	[_panelTwoContainer addSubview:go];

	[go setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[go.widthAnchor constraintEqualToConstant:(kWidth - 50)] setActive:YES];
	[[go.heightAnchor constraintEqualToConstant:45] setActive:YES];
	[[go.leadingAnchor constraintEqualToAnchor:_panelTwoContainer.leadingAnchor constant:25] setActive:YES];
	[[go.topAnchor constraintEqualToAnchor:_panelTwoContainer.topAnchor constant:30] setActive:YES];

	[go setClipsToBounds:YES];
	[go.layer setCornerRadius:10];
	[go setTitle:@"Go" forState:UIControlStateNormal];
	[go.titleLabel setFont:[UIFont systemFontOfSize:[UIFont labelFontSize] weight:0.40]];
	[go setTintColor:[UIColor systemGreenColor]];
	if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [go setBackgroundColor:[UIColor systemGray6Color]];
	else [go setBackgroundColor:[UIColor whiteColor]];
	[go addTarget:self action:@selector(startWork) forControlEvents:UIControlEventTouchUpInside];

	// Config switch
	_configSwitch = [[UISegmentedControl alloc] initWithItems:nil];
	[_panelTwoContainer addSubview:_configSwitch];

	[_configSwitch setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[_configSwitch.widthAnchor constraintEqualToConstant:(kWidth - 50)] setActive:YES];
	[[_configSwitch.heightAnchor constraintEqualToConstant:45] setActive:YES];
	[[_configSwitch.leadingAnchor constraintEqualToAnchor:_panelTwoContainer.leadingAnchor constant:25] setActive:YES];
	[[_configSwitch.bottomAnchor constraintEqualToAnchor:_panelTwoContainer.bottomAnchor constant:-35] setActive:YES];

	[_configSwitch addTarget:self action:@selector(configSegmentChanged:) forControlEvents:UIControlEventValueChanged];
}

-(void)mainButtonTapped:(UIButton *)sender{
	AudioServicesPlaySystemSound(1520); // haptic feedback

	// reset button states if
	// control panel is at state 0
	if(_controlPanelState == 0){
		[sender setSelected:NO];
	}

	// not selected already
	if(!sender.selected){
		[UIView animateWithDuration:0.5 animations:^(void) {
			[_panelOneContainer setAlpha:0];
			[_panelTwoContainer setAlpha:1];
		}];
	}

	// if control panel is at state 0 or if other main button was selected
	if(_controlPanelState == 0 || (sender.tag + 1) != _controlPanelState){
		switch(sender.tag){
			case 0:
				[_configSwitch removeAllSegments];
				[_configSwitch insertSegmentWithTitle:@"Standard" atIndex:0 animated:NO];
				[_configSwitch insertSegmentWithTitle:@"Developer" atIndex:1 animated:NO];
				[_configSwitch setSelectedSegmentIndex:0];
				_controlPanelState = 1;
				break;
			case 1:
				[_configSwitch removeAllSegments];
				[_configSwitch insertSegmentWithTitle:@"Latest" atIndex:0 animated:NO];
				[_configSwitch insertSegmentWithTitle:@"Specific" atIndex:1 animated:NO];
				[_configSwitch setSelectedSegmentIndex:0];
				_controlPanelState = 2;
				break;
		}
	}
	// if control pannel state is not 0 and/or tapped already selected button
	else{
		[UIView animateWithDuration:0.5 animations:^(void) {
			[_panelOneContainer setAlpha:1];
			[_panelTwoContainer setAlpha:0];
			_controlPanelState = 0;
		}];
	}

	// change state
	[sender setSelected:!sender.selected];
}

-(void)subButtonTapped:(UIButton *)sender{
	AudioServicesPlaySystemSound(1520); // haptic feedback

	switch(sender.tag){
		case 0: {
			NSURL *url = [NSURL URLWithString:@"https://github.com/L1ghtmann/IAmLazy"];
			SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:url];
			[self presentViewController:safariViewController animated:YES completion:nil];
			break;
		}
		case 1: {
			IALBackupsViewController *backupsViewController = [[IALBackupsViewController alloc] init];
			[self presentViewController:backupsViewController animated:YES completion:nil];
			break;
		}
	}
}

-(void)startWork{
	AudioServicesPlaySystemSound(1520); // haptic feedback

	switch(_controlPanelState){
		case 1: // backup
			// standard = 0 | developer = 1
			[self selectedBackupWithFilter:!_configSwitch.selectedSegmentIndex];
			break;
		case 2: // restore
			// latest = 0 | specific = 1
			[self restoreLatestBackup:!_configSwitch.selectedSegmentIndex];
			break;
	}

	[UIView animateWithDuration:0.5 animations:^(void) {
		[_panelOneContainer setAlpha:1];
		[_panelTwoContainer setAlpha:0];
		_controlPanelState = 0;
	}];
}

-(void)configSegmentChanged:(UISegmentedControl *)sender{
	AudioServicesPlaySystemSound(1520); // haptic feedback
}

#pragma mark Functionality

-(void)selectedBackupWithFilter:(BOOL)filter{
	UIAlertController *alert = [UIAlertController
								alertControllerWithTitle:@"IAmLazy"
								message:@"Please confirm that you have adequate free storage before proceeding:"
								preferredStyle:UIAlertControllerStyleActionSheet];

	UIAlertAction *confirm = [UIAlertAction
								actionWithTitle:@"Confirm"
								style:UIAlertActionStyleDefault
								handler:^(UIAlertAction *action){
									[self makeBackupWithFilter:filter];
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

-(void)makeBackupWithFilter:(BOOL)filter{
	[self presentViewController:[[IALProgressViewController alloc] initWithPurpose:0 withFilter:filter] animated:YES completion:nil];

	UIApplication *app = [UIApplication sharedApplication];
	[app setIdleTimerDisabled:YES]; // disable idle timer (screen dim + lock)
	_startTime = [NSDate date];

	[_manager makeBackupWithFilter:filter];

	_endTime = [NSDate date];
	[app setIdleTimerDisabled:NO]; // reenable idle timer

	if(![_manager encounteredError]){
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
			[self dismissViewControllerAnimated:YES completion:^{
				[self popPostBackup];
			}];
		});
	}
}

-(NSString *)getDuration{
	NSTimeInterval duration = [_endTime timeIntervalSinceDate:_startTime];
	return [NSString stringWithFormat:@"%.02f", duration];
}

-(void)restoreLatestBackup:(BOOL)latest{
	NSArray *backups = [_manager getBackups];
	if(![backups count]){
		return;
	}

	// get desired backups
	NSString *extension = @"tar.gz";
	NSPredicate *thePredicate = [NSPredicate predicateWithFormat:@"SELF ENDSWITH %@", extension];
	NSArray *desiredBackups = [backups filteredArrayUsingPredicate:thePredicate];

	if(latest){
		// get latest backup
		NSString *backupName = [desiredBackups firstObject];

		// get confirmation before proceeding
		UIAlertController *alert = [UIAlertController
									alertControllerWithTitle:@"IAmLazy"
									message:[NSString stringWithFormat:@"Are you sure that you want to restore from %@?", backupName]
									preferredStyle:UIAlertControllerStyleActionSheet];

		UIAlertAction *yes = [UIAlertAction
								actionWithTitle:@"Yes"
								style:UIAlertActionStyleDefault
								handler:^(UIAlertAction *action){
									[self restoreFromBackup:backupName];
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
		// post list of available backups
		UIAlertController *alert = [UIAlertController
									alertControllerWithTitle:@"IAmLazy"
									message:@"Choose the backup you'd like to restore from:"
									preferredStyle:UIAlertControllerStyleAlert];

		// make each available backup its own action
		for(NSString *backup in desiredBackups){
			// get confirmation before proceeding
			UIAlertAction *action = [UIAlertAction
										actionWithTitle:backup
										style:UIAlertActionStyleDefault
										handler:^(UIAlertAction *action){
											UIAlertController *subalert = [UIAlertController
																			alertControllerWithTitle:@"IAmLazy"
																			message:[NSString stringWithFormat:@"Are you sure that you want to restore from %@?", backup]
																			preferredStyle:UIAlertControllerStyleActionSheet];

											UIAlertAction *yes = [UIAlertAction
																	actionWithTitle:@"Yes"
																	style:UIAlertActionStyleDefault
																	handler:^(UIAlertAction *action){
																		[self restoreFromBackup:backup];
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

-(void)restoreFromBackup:(NSString *)backupName{
	[self presentViewController:[[IALProgressViewController alloc] initWithPurpose:1 withFilter:nil] animated:YES completion:nil];

	UIApplication *app = [UIApplication sharedApplication];
	[app setIdleTimerDisabled:YES]; // disable idle timer (screen dim + lock)

	[_manager restoreFromBackup:backupName];

	[app setIdleTimerDisabled:NO]; // reenable idle timer

	if(![_manager encounteredError]){
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
			[self dismissViewControllerAnimated:YES completion:^{
				[self popPostRestore];
			}];
		});
	}
}

#pragma mark Popups

-(void)popPostBackup{
	AudioServicesPlaySystemSound(4095); // vibration

	UIAlertController *alert = [UIAlertController
								alertControllerWithTitle:@"IAmLazy Notice:"
								message:[NSString stringWithFormat:@"Tweak backup completed successfully in %@ seconds!\n\nYour backup can be found in\n%@", [self getDuration], backupDir]
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

-(void)popPostRestore{
	AudioServicesPlaySystemSound(4095); // vibration

	UIAlertController *alert = [UIAlertController
								alertControllerWithTitle:@"IAmLazy"
								message:@"Choose a post-restore command:"
								preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *respring = [UIAlertAction
								actionWithTitle:@"Respring"
								style:UIAlertActionStyleDefault
								handler:^(UIAlertAction *action){
									NSTask *task = [[NSTask alloc] init];
									[task setLaunchPath:@"/usr/bin/sbreload"];
									[task launch];
								}];

	UIAlertAction *uicache = [UIAlertAction
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

	[alert addAction:respring];
	[alert addAction:uicache];
	[alert addAction:none];

 	[self presentViewController:alert animated:YES completion:nil];
}

-(UIColor *)IALBlue{
	return [UIColor colorWithRed:82.0f/255.0f green:102.0f/255.0f blue:142.0f/255.0f alpha:1.0f];
}

@end
