#import <UIKit/UIKit.h>

@interface IALTableViewCell : UITableViewCell
@property (nonatomic, retain) NSString *function;
@property (nonatomic, retain) UIImageView *functionIcon;
@property (nonatomic, retain) UIView *container;
@property (nonatomic, retain) UILabel *functionLabel;
@property (nonatomic, retain) NSString *functionDescriptor;
@property (nonatomic, retain) UILabel *functionDescriptorLabel;
-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier type:(NSString *)type function:(NSString *)function functionDescriptor:(NSString *)functionDescriptor;
@end
