#import <UIKit/UIKit.h>

@interface IALProgressViewController : UIViewController {
    NSMutableArray *_items;
    NSMutableArray *_itemIcons;
    NSMutableArray *_itemDescriptions;
    NSMutableArray *_itemStatusIcons;
    NSMutableArray *_itemStatusText;
    UIActivityIndicatorView *_loading;
}
-(instancetype)initWithPurpose:(NSInteger)purpose ofType:(NSInteger)type withFilter:(BOOL)filter;
@end
