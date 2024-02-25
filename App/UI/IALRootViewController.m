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
#import <Common.h>
#import <Task.h>

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
	[gradient setColors:@[(id)[self IALYellow].CGColor, (id)[self IALBlue].CGColor]];
	[_mainView.layer insertSublayer:gradient atIndex:0];

	[self configureMainScreen];

	// setup footer label
	UIButton *footer = [UIButton buttonWithType:UIButtonTypeCustom];
	[_mainView addSubview:footer];

	[footer setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[footer.centerXAnchor constraintEqualToAnchor:_mainView.centerXAnchor] setActive:YES];
	[[footer.bottomAnchor constraintEqualToAnchor:_mainView.bottomAnchor constant:-10] setActive:YES];

	[footer setTitle:@"v2.6.0 | Lightmann 2021-2024" forState:UIControlStateNormal];
	[footer.titleLabel setFont:[UIFont systemFontOfSize:[UIFont smallSystemFontSize] weight:UIFontWeightUltraLight]];
	[footer addTarget:self action:@selector(footerTapped) forControlEvents:UIControlEventTouchUpInside];
}

-(void)footerTapped{
	IALCreditsViewController *creditsViewController = [[IALCreditsViewController alloc] init];
	[self presentViewController:creditsViewController animated:YES completion:nil];
}

-(void)configureMainScreen{
	// setup IAL icon
	UIImageView *imgView = [[UIImageView alloc] init];
	[_mainView addSubview:imgView];

	[imgView setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[imgView.centerXAnchor constraintEqualToAnchor:_mainView.centerXAnchor] setActive:YES];
	[[imgView.centerYAnchor constraintEqualToAnchor:_mainView.centerYAnchor constant:-125] setActive:YES];

	UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(toggleDebugMode:)];
	[imgView addGestureRecognizer:longPressGesture];
	[imgView setUserInteractionEnabled:YES];
	[imgView setImage:[UIImage imageNamed:@"Assets/AppIcon250-Clear"]];

	// container for labels
	UIStackView *labelContainer = [[UIStackView alloc] init];
	[_mainView addSubview:labelContainer];

	[labelContainer setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[labelContainer.widthAnchor constraintEqualToConstant:kWidth] setActive:YES];
	[[labelContainer.centerXAnchor constraintEqualToAnchor:_mainView.centerXAnchor] setActive:YES];
	[[labelContainer.topAnchor constraintEqualToAnchor:imgView.bottomAnchor] setActive:YES];

	[labelContainer setBackgroundColor:[UIColor clearColor]];

	[labelContainer setAlignment:UIStackViewAlignmentCenter];
	[labelContainer setAxis:UILayoutConstraintAxisVertical];
	[labelContainer setDistribution:UIStackViewDistributionEqualSpacing];

	[self configureLabelContainer:labelContainer];

	// container for items
	UIStackView *itemContainer = [[UIStackView alloc] init];
	[_mainView addSubview:itemContainer];

	[itemContainer setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[itemContainer.widthAnchor constraintEqualToConstant:((kWidth/3) * 2)] setActive:YES];
	[[itemContainer.heightAnchor constraintEqualToConstant:125] setActive:YES];
	[[itemContainer.centerXAnchor constraintEqualToAnchor:_mainView.centerXAnchor] setActive:YES];
	[[itemContainer.topAnchor constraintEqualToAnchor:labelContainer.bottomAnchor constant:50] setActive:YES];

	[itemContainer setBackgroundColor:[UIColor clearColor]];

	[itemContainer setSpacing:15];
	[itemContainer setAlignment:UIStackViewAlignmentFill];
	[itemContainer setAxis:UILayoutConstraintAxisVertical];
	[itemContainer setDistribution:UIStackViewDistributionFillEqually];

	[self configureItemContainer:itemContainer];
}

-(void)toggleDebugMode:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        BOOL mode = ![defaults boolForKey:@"debug"];
        [defaults setBool:mode forKey:@"debug"];
        [defaults synchronize];

        NSString *message = mode ? @"Debug mode enabled." : @"Debug mode disabled.";
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"IAmLazy"
										message:message
										preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
										style:UIAlertActionStyleDefault
										handler:nil];
        [alert addAction:okAction];

        [self presentViewController:alert animated:YES completion:nil];
    }
}

