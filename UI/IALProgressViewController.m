//
//	IALProgressViewController.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "IALProgressViewController.h"
#import "../Common.h"

#define titleSize (30 * scaleFactor)
#define backgroundSize (55 * scaleFactor)

@implementation IALProgressViewController

-(instancetype)initWithPurpose:(NSInteger)purpose withFilter:(BOOL)filter{
	self = [super init];

	if(self){
		_itemIcons = [self iconsForPurpose:purpose];
		_itemDescriptions = [self itemDescriptionsForPurpose:purpose withFilter:filter];

		[self makeTitleWithPurpose:purpose];
		[self makeLoadingWheel];
		[self makeItemList];

		NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
		[notifCenter addObserver:self selector:@selector(updateItemStatus:) name:@"updateItemStatus" object:nil];
		[notifCenter addObserver:self selector:@selector(updateItemProgress:) name:@"updateItemProgress" object:nil];
		[notifCenter addObserver:self selector:@selector(test:) name:@"IALUpdateItemProgress" object:nil];
	}

	return self;
}

-(void)test:(NSNotification *)sender{
	// everything is sending fine (both in C and ObjC, but the layer doesn't update?!?)
	CGFloat progress = [(NSString *)sender.object floatValue];
	NSLog(@"IAmLazyLog TEST FUNC w/ prog: %f", progress);
	[_circleFill setStrokeEnd:progress];
	[_circleFill didChangeValueForKey:@"strokeEnd"];
}

-(void)loadView{
	[super loadView];

	if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [self.view setBackgroundColor:[self IALDarkGray]];
	else [self.view setBackgroundColor:[self IALOffWhite]];
}

-(NSMutableArray<NSString *> *)iconsForPurpose:(NSInteger)purpose{
	NSMutableArray *icons = [NSMutableArray new];

	/*
		purpose: 0 = backup | 1 = restore
	*/

	if(purpose == 0){
		[icons addObject:@"list.number"];
		[icons addObject:@"rectangle.on.rectangle.angled"];
		[icons addObject:@"rectangle.3.offgrid"];
		[icons addObject:@"folder.badge.plus"];
	}
	else{
		[icons addObject:@"text.badge.checkmark"];
		[icons addObject:@"wrench"];
		[icons addObject:@"goforward"];
		[icons addObject:@"wand.and.stars"];
	}

	return icons;
}

-(NSMutableArray<NSString *> *)itemDescriptionsForPurpose:(NSInteger)purpose withFilter:(BOOL)filter{
	NSMutableArray *itemDescs = [NSMutableArray new];

	/*
		purpose: 0 = backup | 1 = restore
	*/

	if(purpose == 0){
		if(filter){
			[itemDescs addObject:@"Determining user packages"];
		}
		else {
			[itemDescs addObject:@"Determining installed packages"];
		}
		[itemDescs addObject:@"Gathering files for packages"];
		[itemDescs addObject:@"Building debs from files"];
		[itemDescs addObject:@"Creating backup from debs"];
	}
	else{
		[itemDescs addObject:@"Completing pre-restore checks"];
		[itemDescs addObject:@"Unpacking backup"];
		[itemDescs addObject:@"Refreshing APT sources"];
		[itemDescs addObject:@"Installing debs"];
	}

	return itemDescs;
}

-(void)makeTitleWithPurpose:(NSInteger)purpose{
	NSString *purposeString;
	switch(purpose){
		case 0:
			purposeString = @"backup";
			break;
		case 1:
			purposeString = @"restore";
			break;
		default:
			purposeString = @"";
			break;
	}

	// Container for labels
	_titleContainer = [[UIView alloc] init];
	[_titleContainer setBackgroundColor:[UIColor systemGray6Color]];
	[self.view addSubview:_titleContainer];

	[_titleContainer setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[_titleContainer.widthAnchor constraintEqualToConstant:kWidth] setActive:YES];
	[[_titleContainer.heightAnchor constraintEqualToConstant:(titleSize + backgroundSize)] setActive:YES];
	[[_titleContainer.topAnchor constraintEqualToAnchor:self.view.topAnchor] setActive:YES];
	[[_titleContainer.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor] setActive:YES];

	// Main title
	UILabel *title = [[UILabel alloc] init];
	[_titleContainer addSubview:title];

	[title setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[title.bottomAnchor constraintEqualToAnchor:_titleContainer.bottomAnchor constant:-(titleSize/2)] setActive:YES];
	[[title.leadingAnchor constraintEqualToAnchor:_titleContainer.leadingAnchor constant:10] setActive:YES];

	[title setFont:[UIFont systemFontOfSize:titleSize weight:0.60]];
	[title setText:@"Progress"];
	if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [title setTextColor:[self IALOffWhite]];
	else [title setTextColor:[self IALDarkGray]];

	// Subtitle
	UILabel *subtitle = [[UILabel alloc] init];
	[_titleContainer addSubview:subtitle];

	[subtitle setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[subtitle.topAnchor constraintEqualToAnchor:title.topAnchor constant:-15] setActive:YES];
	[[subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor] setActive:YES];

	[subtitle setFont:[UIFont systemFontOfSize:(titleSize/2) weight:0.23]];
	[subtitle setText:[purposeString capitalizedString]];
	[subtitle setTextColor:[UIColor systemGray2Color]];
}

