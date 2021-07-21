#include "IALTableViewCell.h"
#import "Common.h"

// Lightmann
// Made during covid
// IAmLazy

@implementation IALTableViewCell

-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier function:(NSString *)function functionDescriptor:(NSString *)functionDescriptor{

	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];

	if (self){
		// icon setup
		// helpful link for available SFSymbols: https://github.com/cyanzhong/sf-symbols-online
		// note: SFSymbols' width and height aren't equal, so need to set the content mode accordingly
		if([function isEqualToString:@"backup"]){
			_functionIcon = [[UIImageView alloc] initWithFrame:CGRectZero];
			[_functionIcon setImage:[UIImage systemImageNamed:@"plus.app"]];
			[_functionIcon setContentMode:UIViewContentModeScaleAspectFit];
		}
		else if([function isEqualToString:@"restore"]){
			_functionIcon = [[UIImageView alloc] initWithFrame:CGRectZero];
			[_functionIcon setImage:[UIImage systemImageNamed:@"arrow.counterclockwise.circle"]];
			[_functionIcon setContentMode:UIViewContentModeScaleAspectFit];
		}
		else if([function isEqualToString:@"export"]){
			_functionIcon = [[UIImageView alloc] initWithFrame:CGRectZero];
			[_functionIcon setImage:[UIImage systemImageNamed:@"tray.and.arrow.up.fill"]];
			[_functionIcon setContentMode:UIViewContentModeScaleAspectFit];
		}
		else if([function isEqualToString:@"delete"]){
			_functionIcon = [[UIImageView alloc] initWithFrame:CGRectZero];
			[_functionIcon setImage:[UIImage systemImageNamed:@"trash.circle"]];
			[_functionIcon setContentMode:UIViewContentModeScaleAspectFit];
		}
		else{
			_functionIcon = nil;
		}

		if(_functionIcon){
			[self addSubview:_functionIcon];

			[_functionIcon setUserInteractionEnabled:NO];

			[_functionIcon setTranslatesAutoresizingMaskIntoConstraints:NO];
			[_functionIcon.widthAnchor constraintEqualToConstant:(kHeight/3.5)].active = YES;
			[_functionIcon.heightAnchor constraintEqualToConstant:(kHeight/3.5)].active = YES;
			[_functionIcon.centerXAnchor constraintEqualToAnchor:self.centerXAnchor].active = YES;
			[_functionIcon.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:-(cellHeight/7)+10].active = YES;
		}

		// label setup
		_label = [[UILabel alloc] initWithFrame:CGRectZero];
		[self addSubview:_label];

		[_label setTranslatesAutoresizingMaskIntoConstraints:NO];
		[_label.widthAnchor constraintEqualToConstant:kWidth].active = YES;
		[_label.heightAnchor constraintEqualToConstant:20].active = YES;
		[_label.centerXAnchor constraintEqualToAnchor:self.centerXAnchor].active = YES;
		[_label.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-(cellHeight/8)].active = YES;

		_label.font = [UIFont systemFontOfSize:_label.font.pointSize*1.25 weight:0.40];
		[_label setTextAlignment:NSTextAlignmentCenter];
		[_label setUserInteractionEnabled:NO];
		[_label setText:functionDescriptor];
	}

	return self;
}

@end