-(void)configureLabelContainer:(UIStackView *)labelContainer{
	// setup IAL label
	UILabel *label = [[UILabel alloc] init];
	[labelContainer addArrangedSubview:label];

	[label setText:@"IAmLazy"];
	[label setFont:[UIFont systemFontOfSize:([UIFont labelFontSize] * 2) weight:UIFontWeightBlack]];
	[label setShadowColor:[UIColor darkGrayColor]];
	[label setShadowOffset:CGSizeMake(1,2)];
	[label setUserInteractionEnabled:NO];

	// setup sublabel
	UILabel *sublabel = [[UILabel alloc] init];
	[labelContainer addArrangedSubview:sublabel];

	[sublabel setText:localize(@"Easily backup and restore your tweaks")];
	[sublabel setFont:[UIFont systemFontOfSize:[UIFont labelFontSize] weight:UIFontWeightRegular]];
	[sublabel setUserInteractionEnabled:NO];
}

-(void)configureItemContainer:(UIStackView *)itemContainer{
	// setup two function buttons
	for(int i = 0; i < 2; i++){
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		[itemContainer addArrangedSubview:button];

		[button setTranslatesAutoresizingMaskIntoConstraints:NO];
		[[button.widthAnchor constraintEqualToConstant:((kWidth/3) * 2)] setActive:YES];
		[[button.heightAnchor constraintEqualToConstant:55] setActive:YES];

		[button setTag:i];

		if(i == 0){
			[button setTitle:localize(@"Backup") forState:UIControlStateNormal];
			[button setImage:[UIImage systemImageNamed:@"plus.circle"] forState:UIControlStateNormal];
		}
		else{
			[button setTitle:localize(@"Restore") forState:UIControlStateNormal];
			[button setImage:[UIImage systemImageNamed:@"arrow.counterclockwise.circle"] forState:UIControlStateNormal];
		}

		// flip title and icon
		[button setSemanticContentAttribute:UISemanticContentAttributeForceRightToLeft];
		[button setImageEdgeInsets:UIEdgeInsetsMake(2.5, 5, 0, 0)];
		[button setAdjustsImageWhenHighlighted:NO];

		[button.titleLabel setFont:[UIFont systemFontOfSize:[UIFont labelFontSize] weight:UIFontWeightHeavy]];
		[button setTintColor:[self IALBlue]];
		[button setTitleColor:[self IALBlue] forState:UIControlStateNormal];
		if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [button setBackgroundColor:[UIColor systemGray6Color]];
		else [button setBackgroundColor:[UIColor whiteColor]];

		[button layoutIfNeeded];
		[button.layer setCornerRadius:55/2];

		[button addTarget:self action:@selector(mainButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
		if(i == 0){
			UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(mainButtonLongPressed:)];
			[button addGestureRecognizer:longPressGesture];
		}
	}
}

-(void)mainButtonTapped:(UIButton *)sender{
	AudioServicesPlaySystemSound(1520);

	switch(sender.tag){
		case 0: {
			[self selectedBackupWithFilter:YES];
			break;
		}
		case 1: {
			CATransition *transition = [CATransition animation];
			[transition setDuration:0.4];
			[transition setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
			[transition setType:kCATransitionReveal];
			[transition setSubtype:kCATransitionFromLeft];
			[self.view.window.layer addAnimation:transition forKey:nil];

			IALBackupsViewController *backupsViewController = [[IALBackupsViewController alloc] init];
			[self presentViewController:backupsViewController animated:NO completion:nil];
			break;
		}
	}
}

-(void)mainButtonLongPressed:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
  		AudioServicesPlaySystemSound(1520);

		[self selectedBackupWithFilter:NO];
	}
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

	[[alert popoverPresentationController] setSourceView:self.view];

	[self presentViewController:alert animated:YES completion:nil];
}

-(void)makeBackupWithFilter:(BOOL)filter{
	CATransition *transition = [CATransition animation];
	[transition setDuration:0.4];
	[transition setType:kCATransitionReveal];
	[transition setSubtype:kCATransitionFromRight];
	[transition setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
	[self.view.window.layer addAnimation:transition forKey:nil];

	IALProgressViewController *vc = [[IALProgressViewController alloc] initWithPurpose:0 withFilter:filter];
	[vc setModalInPresentation:YES];
	[self presentViewController:vc animated:YES completion:nil];

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

-(UIColor *)IALYellow{
	return [UIColor colorWithRed:252.0f/255.0f green:251.0f/255.0f blue:216.0f/255.0f alpha:1.0f];
}

-(UIColor *)IALBlue{
	return [UIColor colorWithRed:82.0f/255.0f green:102.0f/255.0f blue:142.0f/255.0f alpha:1.0f];
}

@end
