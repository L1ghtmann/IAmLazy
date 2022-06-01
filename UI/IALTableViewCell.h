#import <UIKit/UIKit.h>

@interface IALTableViewCell : UITableViewCell {
    UIImageView *_icon;
    UIView *_container;
    UILabel *_functionLabel;
    UILabel *_descriptorLabel;
}
-(instancetype)initWithIdentifier:(NSString *)identifier purpose:(NSInteger)purpose type:(NSInteger)type function:(NSInteger)function;
@end
