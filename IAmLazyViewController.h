#import <UIKit/UIKit.h>

@interface IAmLazyViewController : UIViewController
@property (nonatomic) int itemCount;
@property (nonatomic) NSMutableArray *items;
@property (nonatomic) NSMutableArray *itemIcons;
@property (nonatomic) NSMutableArray *itemDescriptions;
@property (nonatomic) NSMutableArray *itemStatusIcons;
@property (nonatomic) NSMutableArray *itemStatusText;
@property (nonatomic, retain) UIActivityIndicatorView *loading;
-(instancetype)initWithPurpose:(NSString *)purpose;
-(void)makeTitleWithPurpose:(NSString *)purpose;
-(NSMutableArray *)iconsForPurpose:(NSString *)purpose;
-(void)makeListWithItems:(int)count;
-(NSMutableArray *)itemDescriptionsForPurpose:(NSString *)purpose;
-(void)elaborateItemsList;
-(void)makeLoadingWheel;
@end
