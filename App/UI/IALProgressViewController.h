#import <UIKit/UIKit.h>

@interface IALProgressViewController : UIViewController {
    NSMutableArray<UIImageView *> *_items;
    NSMutableArray<NSString *> *_itemIcons;
    NSMutableArray<NSString *> *_itemDescriptions;
    NSMutableArray<UIView *> *_itemStatusIcons;
    NSMutableArray<UILabel *> *_itemStatusText;
    UIView *_titleContainer;
    UIView *_loadingContainer;
    UIStackView *_itemContainer;
    CAShapeLayer *_circleFill;
}
-(instancetype)initWithPurpose:(NSInteger)purpose withFilter:(BOOL)filter;
@end
