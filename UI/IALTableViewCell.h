#import <UIKit/UIKit.h>

@interface IALTableViewCell : UITableViewCell
@property (nonatomic, retain) UIImageView *icon;
@property (nonatomic, retain) UIView *container;
@property (nonatomic, retain) UILabel *functionLabel;
@property (nonatomic, retain) UILabel *descriptorLabel;
-(instancetype)initWithIdentifier:(NSString *)identifier purpose:(NSInteger)purpose type:(NSInteger)type function:(NSInteger)function functionDescriptor:(NSString *)descriptor;
@end
