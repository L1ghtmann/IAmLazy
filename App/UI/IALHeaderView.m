#import "IALHeaderView.h"
#import <objc/runtime.h>

@implementation IALHeaderView

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithReuseIdentifier:reuseIdentifier];

    if (self) {
        _matView = [objc_getClass("MTMaterialView") materialViewWithRecipe:2 configuration:1 initialWeighting:0.25];
        [self setBackgroundView:_matView];

        _subtitle = [[UILabel alloc] init];
        // TODO: localize
        [_subtitle setText:@"Swipe or tap desired backup"];
        [_subtitle setFont:[UIFont systemFontOfSize:_subtitle.font.pointSize weight:UIFontWeightLight]];
        [self.contentView addSubview:_subtitle];

        _import = [UIButton buttonWithType:UIButtonTypeSystem];
        [_import setImage:[UIImage systemImageNamed:@"plus.circle.fill"] forState:UIControlStateNormal];
        [_import setTintColor:_subtitle.textColor];
        [self.contentView addSubview:_import];
    }

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    [self.textLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    [[self.textLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:25] setActive:YES];
    [[self.textLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:15] setActive:YES];

    [_subtitle setTranslatesAutoresizingMaskIntoConstraints:NO];
    [[_subtitle.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:15] setActive:YES];
    [[_subtitle.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10] setActive:YES];

    [_import setTranslatesAutoresizingMaskIntoConstraints:NO];
    [[_import.widthAnchor constraintEqualToConstant:50] setActive:YES];
    [[_import.heightAnchor constraintEqualToConstant:50] setActive:YES];
    [[_import.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-5] setActive:YES];
    [[_import.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor] setActive:YES];
}

-(UILabel *)textLabel{
    UILabel *label = [super textLabel];
    [label setTextColor:[UIColor labelColor]];
    [label setFont:[UIFont systemFontOfSize:30 weight:UIFontWeightHeavy]];
    return label;
}

@end
