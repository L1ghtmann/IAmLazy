#import <UIKit/UIKit.h>

@interface IALProgressViewController : UIViewController
@property (nonatomic) NSMutableArray *items;
@property (nonatomic) NSMutableArray *itemIcons;
@property (nonatomic) NSMutableArray *itemDescriptions;
@property (nonatomic) NSMutableArray *itemStatusIcons;
@property (nonatomic) NSMutableArray *itemStatusText;
@property (nonatomic, retain) UIActivityIndicatorView *loading;
-(instancetype)initWithPurpose:(NSInteger)purpose ofType:(NSInteger)type withFilter:(BOOL)filter;
@end
