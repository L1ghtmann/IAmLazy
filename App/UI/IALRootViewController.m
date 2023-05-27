//
//	IALRootViewController.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "../../Shared/Managers/IALGeneralManager.h"
#import <AudioToolbox/AudioServices.h>
#import "IALProgressViewController.h"
#import "IALCreditsViewController.h"
#import "IALBackupsViewController.h"
#import "IALRootViewController.h"
#import "../../Common.h"
#import "../../Task.h"

@implementation IALRootViewController

#pragma mark Setup

-(instancetype)init{
	self = [super init];

	if(self){
		_manager = [NSClassFromString(@"IALGeneralManager") sharedManager];
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
	// setup main background
	_mainView = [[UIView alloc] init];
	[self.view addSubview:_mainView];

	[_mainView setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[_mainView.topAnchor constraintEqualToAnchor:self.view.topAnchor] setActive:YES];
	[[_mainView.widthAnchor constraintEqualToConstant:kWidth] setActive:YES];
	[[_mainView.heightAnchor constraintEqualToConstant:((kHeight/4) * 3)] setActive:YES];

	// make sure bounds/frame are updated
	// can't use constraints on calayers
	// so need _mainView's bounds to exist
	[_mainView layoutIfNeeded];

	CAGradientLayer *gradient = [CAGradientLayer layer];
	[gradient setFrame:_mainView.bounds];
	[gradient setColors:@[(id)[self IALBlue].CGColor,
						(id)[UIColor colorWithRed:252.0f/255.0f green:251.0f/255.0f blue:216.0f/255.0f alpha:1.0f].CGColor]];
	[_mainView.layer insertSublayer:gradient atIndex:0];

	// setup IAL icon
	UIImageView *imgView = [[UIImageView alloc] init];
	[_mainView addSubview:imgView];

	[imgView setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[imgView.centerXAnchor constraintEqualToAnchor:_mainView.centerXAnchor] setActive:YES];
	[[imgView.centerYAnchor constraintEqualToAnchor:_mainView.centerYAnchor constant:-85] setActive:YES];

	[imgView setImage:[UIImage imageNamed:@"Assets/AppIcon250-Clear"]];
	[imgView setUserInteractionEnabled:NO];

	// setup primary function buttons
	// backup
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
	[backup setTitle:localize(@"Backup") forState:UIControlStateNormal];
	[backup.titleLabel setFont:[UIFont systemFontOfSize:[UIFont labelFontSize] weight:0.56]];
	[backup setTintColor:[self IALBlue]];
	[backup setTitleColor:[self IALBlue] forState:UIControlStateNormal];
	if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [backup setBackgroundColor:[UIColor systemGray6Color]];
	else [backup setBackgroundColor:[UIColor whiteColor]];
	[backup setAdjustsImageWhenHighlighted:NO];
	[backup setImage:[UIImage systemImageNamed:@"plus.app"] forState:UIControlStateNormal];
	[backup addTarget:self action:@selector(mainButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

	// restore
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
	[restore setTitle:localize(@"Restore") forState:UIControlStateNormal];
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
	// setup control panel background
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
	// create container for buttons
	_panelOneContainer = [[UIView alloc] init];
	[_panelOneContainer setBackgroundColor:[UIColor clearColor]];
	[_controlPanelView addSubview:_panelOneContainer];

	[_panelOneContainer setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[_panelOneContainer.topAnchor constraintEqualToAnchor:_controlPanelView.topAnchor] setActive:YES];
	[[_panelOneContainer.bottomAnchor constraintEqualToAnchor:_controlPanelView.bottomAnchor] setActive:YES];
	[[_panelOneContainer.leadingAnchor constraintEqualToAnchor:_controlPanelView.leadingAnchor] setActive:YES];
	[[_panelOneContainer.trailingAnchor constraintEqualToAnchor:_controlPanelView.trailingAnchor] setActive:YES];

	// me
	UIButton *me = [UIButton buttonWithType:UIButtonTypeSystem];
	[_panelOneContainer addSubview:me];

	[me setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[me.widthAnchor constraintEqualToConstant:(kWidth - 50)] setActive:YES];
	[[me.heightAnchor constraintEqualToConstant:45] setActive:YES];
	[[me.centerXAnchor constraintEqualToAnchor:_panelOneContainer.centerXAnchor] setActive:YES];
	[[me.centerYAnchor constraintEqualToAnchor:_panelOneContainer.centerYAnchor constant:-27] setActive:YES];

	[me setTag:2];
	[me setClipsToBounds:YES];
	[me.layer setCornerRadius:10];
	[me setTitle:[localize(@"Created by Lightmann") stringByAppendingString:@" | v2.1.2"] forState:UIControlStateNormal];
	[me.titleLabel setFont:[UIFont systemFontOfSize:[UIFont labelFontSize] weight:0.40]];
	[me setTintColor:[self IALBlue]];
	if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [me setBackgroundColor:[UIColor systemGray6Color]];
	else [me setBackgroundColor:[UIColor whiteColor]];

	// credits
	UIButton *credits = [UIButton buttonWithType:UIButtonTypeSystem];
	[_panelOneContainer addSubview:credits];

	[credits setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[credits.widthAnchor constraintEqualToConstant:(kWidth/2)] setActive:YES];
	[[credits.heightAnchor constraintEqualToConstant:45] setActive:YES];
	[[credits.leadingAnchor constraintEqualToAnchor:_panelOneContainer.leadingAnchor constant:25] setActive:YES];
	[[credits.centerYAnchor constraintEqualToAnchor:_panelOneContainer.centerYAnchor constant:27.5] setActive:YES];

	[credits setTag:0];
	[credits setClipsToBounds:YES];
	[credits.layer setCornerRadius:10];
	[credits setTitle:localize(@"Credits") forState:UIControlStateNormal];
	[credits.titleLabel setFont:[UIFont systemFontOfSize:[UIFont labelFontSize] weight:0.40]];
	[credits setTintColor:[self IALBlue]];
	if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [credits setBackgroundColor:[UIColor systemGray6Color]];
	else [credits setBackgroundColor:[UIColor whiteColor]];
	[credits addTarget:self action:@selector(subButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

	// backups
	UIButton *backups = [UIButton buttonWithType:UIButtonTypeSystem];
	[_panelOneContainer addSubview:backups];

	[backups setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[backups.widthAnchor constraintEqualToConstant:(kWidth/2)] setActive:YES];
	[[backups.heightAnchor constraintEqualToConstant:45] setActive:YES];
	[[backups.trailingAnchor constraintEqualToAnchor:_panelOneContainer.trailingAnchor constant:-25] setActive:YES];
	[[backups.centerYAnchor constraintEqualToAnchor:_panelOneContainer.centerYAnchor constant:27.5] setActive:YES];

	[backups setTag:1];
	[backups setClipsToBounds:YES];
	[backups.layer setCornerRadius:10];
	[backups setTitle:localize(@"Backups") forState:UIControlStateNormal];
	[backups.titleLabel setFont:[UIFont systemFontOfSize:[UIFont labelFontSize] weight:0.40]];
	[backups setTintColor:[self IALBlue]];
	if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [backups setBackgroundColor:[UIColor systemGray6Color]];
	else [backups setBackgroundColor:[UIColor whiteColor]];
	[backups addTarget:self action:@selector(subButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
}

-(void)makePanelTwo{
	// create container for buttons
	_panelTwoContainer = [[UIView alloc] init];
	[_panelTwoContainer setBackgroundColor:[UIColor clearColor]];
	[_controlPanelView addSubview:_panelTwoContainer];

	[_panelTwoContainer setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[_panelTwoContainer.topAnchor constraintEqualToAnchor:_controlPanelView.topAnchor] setActive:YES];
	[[_panelTwoContainer.bottomAnchor constraintEqualToAnchor:_controlPanelView.bottomAnchor] setActive:YES];
	[[_panelTwoContainer.leadingAnchor constraintEqualToAnchor:_controlPanelView.leadingAnchor] setActive:YES];
	[[_panelTwoContainer.trailingAnchor constraintEqualToAnchor:_controlPanelView.trailingAnchor] setActive:YES];

	// hide until needed
	[_panelTwoContainer setAlpha:0];

	// go
	UIButton *go = [UIButton buttonWithType:UIButtonTypeSystem];
	[_panelTwoContainer addSubview:go];

	[go setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[go.widthAnchor constraintEqualToConstant:(kWidth - 50)] setActive:YES];
	[[go.heightAnchor constraintEqualToConstant:45] setActive:YES];
	[[go.centerXAnchor constraintEqualToAnchor:_panelTwoContainer.centerXAnchor] setActive:YES];
	[[go.centerYAnchor constraintEqualToAnchor:_panelTwoContainer.centerYAnchor constant:-27] setActive:YES];

	[go setClipsToBounds:YES];
	[go.layer setCornerRadius:10];
	[go setTitle:localize(@"Go") forState:UIControlStateNormal];
	[go.titleLabel setFont:[UIFont systemFontOfSize:[UIFont labelFontSize] weight:0.40]];
	[go setTintColor:[UIColor systemGreenColor]];
	if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [go setBackgroundColor:[UIColor systemGray6Color]];
	else [go setBackgroundColor:[UIColor whiteColor]];
	[go addTarget:self action:@selector(startWork) forControlEvents:UIControlEventTouchUpInside];

	// config switch
	_configSwitch = [[UISegmentedControl alloc] initWithItems:nil];
	[_panelTwoContainer addSubview:_configSwitch];

	[_configSwitch setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[_configSwitch.widthAnchor constraintEqualToConstant:(kWidth - 50)] setActive:YES];
	[[_configSwitch.heightAnchor constraintEqualToConstant:45] setActive:YES];
	[[_configSwitch.centerXAnchor constraintEqualToAnchor:_panelTwoContainer.centerXAnchor] setActive:YES];
	[[_configSwitch.centerYAnchor constraintEqualToAnchor:_panelTwoContainer.centerYAnchor constant:27.5] setActive:YES];

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
		[_configSwitch removeAllSegments];
		switch(sender.tag){
			case 0:
				[_configSwitch insertSegmentWithTitle:localize(@"Standard") atIndex:0 animated:NO];
				[_configSwitch insertSegmentWithTitle:localize(@"Developer") atIndex:1 animated:NO];
				_controlPanelState = 1;
				break;
			case 1:
				[_configSwitch insertSegmentWithTitle:localize(@"Latest") atIndex:0 animated:NO];
				[_configSwitch insertSegmentWithTitle:localize(@"Specific") atIndex:1 animated:NO];
				_controlPanelState = 2;
				break;
		}
		[_configSwitch setSelectedSegmentIndex:0];
	}
	// if control panel state is not 0 and/or tapped an already selected button
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
	AudioServicesPlaySystemSound(1520);

	switch(sender.tag){
		case 0: {
			IALCreditsViewController *creditsViewController = [[IALCreditsViewController alloc] init];
			[self presentViewController:creditsViewController animated:YES completion:nil];
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
	AudioServicesPlaySystemSound(1520);

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
	AudioServicesPlaySystemSound(1520);
}

#pragma mark Functionality

-(void)selectedBackupWithFilter:(BOOL)filter{
	UIAlertController *alert = [UIAlertController
								alertControllerWithTitle:@"IAmLazy"
								message:localize(@"Please confirm that you have adequate free storage before proceeding:")
								preferredStyle:UIAlertControllerStyleActionSheet];

	UIAlertAction *confirm = [UIAlertAction
								actionWithTitle:localize(@"Confirm")
								style:UIAlertActionStyleDefault
								handler:^(UIAlertAction *action){
									[self makeBackupWithFilter:filter];
								}];

	UIAlertAction *cancel = [UIAlertAction
								actionWithTitle:localize(@"Cancel")
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

	[_manager makeBackupWithFilter:filter andCompletion:^(BOOL completed){
		dispatch_async(dispatch_get_main_queue(), ^(void){
			[app setIdleTimerDisabled:NO]; // re-enable idle timer regardless of completion status
			if(completed){
				_endTime = [NSDate date];

				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
					[self dismissViewControllerAnimated:YES completion:^{
						[self popPostBackup];
					}];
				});
			}
		});
	}];
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

	// get desired backup
	NSString *extension = @"tar.gz";
	NSPredicate *thePredicate = [NSPredicate predicateWithFormat:@"SELF ENDSWITH %@", extension];
	NSArray *desiredBackups = [backups filteredArrayUsingPredicate:thePredicate];
	if(latest){
		NSString *backup = [desiredBackups firstObject];
		[self confirmRestoreFromBackup:backup];
	}
	else{
		// post list of available backups
		UIAlertController *alert = [UIAlertController
									alertControllerWithTitle:@"IAmLazy"
									message:localize(@"Choose the backup you'd like to restore from:")
									preferredStyle:UIAlertControllerStyleAlert];

		// make each available backup its own action
		for(NSString *backup in desiredBackups){
			UIAlertAction *action = [UIAlertAction
										actionWithTitle:backup
										style:UIAlertActionStyleDefault
										handler:^(UIAlertAction *action){
											[self confirmRestoreFromBackup:backup];
										}];

			[alert addAction:action];
		}

		UIAlertAction *cancel = [UIAlertAction
									actionWithTitle:localize(@"Cancel")
									style:UIAlertActionStyleDefault
									handler:^(UIAlertAction *action){
										[self dismissViewControllerAnimated:YES completion:nil];
									}];

		[alert addAction:cancel];

		[self presentViewController:alert animated:YES completion:^{
			// allows dismissal of UIAlertControllerStyleAlerts when
			// the user touches anywhere out of bounds of the alert view
			[alert.view.superview setUserInteractionEnabled:YES];
			[alert.view.superview addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(alertOOBTap)]];
		}];
	}
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

	[self presentViewController:alert animated:YES completion:nil];
}

-(void)alertOOBTap{
	[self dismissViewControllerAnimated:YES completion:nil];
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

-(void)popPostBackup{
	AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);

	UIAlertController *alert = [UIAlertController
								alertControllerWithTitle:@"IAmLazy"
								message:[NSString stringWithFormat:[[localize(@"Tweak backup completed successfully in %@ seconds!")
																		stringByAppendingString:@"\n\n"]
																		stringByAppendingString:localize(@"Your backup can be found in\n%@")],
																		[self getDuration],
																		backupDir]
								preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *export = [UIAlertAction
								actionWithTitle:localize(@"Export")
								style:UIAlertActionStyleDefault
								handler:^(UIAlertAction *action){
									// Note: to export a local file, need to use an NSURL
									NSURL *fileURL = [NSURL fileURLWithPath:[backupDir stringByAppendingPathComponent:[[_manager getBackups] firstObject]]];

									UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
									[activityViewController setModalTransitionStyle:UIModalTransitionStyleCoverVertical];

									[self presentViewController:activityViewController animated:YES completion:nil];
								}];

	UIAlertAction *okay = [UIAlertAction
							actionWithTitle:localize(@"Okay")
							style:UIAlertActionStyleDefault
							handler:^(UIAlertAction *action){
								[self dismissViewControllerAnimated:YES completion:nil];
							}];

	[alert addAction:export];
	[alert addAction:okay];

 	[self presentViewController:alert animated:YES completion:nil];
}

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
										"/usr/bin/sbreload",
										NULL
									};
									task(args);
								}];

	UIAlertAction *uicache = [UIAlertAction
								actionWithTitle:@"UICache & Respring"
								style:UIAlertActionStyleDefault
								handler:^(UIAlertAction *action){
									const char *args[] = {
										"/usr/bin/uicache",
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

-(UIColor *)IALBlue{
	return [UIColor colorWithRed:82.0f/255.0f green:102.0f/255.0f blue:142.0f/255.0f alpha:1.0f];
}

@end
