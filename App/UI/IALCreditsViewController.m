//
//	IALCreditsViewController.m
//	IAmLazy
//
//	Created by Lightmann 04/22/23
//

#import <SafariServices/SFSafariViewController.h>
#import "IALCreditsViewController.h"
#import "IALHeaderView.h"
#import <objc/runtime.h>
#import <Common.h>

@implementation IALCreditsViewController

#pragma mark Setup

-(instancetype)init{
	return [super initWithStyle:UITableViewStyleGrouped];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
	return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
	return ([_references count] + [_contributors count]);
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
	return localize(@"Credits");
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section{
    return (85 * hScaleFactor);
}

-(void)loadView{
	[super loadView];

	// get data to present
	[self getReferences];
	[self getContributors];
}

-(void)viewDidLoad{
	[super viewDidLoad];

	// tableview background gradient
	MTMaterialView *matView = [objc_getClass("MTMaterialView") materialViewWithRecipe:2 configuration:1 initialWeighting:1];
	[self.tableView setBackgroundView:matView];
	[self.tableView setBackgroundColor:[UIColor clearColor]];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section{
    static NSString *headerIdentifier = @"header";
    IALHeaderView *header = [tableView dequeueReusableHeaderFooterViewWithIdentifier:headerIdentifier];

    if (!header) {
        NSString *subtitle = localize(@"Thank you to all who have helped!");
        UIImage *button = [UIImage systemImageNamed:@"link.circle.fill"];
        header = [[IALHeaderView alloc] initWithReuseIdentifier:headerIdentifier subtitle:subtitle andButtonImage:button];
        [header.import addTarget:self action:@selector(openSource) forControlEvents:UIControlEventTouchUpInside];
    }

    return header;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
	static NSString *cellIdentifier = @"cell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

	if(!cell){
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
		[cell setBackgroundColor:[UIColor clearColor]];
		[cell setSeparatorInset:UIEdgeInsetsZero];
		[cell setSelectionStyle:UITableViewCellSelectionStyleNone];

		[cell.detailTextLabel setTextColor:[UIColor systemGrayColor]];
	}

	NSInteger refCount = [_references count];
	if(indexPath.row < refCount){
		[cell.textLabel setText:_references.allKeys[indexPath.row]];
		[cell.detailTextLabel setText:localize(_references.allValues[indexPath.row])];
	}
	else {
		[cell.textLabel setText:_contributors.allKeys[indexPath.row - refCount]];
		[cell.detailTextLabel setText:localize(_contributors.allValues[indexPath.row - refCount])];
	}

	return cell;
}

-(void)getReferences{
	_references = @{
		// readme credits
		@"Apple" : @"Reachability project",
		@"aesign_" : @"Design inspiration (re: Electra)",
		@"Canister" : @"Bootstrap package identification",
		@"libarchive" : @"Archival functions",
		@"ScrawlingAfterlife" : @"Icon artwork"
	};
}

-(void)getContributors{
	_contributors = @{
		// translators
		@"Uckermark" : @"German translation",
		@"turkborough" : @"Turkish translation",
		@"lisiyaki" : @"Japanese translation",
		@"TheMastjdj" : @"Russian translation",
		@"sevenpastzeero" : @"Arabic translation",
		@"Alejandro Katz" : @"Spanish translation",
		@"gujiaming2022" : @"Simplified Chinese translation",
		@"olivertzeng, Neo1102" : @"Traditional Chinese (Taiwan) translation"
	};

}

#pragma mark Functionality

-(void)openSource{
	NSURL *url = [NSURL URLWithString:@"https://github.com/L1ghtmann/IAmLazy"];
	SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:url];
	[self presentViewController:safariViewController animated:YES completion:nil];
}

@end