-(void)makeLoadingWheel{
	// Container for loading wheel
	_loadingContainer = [[UIView alloc] init];
	[_loadingContainer setBackgroundColor:[UIColor clearColor]];
	[self.view addSubview:_loadingContainer];

	[_loadingContainer setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[_loadingContainer.widthAnchor constraintEqualToConstant:kWidth] setActive:YES];
	[[_loadingContainer.heightAnchor constraintEqualToConstant:((titleSize + backgroundSize) * 2)] setActive:YES];
	[[_loadingContainer.topAnchor constraintEqualToAnchor:_titleContainer.bottomAnchor] setActive:YES];
	[[_loadingContainer.centerXAnchor constraintEqualToAnchor:_titleContainer.centerXAnchor] setActive:YES];

	// Create loading wheel
	UIView *loading = [[UIView alloc] init];
	[loading setBackgroundColor:[UIColor clearColor]];
	[_loadingContainer addSubview:loading];

	[loading setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[loading.widthAnchor constraintEqualToConstant:(backgroundSize * 2)] setActive:YES];
	[[loading.heightAnchor constraintEqualToConstant:(backgroundSize * 2)] setActive:YES];
	[[loading.centerYAnchor constraintEqualToAnchor:_loadingContainer.centerYAnchor] setActive:YES];
	[[loading.centerXAnchor constraintEqualToAnchor:_loadingContainer.centerXAnchor] setActive:YES];

	// https://stackoverflow.com/a/38520766
	CAShapeLayer *circleFramework = [CAShapeLayer layer];
	[circleFramework setFillColor:[[UIColor clearColor] CGColor]];
	[circleFramework setFrame:CGRectMake(0, 0, 90, 90)];
	[circleFramework setPosition:CGPointMake(backgroundSize, backgroundSize)];
	[circleFramework setPath:[[UIBezierPath bezierPathWithOvalInRect:circleFramework.bounds] CGPath]];
	[circleFramework setLineWidth:30];
	[circleFramework setStrokeColor:[[UIColor colorWithRed:16.0f/255.0f green:71.0f/255.0f blue:30.0f/255.0f alpha:1.0f] CGColor]];
	[loading.layer addSublayer:circleFramework];

	// https://juannavas7.medium.com/how-to-make-an-animated-circle-progress-view-48fa2adb1501
	// https://stackoverflow.com/questions/21872610/animate-a-cashapelayer-to-draw-a-progress-circle
	_circleFill = [CAShapeLayer layer];
	[_circleFill setLineWidth:30];
	[_circleFill setLineCap:kCALineCapRound];
	[_circleFill setFillColor:[[UIColor clearColor] CGColor]];
	[_circleFill setPath:[[UIBezierPath bezierPathWithArcCenter:circleFramework.position
							radius:45
							startAngle:(-M_PI/2) // func starts at 0/2pi and we're going clockwise, so go back pi/2
							endAngle:((3 * M_PI)/2) // accounting for the -pi/2, we end at 3pi/2
							clockwise:YES] CGPath]];
	[_circleFill setStrokeStart:0.0f];
	[_circleFill setStrokeEnd:0.0f];
	[_circleFill setStrokeColor:[[UIColor colorWithRed:40.0f/255.0f green:173.0f/255.0f blue:73.0f/255.0f alpha:1.0f] CGColor]];
	[loading.layer addSublayer:_circleFill];
}

