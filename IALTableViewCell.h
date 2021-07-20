#import <UIKit/UIKit.h>

@interface IALTableViewCell : UITableViewCell
-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier function:(NSString *)function functionDescriptor:(NSString *)functionDescriptor;
@property (nonatomic, retain) NSString *function;
@property (nonatomic, retain) UIImageView *functionIcon;
@property (nonatomic, retain) UILabel *label;
@property (nonatomic, retain) NSString *functionDescriptor;
@end
