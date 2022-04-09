//
//	IALProgressViewController.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#include "IALProgressViewController.h"
#import "../Common.h"

#define fillColor [UIColor colorWithRed:16.0f/255.0f green:16.0f/255.0f blue:16.0f/255.0f alpha:1.0f]
#define accentColor [UIColor colorWithRed:247.0f/255.0f green:249.0f/255.0f blue:250.0f/255.0f alpha:1.0f]

@implementation IALProgressViewController

-(instancetype)initWithPurpose:(NSInteger)purpose ofType:(NSInteger)type withFilter:(BOOL)filter{
	self = [super init];

	if(self){
		/*
			purpose: 0 = backup | 1 = restore
			type: 0 = deb | 1 = list
		*/
		if(purpose == 0 && type == 0){
			self.itemCount = 4;
		}
		else{
			self.itemCount = 3;
		}

		[self makeTitleWithPurpose:purpose];
		[self setItemIcons:[self iconsForPurpose:purpose ofType:type]];
		[self makeListWithItems:self.itemCount];
		[self setItemDescriptions:[self itemDescriptionsForPurpose:purpose ofType:type withFilter:filter]];
		[self elaborateItemsList];
		[self makeLoadingWheel];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateProgress:) name:@"updateProgress" object:nil];
	}

	return self;
}

-(void)loadView{
	[super loadView];

	[self.view setBackgroundColor:fillColor];
}

-(void)makeTitleWithPurpose:(NSInteger)purpose{
	NSString *purposeString;
	if(purpose == 0){
		purposeString = @"backup";
	}
	else{
		purposeString = @"restore";
	}

	NSString *text = [NSString stringWithFormat:@"%@ Progress", purposeString];

	UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 35, kWidth, 30)];
	[title setFont:[UIFont systemFontOfSize:30 weight:0.60]];
	[title setText:[text uppercaseString]];
	[title setTextColor:accentColor];
	[title setTextAlignment:NSTextAlignmentCenter];

	[self.view addSubview:title];
}

-(NSMutableArray *)iconsForPurpose:(NSInteger)purpose ofType:(NSInteger)type{
	NSMutableArray *icons = [NSMutableArray new];

	/*
		purpose: 0 = backup | 1 = restore
		type: 0 = deb | 1 = list
	*/

	if(purpose == 0){
		[icons addObject:@"list.number"];
		if(type == 0){
			[icons addObject:@"rectangle.on.rectangle.angled"];
			[icons addObject:@"rectangle.3.offgrid"];
		}
		else{
			[icons addObject:@"increase.indent"];
			[icons addObject:@"pencil"];
		}
		[icons addObject:@"folder.badge.plus"];
	}
	else{
		[icons addObject:@"text.badge.checkmark"];
		if(type == 0) [icons addObject:@"wrench"];
		else [icons addObject:@"magnifyingglass.circle"];
		[icons addObject:@"arrow.down.circle"];
	}

	return icons;
}

-(void)makeListWithItems:(int)count{
	self.items = [NSMutableArray new];
	self.itemStatusIcons = [NSMutableArray new];

	for(int i = 0; i < count; i++){
		CGFloat y = 90 + (i * 100);

		UIView *background = [[UIView alloc] initWithFrame:CGRectMake(10, y, 60, 60)];
		[background setBackgroundColor:accentColor];
		[background.layer setCornerRadius:background.frame.size.height/2];

		UIView *fill = [[UIView alloc] initWithFrame:CGRectInset(background.bounds, 1, 1)];
		[fill setBackgroundColor:fillColor];
		[fill.layer setCornerRadius:background.frame.size.height/2];
		[background addSubview:fill];

		UIImageView *item = [[UIImageView alloc] initWithFrame:CGRectInset(fill.bounds, 7.5, 7.5)];
		[item setImage:[UIImage systemImageNamed:self.itemIcons[i]]];
		[item setContentMode:UIViewContentModeScaleAspectFit];

		UIView *status = [[UIView alloc] initWithFrame:CGRectMake(45, 45, 10, 10)];
		[status setBackgroundColor:[UIColor grayColor]];
		[status.layer setCornerRadius:status.frame.size.height/2];

		[self.view addSubview:background];
		[fill addSubview:item];
		[fill addSubview:status];

		[self.items addObject:item];
		[self.itemStatusIcons addObject:status];
	}
}

