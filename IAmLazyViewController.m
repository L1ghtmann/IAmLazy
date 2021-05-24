#include "IAmLazyViewController.h"
#import "Common.h"

@implementation IAmLazyViewController

- (instancetype)initWithPurpose:(NSString *)purpose {

	self = [super init];

	if(self) {
		int items;
		if([purpose isEqualToString:@"backup"]){
			items = 5;
		}
		else{
			items = 3;
		}

		[self makeTitleWithPurpose:purpose];
		[self setItemIcons:[self iconsForPurpose:purpose]];
		[self makeListWithItems:items];
		[self setItemDescriptions:[self itemDescriptionsForPurpose:purpose]];
		[self elaborateItemsList];
		[self makeLoadingWheel];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateProgress:) name:@"updateProgress" object:nil];
	}	

	return self;
}

// create primary (background) view 
- (void)viewDidLoad{
	[super viewDidLoad];

	self.view = [[UIView alloc] initWithFrame:CGRectMake(0,0,kWidth,kHeight)];
	[self.view setBackgroundColor:[self fillAccordingToInterfaceStyle]];
}

- (void)makeTitleWithPurpose:(NSString *)purpose{
	NSString *text = [NSString stringWithFormat:@"%@ Progress", purpose];
	
	UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0,35,kWidth,30)];
	title.font = [UIFont systemFontOfSize:30 weight:0.60]; 
	[title setText:[text uppercaseString]];
	[title setTextColor:[self accordingToInterfaceStyle]];
	[title setTextAlignment:NSTextAlignmentCenter];     

	[self.view addSubview:title];
}

- (NSMutableArray *)iconsForPurpose:(NSString *)purpose{
	NSMutableArray *icons = [NSMutableArray new];
	
	if([purpose isEqualToString:@"backup"]){
		[icons addObject:@"list.number"];
		[icons addObject:@"person.crop.circle"];
		[icons addObject:@"rectangle.on.rectangle.angled"];
		[icons addObject:@"rectangle.3.offgrid"];
		[icons addObject:@"folder.badge.plus"];
	}
	else{
		[icons addObject:@"text.badge.checkmark"];
		[icons addObject:@"wrench"];
		[icons addObject:@"arrow.down.circle"];
	}
	
	return icons;
}

- (void)makeListWithItems:(int)count{
	self.items = [NSMutableArray new];
	self.itemStatusIcons = [NSMutableArray new];
	self.itemStatusText = [NSMutableArray new];

	for(int i = 0; i < count; i++){
		CGFloat y = 90+(i*100);

		UIView *background = [[UIView alloc] initWithFrame:CGRectMake(10,y,60,60)];
		[background setBackgroundColor:[self accordingToInterfaceStyle]];
		[background.layer setCornerRadius:background.frame.size.height/2];
		
		UIView *fill = [[UIView alloc] initWithFrame:CGRectInset(background.bounds, 1, 1)];
		[fill setBackgroundColor:[self fillAccordingToInterfaceStyle]];
		[fill.layer setCornerRadius:background.frame.size.height/2];
		[background addSubview:fill];

		UIImageView *item = [[UIImageView alloc] initWithFrame:CGRectInset(fill.bounds, 7.5, 7.5)];
		[item setImage:[UIImage systemImageNamed:self.itemIcons[i]]];
		[item setContentMode:UIViewContentModeScaleAspectFit];

		UIView *status = [[UIView alloc] initWithFrame:CGRectMake(45,45,10,10)];
		[status setBackgroundColor:[UIColor grayColor]];
		[status.layer setCornerRadius:status.frame.size.height/2];

		[self.view addSubview:background];
		[fill addSubview:item];
		[fill addSubview:status];

		[self.items addObject:item];
		[self.itemStatusIcons addObject:status];
		[self.itemStatusText addObject:@"Waiting"];
	}
}

- (NSMutableArray *)itemDescriptionsForPurpose:(NSString *)purpose{
	NSMutableArray *itemDescs = [NSMutableArray new];
	
	if([purpose isEqualToString:@"backup"]){
		[itemDescs addObject:@"Generating list of installed packages"];
		[itemDescs addObject:@"Filtering list for user packages"];
		[itemDescs addObject:@"Gathering files for user packages"];
		[itemDescs addObject:@"Building debs from gathered files"];
		[itemDescs addObject:@"Creating backup from debs"];
	}
	else{
		[itemDescs addObject:@"Completing pre-restore checks"];
		[itemDescs addObject:@"Unpacking backup"];
		[itemDescs addObject:@"Installing debs"];
	}
	
	return itemDescs;
}

- (void)elaborateItemsList{
	self.itemStatusText = [NSMutableArray new];

	for(int i = 0; i < [self.items count]; i++){
		UIView *item = self.items[i];
		CGPoint center = item.center;
		CGPoint position = [item convertPoint:center toView:self.view];

		UILabel *itemDesc = [[UILabel alloc] initWithFrame:CGRectMake(position.x+35,position.y-28,kWidth,20)];
		[itemDesc setText:self.itemDescriptions[i]];
		[itemDesc setTextColor:[self accordingToInterfaceStyle]];

		UILabel *itemStatus = [[UILabel alloc] initWithFrame:CGRectMake(position.x+35,position.y-8,kWidth,20)];
		itemStatus.font = [UIFont systemFontOfSize:14 weight:-0.60]; 
		[itemStatus setText:@"Waiting"];
		[itemStatus setTextColor:[self accordingToInterfaceStyle]];
		[itemStatus setAlpha:.75];

		[self.view addSubview:itemDesc];
		[self.view addSubview:itemStatus];

		[self.itemStatusText addObject:itemStatus];
	}
}

- (void)makeLoadingWheel{
	self.loading = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake((kWidth/2)-25,((kHeight*5)/6)+12.5,50,50)];
	[self.loading setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleLarge];
	[self.loading setColor:[self accordingToInterfaceStyle]];
	[self.loading setHidesWhenStopped:YES];
	[self.loading startAnimating];
	[self.view addSubview:self.loading];
}

- (void)updateProgress:(NSNotification *)notification{
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

- (UIColor *)fillAccordingToInterfaceStyle{
	if(self.traitCollection.userInterfaceStyle == 2){ // dark mode enabled
		return [UIColor colorWithRed:16.0f/255.0f green:16.0f/255.0f blue:16.0f/255.0f alpha:1.0f];
	}
	else{
		return [UIColor colorWithRed:247.0f/255.0f green:249.0f/255.0f blue:250.0f/255.0f alpha:1.0];
	}
}

- (UIColor *)accordingToInterfaceStyle{
	if(self.traitCollection.userInterfaceStyle == 2){ // dark mode enabled
		return [UIColor colorWithRed:247.0f/255.0f green:249.0f/255.0f blue:250.0f/255.0f alpha:1.0];
	}
	else{
		return [UIColor colorWithRed:16.0f/255.0f green:16.0f/255.0f blue:16.0f/255.0f alpha:1.0f];
	}
}

@end
