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
	// setup main background
	UIView *mainView = [[UIView alloc] init];
	[self.view addSubview:mainView];

	[mainView setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[mainView.topAnchor constraintEqualToAnchor:self.view.topAnchor] setActive:YES];
	[[mainView.widthAnchor constraintEqualToConstant:kWidth] setActive:YES];
	[[mainView.heightAnchor constraintEqualToConstant:((kHeight/4) * 3)] setActive:YES];

	// make sure bounds/frame are updated
	// can't use constraints on calayers
	// so need mainView's bounds to exist
	[mainView layoutIfNeeded];

	CAGradientLayer *gradient = [CAGradientLayer layer];
	[gradient setFrame:mainView.bounds];
	[gradient setColors:@[(id)[self IALBlue].CGColor,
						(id)[UIColor colorWithRed:252.0f/255.0f green:251.0f/255.0f blue:216.0f/255.0f alpha:1.0f].CGColor]];
	[mainView.layer insertSublayer:gradient atIndex:0];

	// setup IAL icon
	UIImageView *imgView = [[UIImageView alloc] init];
	[mainView addSubview:imgView];

	[imgView setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[imgView.centerXAnchor constraintEqualToAnchor:mainView.centerXAnchor] setActive:YES];
	[[imgView.centerYAnchor constraintEqualToAnchor:mainView.centerYAnchor constant:-85] setActive:YES];

	[imgView setImage:[UIImage imageNamed:@"Assets/AppIcon250-Clear"]];
	[imgView setUserInteractionEnabled:NO];

	// setup two primary function buttons
	for(int i = 0; i < 2; i++){
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		[mainView addSubview:button];

		[button setTranslatesAutoresizingMaskIntoConstraints:NO];
		[[button.widthAnchor constraintEqualToConstant:((kWidth/3) * 2)] setActive:YES];
		[[button.heightAnchor constraintEqualToConstant:(55 * hScaleFactor)] setActive:YES];
		[[button.centerXAnchor constraintEqualToAnchor:mainView.centerXAnchor] setActive:YES];
		if(i == 0){
			[[button.centerYAnchor constraintEqualToAnchor:mainView.centerYAnchor constant:75] setActive:YES];
		}
		else{
			[[button.topAnchor constraintEqualToAnchor:mainView.subviews[i].bottomAnchor constant:15] setActive:YES];
		}

		[button setTag:i];
		[button setClipsToBounds:YES];
		[button.layer setCornerRadius:10];
		if(i == 0){
			[button setTitle:localize(@"Backup") forState:UIControlStateNormal];
			[button setImage:[UIImage systemImageNamed:@"plus.app"] forState:UIControlStateNormal];
		}
		else{
			[button setTitle:localize(@"Restore") forState:UIControlStateNormal];
			[button setImage:[UIImage systemImageNamed:@"arrow.counterclockwise.circle"] forState:UIControlStateNormal];
		}
		[button.titleLabel setFont:[UIFont systemFontOfSize:[UIFont labelFontSize] weight:0.56]];
		[button setTintColor:[self IALBlue]];
		[button setTitleColor:[self IALBlue] forState:UIControlStateNormal];
		if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [button setBackgroundColor:[UIColor systemGray6Color]];
		else [button setBackgroundColor:[UIColor whiteColor]];
		[button setAdjustsImageWhenHighlighted:NO];
		[button addTarget:self action:@selector(mainButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
	}
}

-(void)makeControlPanel{
	// setup control panel background
	UIView *controlPanelView = [[UIView alloc] init];
	[self.view addSubview:controlPanelView];

	[controlPanelView setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[controlPanelView.widthAnchor constraintEqualToConstant:kWidth] setActive:YES];
	[[controlPanelView.heightAnchor constraintEqualToConstant:(kHeight/4)] setActive:YES];
	[[controlPanelView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor] setActive:YES];

	if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [controlPanelView setBackgroundColor:[UIColor colorWithRed:16.0f/255.0f green:16.0f/255.0f blue:16.0f/255.0f alpha:1.0f]];
	else [controlPanelView setBackgroundColor:[UIColor colorWithRed:247.0f/255.0f green:249.0f/255.0f blue:250.0f/255.0f alpha:1.0f]];

	// setup two button containers
	for(int i = 0; i < 2; i++){
		// container
		UIView *view = [[UIView alloc] init];
		[view setBackgroundColor:[UIColor clearColor]];
		[controlPanelView addSubview:view];

		[view setTranslatesAutoresizingMaskIntoConstraints:NO];
		[[view.topAnchor constraintEqualToAnchor:controlPanelView.topAnchor] setActive:YES];
		[[view.bottomAnchor constraintEqualToAnchor:controlPanelView.bottomAnchor] setActive:YES];
		[[view.leadingAnchor constraintEqualToAnchor:controlPanelView.leadingAnchor] setActive:YES];
		[[view.trailingAnchor constraintEqualToAnchor:controlPanelView.trailingAnchor] setActive:YES];
		[view layoutIfNeeded];

		// top button
		UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
		[view addSubview:button];

		[button setTranslatesAutoresizingMaskIntoConstraints:NO];
		[[button.widthAnchor constraintEqualToConstant:((kWidth/7) * 6)] setActive:YES];
		[[button.heightAnchor constraintEqualToConstant:(45 * hScaleFactor)] setActive:YES];
		[[button.centerXAnchor constraintEqualToAnchor:view.centerXAnchor] setActive:YES];
		[[button.centerYAnchor constraintEqualToAnchor:view.centerYAnchor constant:-(view.bounds.size.height/6)] setActive:YES];

		[button setClipsToBounds:YES];
		[button.layer setCornerRadius:10];
		[button.titleLabel setFont:[UIFont systemFontOfSize:[UIFont labelFontSize] weight:0.40]];
		if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [button setBackgroundColor:[UIColor systemGray6Color]];
		else [button setBackgroundColor:[UIColor whiteColor]];

		if(i == 0){
			[button setTitle:[localize(@"Created by Lightmann") stringByAppendingString:@" | v2.4.0"] forState:UIControlStateNormal];
			[button setTintColor:[self IALBlue]];

			_panelOneContainer = view;

			[self configurePanelOne];
		}
		else{
			// hide until needed
			[view setAlpha:0];

			[button setTitle:localize(@"Go") forState:UIControlStateNormal];
			[button setTintColor:[UIColor systemGreenColor]];
			[button addTarget:self action:@selector(startWork) forControlEvents:UIControlEventTouchUpInside];

			_panelTwoContainer = view;

			[self configurePanelTwo];
		}
	}

	_controlPanelState = 0;
}

-(void)configurePanelOne{
	// setup left and right buttons
	UIView *ref = _panelOneContainer.subviews.firstObject;
	for(int i = 0; i < 2; i++){
		UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
		[_panelOneContainer addSubview:button];

		[button setTranslatesAutoresizingMaskIntoConstraints:NO];
		[[button.widthAnchor constraintEqualToConstant:(((kWidth/7) * 3) + 8)] setActive:YES];
		[[button.heightAnchor constraintEqualToConstant:(45 * hScaleFactor)] setActive:YES];
		[[button.topAnchor constraintEqualToAnchor:ref.bottomAnchor constant:15] setActive:YES];
		if(i == 0){
			[[button.leadingAnchor constraintEqualToAnchor:ref.leadingAnchor] setActive:YES];
		}
		else{
			[[button.trailingAnchor constraintEqualToAnchor:ref.trailingAnchor] setActive:YES];
		}

		[button setTag:i];
		[button setClipsToBounds:YES];
		[button.layer setCornerRadius:10];
		if(i == 0){
			[button setTitle:localize(@"Credits") forState:UIControlStateNormal];
		}
		else{
			[button setTitle:localize(@"Backups") forState:UIControlStateNormal];
		}
		[button.titleLabel setFont:[UIFont systemFontOfSize:[UIFont labelFontSize] weight:0.40]];
		[button setTintColor:[self IALBlue]];
		if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [button setBackgroundColor:[UIColor systemGray6Color]];
		else [button setBackgroundColor:[UIColor whiteColor]];
		[button addTarget:self action:@selector(subButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
	}
}

-(void)configurePanelTwo{
	// config switch
	UIView *ref = _panelTwoContainer.subviews.firstObject;
	_configSwitch = [[UISegmentedControl alloc] initWithItems:nil];
	[_panelTwoContainer addSubview:_configSwitch];

	[_configSwitch setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[_configSwitch.widthAnchor constraintEqualToConstant:((kWidth/7) * 6)] setActive:YES];
	[[_configSwitch.heightAnchor constraintEqualToConstant:(45 * hScaleFactor)] setActive:YES];
	[[_configSwitch.centerXAnchor constraintEqualToAnchor:_panelTwoContainer.centerXAnchor] setActive:YES];
	[[_configSwitch.topAnchor constraintEqualToAnchor:ref.bottomAnchor constant:15] setActive:YES];

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

	[[alert popoverPresentationController] setSourceView:_panelTwoContainer];

	[self presentViewController:alert animated:YES completion:nil];
}

-(void)makeBackupWithFilter:(BOOL)filter{
	[self presentViewController:[[IALProgressViewController alloc] initWithPurpose:0 withFilter:filter] animated:YES completion:nil];

	UIApplication *app = [UIApplication sharedApplication];
	[app setIdleTimerDisabled:YES]; // disable idle timer (screen dim + lock)
	_startTime = [NSDate date];

	[_manager makeBackupWithFilter:filter andCompletion:^(BOOL completed, NSString *info){
		dispatch_async(dispatch_get_main_queue(), ^(void){
			[app setIdleTimerDisabled:NO]; // re-enable idle timer regardless of completion status
			if(completed){
				_endTime = [NSDate date];

				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
					[self dismissViewControllerAnimated:YES completion:^{
						[self popPostBackupWithInfo:info];
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
		[_manager displayErrorWithMessage:localize(@"No backups were found!")];
		return;
	}

	// get desired backup
	if(latest){
		NSString *backup = [backups firstObject];
		[self confirmRestoreFromBackup:backup];
	}
	else{
		// post list of available backups
		UIAlertController *alert = [UIAlertController
									alertControllerWithTitle:@"IAmLazy"
									message:localize(@"Choose the backup you'd like to restore from:")
									preferredStyle:UIAlertControllerStyleAlert];

		// make each available backup its own action
		for(NSString *backup in backups){
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

									[[subalert popoverPresentationController] setSourceView:_panelTwoContainer];

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

	[[alert popoverPresentationController] setSourceView:_panelTwoContainer];

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

-(void)popPostBackupWithInfo:(NSString *)info{
	AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);

	NSString *msg = [NSString stringWithFormat:[[localize(@"Tweak backup completed successfully in %@ seconds!")
																stringByAppendingString:@"\n\n"]
																stringByAppendingString:localize(@"Your backup can be found in\n%@")],
																[self getDuration],
																backupDir];

	if([info length]){
		msg = [[msg stringByAppendingString:@"\n\n"]
					stringByAppendingString:[NSString stringWithFormat:localize(@"The following packages are not properly installed/configured and were skipped:\n%@"),
					info]];
	}

	UIAlertController *alert = [UIAlertController
								alertControllerWithTitle:@"IAmLazy"
								message:msg
								preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *export = [UIAlertAction
								actionWithTitle:localize(@"Export")
								style:UIAlertActionStyleDefault
								handler:^(UIAlertAction *action){
									// Note: to export a local file, need to use an NSURL
									NSURL *fileURL = [NSURL fileURLWithPath:[backupDir stringByAppendingPathComponent:[[_manager getBackups] firstObject]]];
									UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
									[activityViewController setModalTransitionStyle:UIModalTransitionStyleCoverVertical];
									[activityViewController.popoverPresentationController setSourceView:self.view.window.rootViewController.view];
									[activityViewController.popoverPresentationController setSourceRect:CGRectMake(0, 0, kWidth, (kHeight/2))];
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

-(UIColor *)IALBlue{
	return [UIColor colorWithRed:82.0f/255.0f green:102.0f/255.0f blue:142.0f/255.0f alpha:1.0f];
}

@end
