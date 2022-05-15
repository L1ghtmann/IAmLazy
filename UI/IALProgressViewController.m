//
//	IALProgressViewController.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "IALProgressViewController.h"
#import "../Common.h"

#define fillColor [UIColor colorWithRed:16.0f/255.0f green:16.0f/255.0f blue:16.0f/255.0f alpha:1.0f]
#define accentColor [UIColor colorWithRed:247.0f/255.0f green:249.0f/255.0f blue:250.0f/255.0f alpha:1.0f]

#define titleSize 30
#define backgroundSize 60
#define startY titleSize + backgroundSize

@implementation IALProgressViewController

-(instancetype)initWithPurpose:(NSInteger)purpose ofType:(NSInteger)type withFilter:(BOOL)filter{
	self = [super init];

	if(self){
		/*
			purpose: 0 = backup | 1 = restore
			type: 0 = deb | 1 = list
		*/
		int itemCount = 3;
		if(purpose == 0 && type == 0) itemCount = 4;

		_itemIcons = [self iconsForPurpose:purpose ofType:type];
		_itemDescriptions = [self itemDescriptionsForPurpose:purpose ofType:type withFilter:filter];

		[self makeTitleWithPurpose:purpose];
		[self makeListWithItems:itemCount];
		[self makeLoadingWheel];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateProgress:) name:@"updateProgress" object:nil];
	}

	return self;
}

-(void)loadView{
	[super loadView];

	[self.view setBackgroundColor:fillColor];
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
			[icons addObject:@"folder.badge.plus"];
		}
		else{
			[icons addObject:@"increase.indent"];
			[icons addObject:@"pencil"];
		}
	}
	else{
		[icons addObject:@"text.badge.checkmark"];
		if(type == 0) [icons addObject:@"wrench"];
		else [icons addObject:@"icloud.and.arrow.down"];
		[icons addObject:@"wand.and.stars"];
	}

	return icons;
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
		}
		else{
			[itemDescs addObject:@"Downloading debs"];
		}
		[itemDescs addObject:@"Installing debs"];
	}

	return itemDescs;
}

-(void)makeTitleWithPurpose:(NSInteger)purpose{
	NSString *purposeString;
	if(purpose == 0) purposeString = @"backup";
	else purposeString = @"restore";

	NSString *text = [NSString stringWithFormat:@"%@ Progress", purposeString];

	UILabel *title = [[UILabel alloc] init];
	[self.view addSubview:title];

	[title setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[title.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:titleSize] setActive:YES];
	[[title.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor] setActive:YES];

	[title setFont:[UIFont systemFontOfSize:titleSize weight:0.60]];
	[title setTextAlignment:NSTextAlignmentCenter];
	[title setText:[text uppercaseString]];
	[title setTextColor:accentColor];
}

-(void)makeListWithItems:(int)count{
	_items = [NSMutableArray new];
	_itemStatusIcons = [NSMutableArray new];

	for(int i = 0; i < count; i++){
		CGFloat y = startY + (i * 100);

		// white circle
		UIView *background = [[UIView alloc] init];
		[self.view addSubview:background];

		[background setTranslatesAutoresizingMaskIntoConstraints:NO];
		[[background.widthAnchor constraintEqualToConstant:backgroundSize] setActive:YES];
		[[background.heightAnchor constraintEqualToConstant:backgroundSize] setActive:YES];
		[[background.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:y] setActive:YES];
		[[background.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:10] setActive:YES];

		[background.layer setCornerRadius:backgroundSize/2];
		[background setBackgroundColor:accentColor];

		// circle fill
		UIView *fill = [[UIView alloc] init];
		[background addSubview:fill];

		[fill setTranslatesAutoresizingMaskIntoConstraints:NO];
		[[fill.widthAnchor constraintEqualToConstant:backgroundSize - 2] setActive:YES];
		[[fill.heightAnchor constraintEqualToConstant:backgroundSize - 2] setActive:YES];
		[[fill.centerXAnchor constraintEqualToAnchor:background.centerXAnchor] setActive:YES];
		[[fill.centerYAnchor constraintEqualToAnchor:background.centerYAnchor] setActive:YES];

		[fill.layer setCornerRadius:backgroundSize/2];
		[fill setBackgroundColor:fillColor];

		// image
		UIImageView *item = [[UIImageView alloc] init];
		[fill addSubview:item];
		[_items addObject:item];

		[item setTranslatesAutoresizingMaskIntoConstraints:NO];
		[[item.widthAnchor constraintEqualToConstant:backgroundSize/1.5] setActive:YES];
		[[item.heightAnchor constraintEqualToConstant:backgroundSize/1.5] setActive:YES];
		[[item.centerXAnchor constraintEqualToAnchor:fill.centerXAnchor] setActive:YES];
		[[item.centerYAnchor constraintEqualToAnchor:fill.centerYAnchor] setActive:YES];

		[item setImage:[UIImage systemImageNamed:_itemIcons[i]]];
		[item setContentMode:UIViewContentModeScaleAspectFit];

		// status indicator (colored circle)
		UIView *status = [[UIView alloc] init];
		[fill addSubview:status];
		[_itemStatusIcons addObject:status];

		[status setTranslatesAutoresizingMaskIntoConstraints:NO];
		[[status.widthAnchor constraintEqualToConstant:backgroundSize/6] setActive:YES];
		[[status.heightAnchor constraintEqualToConstant:backgroundSize/6] setActive:YES];
		[[status.trailingAnchor constraintEqualToAnchor:fill.trailingAnchor constant:-2] setActive:YES];
		[[status.topAnchor constraintEqualToAnchor:fill.topAnchor constant:(backgroundSize * 0.72)] setActive:YES];

		[status setBackgroundColor:[UIColor grayColor]];
		[status.layer setCornerRadius:backgroundSize/12];
	}

	[self elaborateItemsList];
}

