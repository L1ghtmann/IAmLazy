#import <UIKit/UIKit.h>

@interface MTMaterialView : UIView
+(instancetype)materialViewWithRecipe:(long long)arg1 configuration:(long long)arg2 initialWeighting:(double)arg3 ;
@end

@interface IALHeaderView : UITableViewHeaderFooterView {
    MTMaterialView *_matView;
    UILabel *_subtitle;
}
@property (nonatomic, strong) UIButton *import;
-(instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier subtitle:(NSString *)subtitle andButtonImage:(UIImage *)img;
@end
