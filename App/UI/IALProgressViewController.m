//
//	IALProgressViewController.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "IALProgressViewController.h"
#import "IALHeaderView.h"
#import <objc/runtime.h>
#import <Shared.h>
#import <Common.h>

#define headerSize (85 * hScaleFactor)
#define backgroundSize 55

@implementation IALProgressViewController

-(instancetype)initWithPurpose:(NSInteger)purpose withFilter:(BOOL)filter{
	self = [super initWithStyle:UITableViewStyleGrouped];

	if(self){
		_debug = [[NSUserDefaults standardUserDefaults] boolForKey:@"debug"];
		_itemDescriptions = itemDescriptionsForPurposeWithFilter(purpose,filter);

		switch(purpose){
			case 0:
				_purpose = localize(@"Backup");
				break;
			case 1:
				_purpose = localize(@"Restore");
				break;
			default:
				_purpose = @"Default";
				break;
		}

		NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
		[notifCenter addObserver:self selector:@selector(updateItemStatus:) name:@"updateItemStatus" object:nil];
		[notifCenter addObserver:self selector:@selector(updateItemProgress:) name:@"updateItemProgress" object:nil];
	}

	return self;
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
	return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
	// loading, labels, (log?)
	return _debug ? 3 : 2;
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
	return localize(@"Progress");
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section{
    return (85 * hScaleFactor);
}

-(void)viewDidLoad{
	[super viewDidLoad];

	[self.tableView setScrollEnabled:NO];
	[self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];

	// tableview background gradient
	MTMaterialView *matView = [objc_getClass("MTMaterialView") materialViewWithRecipe:2 configuration:1 initialWeighting:1];
	[self.tableView setBackgroundView:matView];
	[self.tableView setBackgroundColor:[UIColor clearColor]];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section{
    static NSString *headerIdentifier = @"header";
    IALHeaderView *header = [tableView dequeueReusableHeaderFooterViewWithIdentifier:headerIdentifier];

    if (!header) {
        NSString *subtitle = localize(_purpose);
        header = [[IALHeaderView alloc] initWithReuseIdentifier:headerIdentifier subtitle:subtitle andButtonImage:nil];
    }

    return header;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
	static NSString *cellIdentifier = @"cell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

	if(!cell){
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];

		// allow time for cell run loop to complete
		dispatch_async(dispatch_get_main_queue(), ^{
			switch(indexPath.row){
				case 0:{
					[self addLoadingWheelTo:cell];
					break;
				}
				case 1:{
					[self addProgressItemsTo:cell];
					break;
				}
				case 2:{
					[self addDebugViewTo:cell];
					break;
				}
			}
		});

		[cell setBackgroundColor:[UIColor clearColor]];
		[cell setUserInteractionEnabled:NO];
	}

	return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
	// cell height
	CGFloat workingWith = tableView.frame.size.height - headerSize;
	if(!_debug && indexPath.row == 1){
		// loading always 1/3
		// items take up rest of space
		return 2 * (workingWith/3);
	}
	return workingWith/3;
}

-(void)addLoadingWheelTo:(UITableViewCell *)loadingContainer{
	// ref: https://stackoverflow.com/a/38520766
	CGFloat loadingSize = 90;
	CAShapeLayer *circleFramework = [CAShapeLayer layer];
	[circleFramework setFillColor:[[UIColor clearColor] CGColor]];
	if(iPad()){
		[circleFramework setBounds:CGRectMake(0, 0, (loadingSize * (wScaleFactor/2)), (loadingSize * (wScaleFactor/2)))];
	}
	else{
		[circleFramework setBounds:CGRectMake(0, 0, loadingSize, loadingSize)];
	}
	[circleFramework setPosition:CGPointMake(CGRectGetMidX(loadingContainer.contentView.bounds), CGRectGetMidY(loadingContainer.contentView.bounds))];
	[circleFramework setLineWidth:(loadingSize/3)];
	[circleFramework setPath:[[UIBezierPath bezierPathWithOvalInRect:circleFramework.bounds] CGPath]];
	[circleFramework setStrokeColor:[[UIColor colorWithRed:16.0f/255.0f green:71.0f/255.0f blue:30.0f/255.0f alpha:1.0f] CGColor]];
	[loadingContainer.contentView.layer addSublayer:circleFramework];

	// ref: https://juannavas7.medium.com/how-to-make-an-animated-circle-progress-view-48fa2adb1501
	// 		https://stackoverflow.com/questions/21872610/animate-a-cashapelayer-to-draw-a-progress-circle
	_circleFill = [CAShapeLayer layer];
	[_circleFill setFillColor:[[UIColor clearColor] CGColor]];
	[_circleFill setLineCap:kCALineCapRound];
	[_circleFill setFrame:circleFramework.bounds];
	[_circleFill setLineWidth:circleFramework.lineWidth];
	[_circleFill setPath:[[UIBezierPath bezierPathWithArcCenter:circleFramework.position
							radius:(circleFramework.frame.size.width/2)
							startAngle:(-M_PI/2) // func starts at 0/2pi and we're going clockwise, so go back pi/2
							endAngle:((3 * M_PI)/2) // accounting for the -pi/2, we end at 3pi/2
							clockwise:YES] CGPath]];
	[_circleFill setStrokeStart:0.0f];
	[_circleFill setStrokeEnd:0.0f];
	[_circleFill setStrokeColor:[[UIColor colorWithRed:40.0f/255.0f green:173.0f/255.0f blue:73.0f/255.0f alpha:1.0f] CGColor]];
	[loadingContainer.contentView.layer addSublayer:_circleFill];
}

-(void)addProgressItemsTo:(UITableViewCell *)cell{
	_itemStatusIndicators =[NSMutableArray new];
	_itemStatusText = [NSMutableArray new];

	// container for items
	UIStackView *itemcontainer = [[UIStackView alloc] init];
	[cell.contentView addSubview:itemcontainer];

	[itemcontainer setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[itemcontainer.widthAnchor constraintEqualToConstant:cell.contentView.frame.size.width-75] setActive:YES];
	[[itemcontainer.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor] setActive:YES];
	[[itemcontainer.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor] setActive:YES];
	[[itemcontainer.centerXAnchor constraintEqualToAnchor:cell.contentView.centerXAnchor] setActive:YES];

	[itemcontainer setAlignment:UIStackViewAlignmentLeading];
	[itemcontainer setAxis:UILayoutConstraintAxisVertical];
	[itemcontainer setDistribution:UIStackViewDistributionEqualSpacing];
	[itemcontainer setLayoutMargins:UIEdgeInsetsMake(0, 25, 0, 0)];
	[itemcontainer setLayoutMarginsRelativeArrangement:YES];

	for(int i = 0; i < [_itemDescriptions count]; i++){
		// pane for container
		UIView *pane = [[UIView alloc] init];
		[itemcontainer addArrangedSubview:pane];

		[pane setTranslatesAutoresizingMaskIntoConstraints:NO];
		[[pane.widthAnchor constraintEqualToConstant:cell.contentView.frame.size.width] setActive:YES];
		[[pane.heightAnchor constraintEqualToConstant:cell.contentView.frame.size.height/[_itemDescriptions count]] setActive:YES];

		// main label
		UILabel *itemDesc = [[UILabel alloc] init];
		[pane addSubview:itemDesc];

		[itemDesc setTranslatesAutoresizingMaskIntoConstraints:NO];
		[[itemDesc.leadingAnchor constraintEqualToAnchor:pane.leadingAnchor constant:5] setActive:YES];
		[[itemDesc.topAnchor constraintEqualToAnchor:pane.topAnchor] setActive:YES];

		[itemDesc setAdjustsFontSizeToFitWidth:YES];
		[itemDesc setText:_itemDescriptions[i]];
		[itemDesc setMinimumScaleFactor:0.5];
		if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [itemDesc setTextColor:[self IALOffWhite]];
		else [itemDesc setTextColor:[self IALDarkGray]];

		// sublabel
		UILabel *itemStatus = [[UILabel alloc] init];
		[pane addSubview:itemStatus];

		[itemStatus setTranslatesAutoresizingMaskIntoConstraints:NO];
		[[itemStatus.leadingAnchor constraintEqualToAnchor:itemDesc.leadingAnchor] setActive:YES];
		[[itemStatus.topAnchor constraintEqualToAnchor:itemDesc.bottomAnchor] setActive:YES];

		[itemStatus setFont:[UIFont systemFontOfSize:(itemDesc.font.pointSize - 3) weight:-0.60]];
		[itemStatus setText:localize(@"Waiting")];
		if(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) [itemStatus setTextColor:[self IALOffWhite]];
		else [itemStatus setTextColor:[self IALDarkGray]];
		[itemStatus setAlpha:0.75];

		[_itemStatusText addObject:itemStatus];

		// item status
		UIView *status = [[UIView alloc] init];
		[pane addSubview:status];

		[status setTranslatesAutoresizingMaskIntoConstraints:NO];
		[[status.widthAnchor constraintEqualToConstant:(backgroundSize/6)] setActive:YES];
		[[status.heightAnchor constraintEqualToConstant:(backgroundSize/6)] setActive:YES];
		[[status.trailingAnchor constraintEqualToAnchor:itemDesc.leadingAnchor constant:-5] setActive:YES];
		[[status.centerYAnchor constraintEqualToAnchor:itemDesc.centerYAnchor] setActive:YES];
		[status setBackgroundColor:[UIColor grayColor]];
		[status.layer setCornerRadius:(backgroundSize/12)];

		[_itemStatusIndicators addObject:status];
	}
}

- (void)addDebugViewTo:(UITableViewCell *)cell {
    UITextView *textView = [[UITextView alloc] initWithFrame:cell.contentView.bounds];
	[cell.contentView addSubview:textView];

    [textView setEditable:NO];
	[textView setTextContainerInset:UIEdgeInsetsMake(0, 10, 0, 10)];

    [[NSDistributedNotificationCenter defaultCenter] addObserverForName:@"[IALLog]" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        NSDictionary *userInfo = note.userInfo;
        NSString *message = userInfo[@"message"];
        dispatch_async(dispatch_get_main_queue(), ^{
            textView.text = [textView.text stringByAppendingFormat:@"\n%@", message];
			[textView scrollRangeToVisible:NSMakeRange(textView.text.length - 1, 1)];
        });
    }];

    [[NSDistributedNotificationCenter defaultCenter] addObserverForName:@"[IALLogErr]" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        NSDictionary *userInfo = note.userInfo;
        NSString *message = userInfo[@"message"];
        dispatch_async(dispatch_get_main_queue(), ^{
            textView.text = [textView.text stringByAppendingFormat:@"\n%@", message];
			[textView scrollRangeToVisible:NSMakeRange(textView.text.length - 1, 1)];
        });
    }];
}

-(void)updateItemStatus:(NSNotification *)notification{
	CGFloat item = [(NSString *)notification.object floatValue];
	NSInteger itemInt = ceil(item);
	BOOL isInteger = item == itemInt;

	// Note: colorWithRed:green:blue:alpha: seems to use sRGB, not Adobe RGB (https://stackoverflow.com/a/40052756)
	// a helpful link -- https://www.easyrgb.com/en/convert.php#inputFORM
	dispatch_async(dispatch_get_main_queue(), ^(void){
		if(isInteger){
			[UIView animateWithDuration:0.5 animations:^{
				[_itemStatusIndicators[itemInt] setBackgroundColor:[UIColor colorWithRed:0.04716 green:0.73722 blue:0.09512 alpha:1.00000]];
				[_itemStatusText[itemInt] setText:localize(@"Completed")];
			}];
		}
		else{
			[UIView animateWithDuration:0.5 animations:^{
				[_itemStatusIndicators[itemInt] setBackgroundColor:[UIColor colorWithRed:1.00000 green:0.67260 blue:0.21379 alpha:1.00000]];
				[_itemStatusText[itemInt] setText:localize(@"In-progress")];
			}];
		}
	});
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