-(void)elaborateItemsList{
	_itemStatusText = [NSMutableArray new];

	for(int i = 0; i < [_items count]; i++){
		CGFloat y = startY + (i * 100);

		// top label
		UILabel *itemDesc = [[UILabel alloc] init];
		[self.view addSubview:itemDesc];

		[itemDesc setTranslatesAutoresizingMaskIntoConstraints:NO];
		[[itemDesc.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:(backgroundSize + 20)] setActive:YES];
		[[itemDesc.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:(y + 10)] setActive:YES];

		[itemDesc setText:_itemDescriptions[i]];
		[itemDesc setTextColor:accentColor];

		// bottom label
		UILabel *itemStatus = [[UILabel alloc] init];
		[self.view addSubview:itemStatus];
		[_itemStatusText addObject:itemStatus];

		[itemStatus setTranslatesAutoresizingMaskIntoConstraints:NO];
		[[itemStatus.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:(backgroundSize + 20)] setActive:YES];
		[[itemStatus.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:(y + 30)] setActive:YES];

		[itemStatus setFont:[UIFont systemFontOfSize:14 weight:-0.60]];
		[itemStatus setText:@"Waiting"];
		[itemStatus setTextColor:accentColor];
		[itemStatus setAlpha:0.75];
	}
}

-(void)makeLoadingWheel{
	_loading = [[UIActivityIndicatorView alloc] init];
	[self.view addSubview:_loading];

	[_loading setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[_loading.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-20] setActive:YES];
	[[_loading.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor] setActive:YES];

	[_loading setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleLarge];
	[_loading setColor:accentColor];
	[_loading setHidesWhenStopped:YES];
	[_loading startAnimating];
}

-(void)updateProgress:(NSNotification *)notification{
	CGFloat item = [(NSString *)notification.object floatValue];
	int itemInt = ceil(item);
	BOOL isInteger = itemInt == item;

	// Note: colorWithRed:green:blue:alpha: seems to use sRGB, not Adobe RGB (https://stackoverflow.com/a/40052756)
	// A helpful link -- https://www.easyrgb.com/en/convert.php#inputFORM

	if(isInteger){
		[UIView animateWithDuration:0.5 animations:^{
			[_itemStatusIcons[itemInt] setBackgroundColor:[UIColor colorWithRed:0.04716 green:0.73722 blue:0.09512 alpha:1.00000]];
			[_itemStatusText[itemInt] setText:@"Completed"];
		}];
	}
	else{
		[UIView animateWithDuration:0.5 animations:^{
			[_itemStatusIcons[itemInt] setBackgroundColor:[UIColor colorWithRed:1.00000 green:0.67260 blue:0.21379 alpha:1.00000]];
			[_itemStatusText[itemInt] setText:@"In-progress"];
		}];
	}

	if(item + 1 == [_items count]){
		[_loading stopAnimating];
	}
}

@end
