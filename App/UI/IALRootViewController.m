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
	[self setupMainScreen];
}

-(void)setupMainScreen{
	// setup main background
	_mainView = [[UIView alloc] initWithFrame:self.view.frame];
	[self.view addSubview:_mainView];

	CAGradientLayer *gradient = [CAGradientLayer layer];
	[gradient setFrame:_mainView.bounds];
	[gradient setColors:@[(id)[UIColor colorWithRed:252.0f/255.0f green:251.0f/255.0f blue:216.0f/255.0f alpha:1.0f].CGColor,
						  (id)[self IALBlue].CGColor]];
	[_mainView.layer insertSublayer:gradient atIndex:0];

	[self configureMainScreen];

	// setup footer label
	UILabel *footer = [[UILabel alloc] init];
	[_mainView addSubview:footer];

	[footer setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[footer.centerXAnchor constraintEqualToAnchor:_mainView.centerXAnchor] setActive:YES];
	[[footer.bottomAnchor constraintEqualToAnchor:_mainView.bottomAnchor constant:-15] setActive:YES];

	[footer setText:@"v2.5.1 | Lightmann 2021-2024"];
	[footer setFont:[UIFont systemFontOfSize:[UIFont smallSystemFontSize] weight:UIFontWeightUltraLight]];
	[footer setUserInteractionEnabled:NO];
}

-(void)configureMainScreen{
	// setup IAL icon
	UIImageView *imgView = [[UIImageView alloc] init];
	[_mainView addSubview:imgView];

	[imgView setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[imgView.centerXAnchor constraintEqualToAnchor:_mainView.centerXAnchor] setActive:YES];
	[[imgView.topAnchor constraintEqualToAnchor:_mainView.topAnchor constant:85] setActive:YES];

	[imgView setImage:[UIImage imageNamed:@"Assets/AppIcon250-Clear"]];
	[imgView setUserInteractionEnabled:NO];


	// container for labels
	_labelContainer = [[UIStackView alloc] init];
	[_mainView addSubview:_labelContainer];

	[_labelContainer setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[_labelContainer.widthAnchor constraintEqualToConstant:kWidth] setActive:YES];
	[[_labelContainer.centerXAnchor constraintEqualToAnchor:_mainView.centerXAnchor] setActive:YES];
	[[_labelContainer.topAnchor constraintEqualToAnchor:imgView.bottomAnchor] setActive:YES];

	[_labelContainer setBackgroundColor:[UIColor clearColor]];

	[_labelContainer setAlignment:UIStackViewAlignmentCenter];
	[_labelContainer setAxis:UILayoutConstraintAxisVertical];
	[_labelContainer setDistribution:UIStackViewDistributionEqualSpacing];

	[self configureLabelContainer];


	// container for items
	_itemContainer = [[UIStackView alloc] init];
	[_mainView addSubview:_itemContainer];

	[_itemContainer setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[_itemContainer.widthAnchor constraintEqualToConstant:((kWidth/3) * 2)] setActive:YES];
	[[_itemContainer.heightAnchor constraintEqualToConstant:125] setActive:YES];
	[[_itemContainer.centerXAnchor constraintEqualToAnchor:_mainView.centerXAnchor] setActive:YES];
	[[_itemContainer.topAnchor constraintEqualToAnchor:_labelContainer.bottomAnchor constant:50] setActive:YES];

	[_itemContainer setBackgroundColor:[UIColor redColor]];

	[_itemContainer setSpacing:15];
	[_itemContainer setAlignment:UIStackViewAlignmentFill];
	[_itemContainer setAxis:UILayoutConstraintAxisVertical];
	[_itemContainer setDistribution:UIStackViewDistributionFillEqually];

	[self configureItemContainer];
}

-(void)configureLabelContainer{
	// setup IAL label
	UILabel *label = [[UILabel alloc] init];
	[_labelContainer addArrangedSubview:label];

	[label setText:@"IAmLazy"];
	[label setFont:[UIFont systemFontOfSize:([UIFont labelFontSize] * 2) weight:UIFontWeightBlack]];
	[label setShadowColor:[UIColor darkGrayColor]];
	[label setShadowOffset:CGSizeMake(1,2)];
	[label setUserInteractionEnabled:NO];


	// setup sublabel
	UILabel *sublabel = [[UILabel alloc] init];
	[_labelContainer addArrangedSubview:sublabel];

	[sublabel setText:@"Easily backup and restore your tweaks"];
	[sublabel setFont:[UIFont systemFontOfSize:[UIFont labelFontSize] weight:UIFontWeightRegular]];
	[sublabel setUserInteractionEnabled:NO];
}

-(void)configureItemContainer{
	// setup two function buttons
	for(int i = 0; i < 2; i++){
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		[_itemContainer addArrangedSubview:button];

		[button setTag:i];

		if(i == 0){
			[button setTitle:localize(@"Begin") forState:UIControlStateNormal];
			[button setImage:[UIImage systemImageNamed:@"chevron.right.circle"] forState:UIControlStateNormal];
		}
		else{
			[button setTitle:localize(@"Credits") forState:UIControlStateNormal];
			[button setImage:[UIImage systemImageNamed:@"person.circle"] forState:UIControlStateNormal];
		}

		// flip title and icon
		[button setSemanticContentAttribute:UISemanticContentAttributeForceRightToLeft];
		[button setImageEdgeInsets:UIEdgeInsetsMake(2.5, 5, 0, 0)];

		[button.titleLabel setFont:[UIFont systemFontOfSize:[UIFont labelFontSize] weight:0.56]];
		[button setTintColor:[self IALBlue]];
		[button setTitleColor:[self IALBlue] forState:UIControlStateNormal];
		if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [button setBackgroundColor:[UIColor systemGray6Color]];
		else [button setBackgroundColor:[UIColor whiteColor]];

		// fix me
		[button layoutIfNeeded];
		[button.layer setMasksToBounds:YES];
		[button.layer setCornerRadius:button.bounds.size.height/2];

		[button setAdjustsImageWhenHighlighted:NO];
		[button addTarget:self action:@selector(mainButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
	}
}

-(void)mainButtonTapped:(UIButton *)sender{
	AudioServicesPlaySystemSound(1520);

	switch(sender.tag){
		case 0: {
			IALBackupsViewController *backupsViewController = [[IALBackupsViewController alloc] init];
			[self presentViewController:backupsViewController animated:YES completion:nil];
			break;
		}
		case 1: {
			IALCreditsViewController *creditsViewController = [[IALCreditsViewController alloc] init];
			[self presentViewController:creditsViewController animated:YES completion:nil];
			break;
		}
	}
}

// -(void)startWork{
// 	AudioServicesPlaySystemSound(1520);

// 	switch(_controlPanelState){
// 		case 1: // backup
// 			// standard = 0 | developer = 1
// 			[self selectedBackupWithFilter:!_configSwitch.selectedSegmentIndex];
// 			break;
// 		case 2: // restore
// 			// latest = 0 | specific = 1
// 			[self restoreLatestBackup:!_configSwitch.selectedSegmentIndex];
// 			break;
// 	}

// 	[UIView animateWithDuration:0.5 animations:^(void) {
// 		[_panelOneContainer setAlpha:1];
// 		[_panelTwoContainer setAlpha:0];
// 		_controlPanelState = 0;
// 	}];
// }

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

	[[alert popoverPresentationController] setSourceView:self.view];

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
