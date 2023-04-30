//
//	IALCreditsViewController.m
//	IAmLazy
//
//	Created by Lightmann 04/22/23
//

#import <SafariServices/SFSafariViewController.h>
#import "IALCreditsViewController.h"
#import "../Common.h"

@implementation IALCreditsViewController

#pragma mark Setup

-(instancetype)init{
	return [super initWithStyle:UITableViewStyleGrouped];
}

-(void)loadView{
	[super loadView];

	// get data to present
	[self getReferences];
	[self getContributors];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
	return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
	return ([_references count] + [_contributors count]);
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
	return localize(@"credits");
}

-(void)tableView:(UITableView *)tableView willDisplayHeaderView:(UITableViewHeaderFooterView *)header forSection:(NSInteger)section{
	[header.textLabel setTextColor:[UIColor labelColor]];
	[header.textLabel setFont:[UIFont systemFontOfSize:(20 * scaleFactor) weight:0.56]];
	[header.textLabel setText:[header.textLabel.text capitalizedString]];

	// add link button to header
	UIButton *link = [UIButton buttonWithType:UIButtonTypeSystem];
	[header addSubview:link];

	[link setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[link.widthAnchor constraintEqualToConstant:50] setActive:YES];
	[[link.heightAnchor constraintEqualToConstant:50] setActive:YES];
	[[link.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-5] setActive:YES];
	[[link.topAnchor constraintEqualToAnchor:header.topAnchor constant:5] setActive:YES];

	[link setImage:[UIImage systemImageNamed:@"link.circle.fill"] forState:UIControlStateNormal];
	[link addTarget:self action:@selector(openSource) forControlEvents:UIControlEventTouchUpInside];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
	static NSString *cellIdentifier = @"cell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

	if(!cell){
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
	}

	NSInteger refCount = [_references count];
	if(indexPath.row < refCount){
		[cell.textLabel setText:_references.allKeys[indexPath.row]];
		[cell.detailTextLabel setText:_references.allValues[indexPath.row]];
	}
	else {
		[cell.textLabel setText:_contributors.allKeys[indexPath.row - refCount]];
		[cell.detailTextLabel setText:_contributors.allValues[indexPath.row - refCount]];
	}

	return cell;
}

-(void)getReferences{
	_references = @{
		// readme credits
		@"Apple" : @"Reachability project",
		@"aesign_" : @"Design inspiration (re: Electra)",
		@"libarchive" : @"Base libarchive methods",
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
		@"gujiaming2022" : @"Simplified Chinese translation"
	};

}

#pragma mark Functionality

-(void)openSource{
	NSURL *url = [NSURL URLWithString:@"https://github.com/L1ghtmann/IAmLazy"];
	SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:url];
	[self presentViewController:safariViewController animated:YES completion:nil];
}

@end
