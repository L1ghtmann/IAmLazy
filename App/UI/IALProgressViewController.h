#import <UIKit/UIKit.h>

@interface IALProgressViewController : UITableViewController {
    NSMutableArray<NSString *> *_itemDescriptions;
    NSMutableArray<UIView *> *_itemStatusIndicators;
    NSMutableArray<UILabel *> *_itemStatusText;
    NSString *_purpose;
    BOOL _debug;
    CAShapeLayer *_circleFill;
}
-(instancetype)initWithPurpose:(NSInteger)purpose withFilter:(BOOL)filter;
@end