-(NSMutableArray *)itemDescriptionsForPurpose:(NSInteger)purpose ofType:(NSInteger)type withFilter:(BOOL)filter{
	NSMutableArray *itemDescs = [NSMutableArray new];

	/*
		purpose: 0 = backup | 1 = restore
		type: 0 = deb | 1 = list
	*/

	if(purpose == 0){
		if(type == 0){
			if(filter){
				[itemDescs addObject:@"Generating list of user packages"];
				[itemDescs addObject:@"Gathering files for user packages"];
			}
			else {
				[itemDescs addObject:@"Generating list of installed packages"];
				[itemDescs addObject:@"Gathering files for installed packages"];
			}
			[itemDescs addObject:@"Building debs from gathered files"];
			[itemDescs addObject:@"Creating backup from debs"];
		}
		else{
			if(filter){
				[itemDescs addObject:@"Generating list of user packages"];
				[itemDescs addObject:@"Formatting list of user packages"];
			}
			else{
				[itemDescs addObject:@"Generating list of installed packages"];
				[itemDescs addObject:@"Formatting list of installed packages"];
			}
			[itemDescs addObject:@"Writing list to file"];
		}
	}
	else{
		[itemDescs addObject:@"Completing pre-restore checks"];
		if(type == 0){
			[itemDescs addObject:@"Unpacking backup"];
			[itemDescs addObject:@"Installing debs"];
		}
		else{
			[itemDescs addObject:@"Preparing the target list"];
			[itemDescs addObject:@"Installing packages from list"];
		}
	}

	return itemDescs;
}

-(void)elaborateItemsList{
	self.itemStatusText = [NSMutableArray new];

	for(int i = 0; i < [self.items count]; i++){
		UIView *item = self.items[i];
		CGPoint center = item.center;
		CGPoint position = [item convertPoint:center toView:self.view];
		CGFloat x = 0;
		// RTL support
		if([UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft){
			x = -10;
		}
		else{
			x = position.x + 35;
		}

		UILabel *itemDesc = [[UILabel alloc] initWithFrame:CGRectMake(x,position.y - 28, kWidth, 20)];
		[itemDesc setText:self.itemDescriptions[i]];
		[itemDesc setTextColor:accentColor];

		UILabel *itemStatus = [[UILabel alloc] initWithFrame:CGRectMake(x,position.y - 8, kWidth, 20)];
		[itemStatus setFont:[UIFont systemFontOfSize:14 weight:-0.60]];
		[itemStatus setText:@"Waiting"];
		[itemStatus setTextColor:accentColor];
		[itemStatus setAlpha:0.75];

		[self.view addSubview:itemDesc];
		[self.view addSubview:itemStatus];

		[self.itemStatusText addObject:itemStatus];
	}
}

-(void)makeLoadingWheel{
	self.loading = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake((kWidth/2) - 25, (kHeight * (5/6)) + 12.5, 50, 50)];
	[self.loading setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleLarge];
	[self.loading setColor:accentColor];
	[self.loading setHidesWhenStopped:YES];
	[self.loading startAnimating];
	[self.view addSubview:self.loading];
}

-(void)updateProgress:(NSNotification *)notification{
	CGFloat item = [(NSString *)notification.object floatValue];
	int itemInt = ceil(item);
	BOOL isInteger = itemInt == item;

	if(isInteger){
		[UIView animateWithDuration:0.5 animations:^{
			// Note: colorWithRed:green:blue:alpha: seems to use sRGB, not Adobe RGB (https://stackoverflow.com/a/40052756)
			// super helpful link -- https://www.easyrgb.com/en/convert.php#inputFORM
			[self.itemStatusIcons[itemInt] setBackgroundColor:[UIColor colorWithRed:0.04716 green:0.73722 blue:0.09512 alpha:1.00000]];
			[self.itemStatusText[itemInt] setText:@"Completed"];
		}];
	}
	else{
		[UIView animateWithDuration:0.5 animations:^{
			[self.itemStatusIcons[itemInt] setBackgroundColor:[UIColor colorWithRed:1.00000 green:0.67260 blue:0.21379 alpha:1.00000]];
			[self.itemStatusText[itemInt] setText:@"In-progress"];
		}];
	}

	if(item+1 == [self.items count]){
		[self.loading stopAnimating];
	}
}

@end
