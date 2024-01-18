//
//	IALHeaderView.m
//	IAmLazy
//
//	Created by Lightmann in 2024
//

#import "IALHeaderView.h"
#import <objc/runtime.h>

@implementation IALHeaderView

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier subtitle:(NSString *)subtitle andButtonImage:(UIImage *)img {
    self = [super initWithReuseIdentifier:reuseIdentifier];

    if (self) {
        _matView = [objc_getClass("MTMaterialView") materialViewWithRecipe:2 configuration:1 initialWeighting:0.25];
        [self setBackgroundView:_matView];

        _subtitle = [[UILabel alloc] init];
        [_subtitle setText:subtitle];
        [_subtitle setFont:[UIFont systemFontOfSize:_subtitle.font.pointSize weight:UIFontWeightLight]];
        [self.contentView addSubview:_subtitle];

        if(img){
            _import = [UIButton buttonWithType:UIButtonTypeSystem];
            [_import setImage:img forState:UIControlStateNormal];
            [_import setTintColor:_subtitle.textColor];
            [self.contentView addSubview:_import];
        }
    }

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    [self.textLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    [[self.textLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:15] setActive:YES];
    [[self.textLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:15] setActive:YES];

    [_subtitle setTranslatesAutoresizingMaskIntoConstraints:NO];
    [[_subtitle.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:15] setActive:YES];
    [[_subtitle.bottomAnchor constraintEqualToAnchor:self.textLabel.topAnchor constant:5] setActive:YES];

    if(_import){
        [_import setTranslatesAutoresizingMaskIntoConstraints:NO];
        [[_import.widthAnchor constraintEqualToConstant:50] setActive:YES];
        [[_import.heightAnchor constraintEqualToConstant:50] setActive:YES];
        [[_import.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-5] setActive:YES];
        [[_import.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:5] setActive:YES];
    }
}

-(UILabel *)textLabel{
    UILabel *label = [super textLabel];
    [label setTextColor:[UIColor labelColor]];
    [label setFont:[UIFont systemFontOfSize:30 weight:UIFontWeightHeavy]];
    return label;
}

@end
