//
//	IALTableViewCell.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#include "IALTableViewCell.h"
#import "Common.h"

@implementation IALTableViewCell

-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier type:(NSString *)type function:(NSString *)function functionDescriptor:(NSString *)functionDescriptor{

	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];

	if (self){
		// icon setup
		// helpful link for available SFSymbols: https://github.com/cyanzhong/sf-symbols-online
		// note: SFSymbols' width and height aren't equal, so need to set the content mode accordingly
		if([function isEqualToString:@"standard-backup"]){
			_functionIcon = [[UIImageView alloc] initWithFrame:CGRectZero];
			if([type isEqualToString:@"deb"]){
				[_functionIcon setImage:[UIImage systemImageNamed:@"plus.app"]];
			}
			else{
				[_functionIcon setImage:[UIImage systemImageNamed:@"line.horizontal.3.decrease.circle"]];
			}
			[_functionIcon setContentMode:UIViewContentModeScaleAspectFit];
		}
		else if([function isEqualToString:@"unfiltered-backup"]){
			_functionIcon = [[UIImageView alloc] initWithFrame:CGRectZero];
			if([type isEqualToString:@"deb"]){
				[_functionIcon setImage:[UIImage systemImageNamed:@"exclamationmark.square"]];
			}
			else{
				[_functionIcon setImage:[UIImage systemImageNamed:@"exclamationmark.circle"]];
			}
			[_functionIcon setContentMode:UIViewContentModeScaleAspectFit];
			[_functionIcon setTintColor:[UIColor colorWithRed:1.00000 green:0.94118 blue:0.85098 alpha:1.00000]];
		}
		else if([function isEqualToString:@"latest-restore"]){
			_functionIcon = [[UIImageView alloc] initWithFrame:CGRectZero];
			if([type isEqualToString:@"deb"]){
				[_functionIcon setImage:[UIImage systemImageNamed:@"arrow.counterclockwise.circle"]];
			}
			else{
				[_functionIcon setImage:[UIImage systemImageNamed:@"pencil.and.outline"]];
			}
			[_functionIcon setContentMode:UIViewContentModeScaleAspectFit];
		}
		else if([function isEqualToString:@"specific-restore"]){
			_functionIcon = [[UIImageView alloc] initWithFrame:CGRectZero];
			if([type isEqualToString:@"deb"]){
				[_functionIcon setImage:[UIImage systemImageNamed:@"questionmark.circle"]];
			}
			else{
				[_functionIcon setImage:[UIImage systemImageNamed:@"pencil.tip.crop.circle"]];
			}
			[_functionIcon setContentMode:UIViewContentModeScaleAspectFit];
			[_functionIcon setTintColor:[UIColor colorWithRed:1.00000 green:0.94118 blue:0.85098 alpha:1.00000]];
		}
		else{
			_functionIcon = nil;
		}

		if(_functionIcon){
			[self addSubview:_functionIcon];

			[_functionIcon setUserInteractionEnabled:NO];

			[_functionIcon setTranslatesAutoresizingMaskIntoConstraints:NO];
			[_functionIcon.widthAnchor constraintEqualToConstant:75].active = YES;
			[_functionIcon.heightAnchor constraintEqualToConstant:75].active = YES;
			[_functionIcon.leftAnchor constraintEqualToAnchor:self.leftAnchor constant:25].active = YES;
			[_functionIcon.centerYAnchor constraintEqualToAnchor:self.centerYAnchor].active = YES;
		}

		// (label) container setup
		_container = [[UIView alloc] initWithFrame:CGRectZero];
		[self addSubview:_container];

		[_container setTranslatesAutoresizingMaskIntoConstraints:NO];
		[_container.widthAnchor constraintEqualToConstant:(self.frame.size.width-75)].active = YES;
		[_container.heightAnchor constraintEqualToConstant:50].active = YES;
		[_container.leftAnchor constraintEqualToAnchor:self.leftAnchor constant:105].active = YES;
		[_container.centerYAnchor constraintEqualToAnchor:self.centerYAnchor].active = YES;


		// function label setup
		_functionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		[_container addSubview:_functionLabel];

		[_functionLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
		[_functionLabel.widthAnchor constraintEqualToConstant:kWidth].active = YES;
		[_functionLabel.heightAnchor constraintEqualToConstant:25].active = YES;
		[_functionLabel.topAnchor constraintEqualToAnchor:_container.topAnchor constant:2].active = YES;

		_functionLabel.font = [UIFont systemFontOfSize:_functionLabel.font.pointSize weight:0.40];
		[_functionLabel setUserInteractionEnabled:NO];
		[_functionLabel setText:functionDescriptor];

		// function descriptor label setup
		_functionDescriptorLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		[_container addSubview:_functionDescriptorLabel];

		[_functionDescriptorLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
		[_functionDescriptorLabel.widthAnchor constraintEqualToConstant:kWidth].active = YES;
		[_functionDescriptorLabel.heightAnchor constraintEqualToConstant:25].active = YES;
		[_functionDescriptorLabel.topAnchor constraintEqualToAnchor:_container.topAnchor constant:22].active = YES;

		_functionDescriptorLabel.font = [UIFont systemFontOfSize:_functionDescriptorLabel.font.pointSize*.75 weight:-0.40];
		[_functionDescriptorLabel setUserInteractionEnabled:NO];
		[_functionDescriptorLabel setNumberOfLines:0];
		[_functionDescriptorLabel setText:[[self descriptionForFunction:function] firstObject]];
	}

	return self;
}

-(NSMutableArray *)descriptionForFunction:(NSString *)function{
	NSMutableArray *functionDescs = [NSMutableArray new];

	if([function isEqualToString:@"standard-backup"]){
		[functionDescs addObject:@"Excludes developer packages"];
	}
	else if([function isEqualToString:@"unfiltered-backup"]){
		[functionDescs addObject:@"Includes all packages"];
	}
	else if([function isEqualToString:@"latest-restore"]){
		[functionDescs addObject:@"The most recent backup"];
	}
	else if([function isEqualToString:@"specific-restore"]){
		[functionDescs addObject:@"A backup of your choosing"];
	}
	else{
	}

	return functionDescs;
}

@end
