//
//	IALTableViewCell.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "IALTableViewCell.h"
#import "../Common.h"

@implementation IALTableViewCell

-(instancetype)initWithIdentifier:(NSString *)identifier purpose:(NSInteger)purpose type:(NSInteger)type function:(NSInteger)function functionDescriptor:(NSString *)descriptor{
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];

	if(self){
		// icon setup
		// helpful link for available SFSymbols: https://github.com/cyanzhong/sf-symbols-online
		// note: SFSymbols' width and height aren't equal, so need to set the content mode accordingly
		_icon = [[UIImageView alloc] initWithFrame:CGRectZero];
		[self addSubview:_icon];

		[_icon setContentMode:UIViewContentModeScaleAspectFit];
		[_icon setImage:[self imageForPurpose:purpose ofType:type andFunction:function]];
		[_icon setUserInteractionEnabled:NO];

		// color icon for 2nd cell in section creme
		if(function == 1) [_icon setTintColor:[UIColor colorWithRed:1.00000 green:0.94118 blue:0.85098 alpha:1.00000]];

		[_icon setTranslatesAutoresizingMaskIntoConstraints:NO];
		[_icon.widthAnchor constraintEqualToConstant:75].active = YES;
		[_icon.heightAnchor constraintEqualToConstant:75].active = YES;
		[_icon.leftAnchor constraintEqualToAnchor:self.leftAnchor constant:25].active = YES;
		[_icon.centerYAnchor constraintEqualToAnchor:self.centerYAnchor].active = YES;


		// (label) container setup
		_container = [[UIView alloc] initWithFrame:CGRectZero];
		[self addSubview:_container];

		[_container setTranslatesAutoresizingMaskIntoConstraints:NO];
		[_container.widthAnchor constraintEqualToConstant:(self.frame.size.width - 75)].active = YES;
		[_container.heightAnchor constraintEqualToConstant:50].active = YES;
		[_container.leftAnchor constraintEqualToAnchor:self.leftAnchor constant:105].active = YES;
		[_container.centerYAnchor constraintEqualToAnchor:self.centerYAnchor].active = YES;


		// function label setup
		_functionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		[_container addSubview:_functionLabel];

		[_functionLabel setFont:[UIFont systemFontOfSize:_functionLabel.font.pointSize weight:0.40]];
		[_functionLabel setUserInteractionEnabled:NO];
		[_functionLabel setText:descriptor];

		[_functionLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
		[_functionLabel.widthAnchor constraintEqualToConstant:kWidth].active = YES;
		[_functionLabel.heightAnchor constraintEqualToConstant:25].active = YES;
		[_functionLabel.topAnchor constraintEqualToAnchor:_container.topAnchor constant:2].active = YES;


		// function descriptor label setup
		_descriptorLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		[_container addSubview:_descriptorLabel];

		[_descriptorLabel setFont:[UIFont systemFontOfSize:(_descriptorLabel.font.pointSize * 0.75) weight:-0.40]];
		[_descriptorLabel setUserInteractionEnabled:NO];
		[_descriptorLabel setNumberOfLines:0];
		[_descriptorLabel setText:[self descriptionForPurpose:purpose andFunction:function]];

		[_descriptorLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
		[_descriptorLabel.widthAnchor constraintEqualToConstant:kWidth].active = YES;
		[_descriptorLabel.heightAnchor constraintEqualToConstant:25].active = YES;
		[_descriptorLabel.topAnchor constraintEqualToAnchor:_container.topAnchor constant:22].active = YES;
	}

	return self;
}

-(UIImage *)imageForPurpose:(NSInteger)purpose ofType:(NSInteger)type andFunction:(NSInteger)function{
	UIImage *image;

	/*
		purpose: 0 = backup | 1 = restore
		type: 0 = deb | 1 = list
		function: 0 = standard|latest | unfiltered|specific
	*/

	// backup cell
	if(purpose == 0){
		if(type == 0){ // deb
			if(function == 0) image = [UIImage systemImageNamed:@"plus.app"];
			else image = [UIImage systemImageNamed:@"exclamationmark.square"];
		}
		else{ // list
			if(function == 0) image = [UIImage systemImageNamed:@"line.horizontal.3.decrease.circle"];
			else image = [UIImage systemImageNamed:@"exclamationmark.circle"];
		}
	}
	// restore cell
	else{
		if(type == 0){ // deb
			if(function == 0) image = [UIImage systemImageNamed:@"arrow.counterclockwise.circle"];
			else image = [UIImage systemImageNamed:@"questionmark.circle"];
		}
		else{ // list
			if(function == 0) image = [UIImage systemImageNamed:@"pencil.and.outline"];
			else image = [UIImage systemImageNamed:@"pencil.tip.crop.circle"];
		}
	}

	return image;
}

-(NSString *)descriptionForPurpose:(NSInteger)purpose andFunction:(NSInteger)function{
	NSString *description;

	/*
		purpose: 0 = backup | 1 = restore
		function: 0 = standard|latest | unfiltered|specific
	*/

	if(purpose == 0){
		if(function == 0) description = @"Excludes developer packages";
		else description = @"Includes all packages";
	}
	else{
		if(function == 0) description = @"The most recent backup";
		else description = @"A backup of your choosing";
	}

	return description;
}

@end