-(void)makeItemList{
	_items = [NSMutableArray new];
	_itemStatusIcons = [NSMutableArray new];

	// Container for items
	_itemContainer = [[UIView alloc] init];
	[_itemContainer setBackgroundColor:[UIColor clearColor]];
	[self.view addSubview:_itemContainer];

	[_itemContainer setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[_itemContainer.widthAnchor constraintEqualToConstant:kWidth] setActive:YES];
	[[_itemContainer.topAnchor constraintEqualToAnchor:_loadingContainer.bottomAnchor] setActive:YES];
	[[_itemContainer.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor] setActive:YES];

	// make sure bounds/frame are updated
	[_itemContainer layoutIfNeeded];

	for(int i = 0; i < [_itemIcons count]; i++){
		CGFloat y = (i * (_itemContainer.frame.size.height/4.5));

		// circle border
		UIView *background = [[UIView alloc] init];
		[_itemContainer addSubview:background];

		[background setTranslatesAutoresizingMaskIntoConstraints:NO];
		[[background.widthAnchor constraintEqualToConstant:backgroundSize] setActive:YES];
		[[background.heightAnchor constraintEqualToConstant:backgroundSize] setActive:YES];
		[[background.topAnchor constraintEqualToAnchor:_itemContainer.topAnchor constant:(y + (5 * scaleFactor))] setActive:YES];
		[[background.leadingAnchor constraintEqualToAnchor:_itemContainer.leadingAnchor constant:((kWidth/4) - 5 - backgroundSize)] setActive:YES];

		[background.layer setCornerRadius:backgroundSize/2];
		if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [background setBackgroundColor:[self IALOffWhite]];
		else [background setBackgroundColor:[self IALDarkGray]];

		// circle fill
		UIView *fill = [[UIView alloc] init];
		[background addSubview:fill];

		[fill setTranslatesAutoresizingMaskIntoConstraints:NO];
		[[fill.widthAnchor constraintEqualToConstant:backgroundSize - 2] setActive:YES];
		[[fill.heightAnchor constraintEqualToConstant:backgroundSize - 2] setActive:YES];
		[[fill.centerXAnchor constraintEqualToAnchor:background.centerXAnchor] setActive:YES];
		[[fill.centerYAnchor constraintEqualToAnchor:background.centerYAnchor] setActive:YES];

		[fill.layer setCornerRadius:backgroundSize/2];
		if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [fill setBackgroundColor:[self IALDarkGray]];
		else [fill setBackgroundColor:[self IALOffWhite]];

		// icon
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

	[self elaborateItemList];
}

-(void)elaborateItemList{
	_itemStatusText = [NSMutableArray new];

	for(int i = 0; i < [_items count]; i++){
		CGFloat y = (i * (_itemContainer.frame.size.height/4.5));

		// top label
		UILabel *itemDesc = [[UILabel alloc] init];
		[_itemContainer addSubview:itemDesc];

		[itemDesc setTranslatesAutoresizingMaskIntoConstraints:NO];
		[[itemDesc.leadingAnchor constraintEqualToAnchor:_itemContainer.leadingAnchor constant:((kWidth/4) + 5)] setActive:YES];
		[[itemDesc.topAnchor constraintEqualToAnchor:_itemContainer.topAnchor constant:(y + (10 * scaleFactor))] setActive:YES];

		[itemDesc setFont:[UIFont systemFontOfSize:([UIFont labelFontSize] * scaleFactor)]];
		[itemDesc setText:_itemDescriptions[i]];
		if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [itemDesc setTextColor:[self IALOffWhite]];
		else [itemDesc setTextColor:[self IALDarkGray]];

		// bottom label
		UILabel *itemStatus = [[UILabel alloc] init];
		[_itemContainer addSubview:itemStatus];
		[_itemStatusText addObject:itemStatus];

		[itemStatus setTranslatesAutoresizingMaskIntoConstraints:NO];
		[[itemStatus.leadingAnchor constraintEqualToAnchor:itemDesc.leadingAnchor] setActive:YES];
		[[itemStatus.topAnchor constraintEqualToAnchor:itemDesc.topAnchor constant:20] setActive:YES];

		[itemStatus setFont:[UIFont systemFontOfSize:(itemDesc.font.pointSize - 3) weight:-0.60]];
		[itemStatus setText:@"Waiting"];
		if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [itemStatus setTextColor:[self IALOffWhite]];
		else [itemStatus setTextColor:[self IALDarkGray]];
		[itemStatus setAlpha:0.75];
	}
}

-(void)updateItemStatus:(NSNotification *)notification{
	CGFloat item = [(NSString *)notification.object floatValue];
	NSInteger itemInt = ceil(item);
	BOOL isInteger = item == itemInt;

	// Note: colorWithRed:green:blue:alpha: seems to use sRGB, not Adobe RGB (https://stackoverflow.com/a/40052756)
	// a helpful link -- https://www.easyrgb.com/en/convert.php#inputFORM

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
}

-(void)updateItemProgress:(NSNotification *)notification{
	CGFloat progress = [(NSString *)notification.object floatValue];
	[_circleFill setStrokeEnd:progress];
	[_circleFill didChangeValueForKey:@"strokeEnd"];
}

-(UIColor *)IALDarkGray{
	return [UIColor colorWithRed:16.0f/255.0f green:16.0f/255.0f blue:16.0f/255.0f alpha:1.0f];
}

-(UIColor *)IALOffWhite{
	return [UIColor colorWithRed:247.0f/255.0f green:249.0f/255.0f blue:250.0f/255.0f alpha:1.0f];
}

@end
