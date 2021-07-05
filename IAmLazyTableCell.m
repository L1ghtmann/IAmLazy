#include "IAmLazyTableCell.h"
#import "Common.h"

// Lightmann
// Made during covid
// IAmLazy

@implementation IAmLazyTableCell

-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier{

	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];

	if (self){
		_function = specifier.properties[@"type"];
		_functionDescriptor = specifier.properties[@"text"];

		// icon setup
		// helpful link for available SFSymbols: https://github.com/cyanzhong/sf-symbols-online
		// note: SFSymbols' width and height aren't equal, so need to set the content mode accordingly
		if([_function isEqualToString:@"backup"]){
			_functionIcon = [[UIImageView alloc] initWithFrame:CGRectZero];
			[_functionIcon setImage:[UIImage systemImageNamed:@"plus.app"]];
			[_functionIcon setContentMode:UIViewContentModeScaleAspectFit];
		}
		else if([_function isEqualToString:@"restore"]){
			_functionIcon = [[UIImageView alloc] initWithFrame:CGRectZero];
			[_functionIcon setImage:[UIImage systemImageNamed:@"arrow.counterclockwise.circle"]];
			[_functionIcon setContentMode:UIViewContentModeScaleAspectFit];
		}
		else if([_function isEqualToString:@"export"]){
			_functionIcon = [[UIImageView alloc] initWithFrame:CGRectZero];
			[_functionIcon setImage:[UIImage systemImageNamed:@"tray.and.arrow.up.fill"]];
			[_functionIcon setContentMode:UIViewContentModeScaleAspectFit];
		}
		else if([_function isEqualToString:@"delete"]){
			_functionIcon = [[UIImageView alloc] initWithFrame:CGRectZero];
			[_functionIcon setImage:[UIImage systemImageNamed:@"trash.circle"]];
			[_functionIcon setContentMode:UIViewContentModeScaleAspectFit];
		}
		else{
			_functionIcon = nil;
		}

		if(_functionIcon){
			[self addSubview:_functionIcon];
			[_functionIcon setTranslatesAutoresizingMaskIntoConstraints:NO];
			[_functionIcon.widthAnchor constraintEqualToConstant:(kHeight/4.5)].active = YES;
			[_functionIcon.heightAnchor constraintEqualToConstant:(kHeight/4.5)].active = YES;
			[_functionIcon.centerXAnchor constraintEqualToAnchor:self.centerXAnchor].active = YES;
			[_functionIcon.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:-(cellHeight/8)+10].active = YES;
			[_functionIcon setUserInteractionEnabled:NO];
		}

		// label setup
		_label = [[UILabel alloc] initWithFrame:CGRectZero];
		[self addSubview:_label];

		[_label setTranslatesAutoresizingMaskIntoConstraints:NO];
		[_label.widthAnchor constraintEqualToConstant:kWidth].active = YES;
		[_label.heightAnchor constraintEqualToConstant:20].active = YES;
		[_label.centerXAnchor constraintEqualToAnchor:self.centerXAnchor].active = YES;
		[_label.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-(cellHeight/8)].active = YES;

		_label.font = [UIFont systemFontOfSize:_label.font.pointSize weight:0.40];
		[_label setTextAlignment:NSTextAlignmentCenter];
		[_label setUserInteractionEnabled:NO];
		[_label setText:_functionDescriptor];
	}

	return self;
}

-(void)setBackgroundColor:(UIColor *)color{
	[super setBackgroundColor:[self accordingToInterfaceStyle]];
}

-(UIColor *)accordingToInterfaceStyle{
	if(self.traitCollection.userInterfaceStyle == 2){ // dark mode enabled
		return [UIColor colorWithRed:16.0f/255.0f green:16.0f/255.0f blue:16.0f/255.0f alpha:1.0f];
	}
	else{
		return [UIColor colorWithRed:247.0f/255.0f green:249.0f/255.0f blue:250.0f/255.0f alpha:1.0];
	}
}

@end
