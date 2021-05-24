#import <Preferences/PSTableCell.h>
#import <Preferences/PSSpecifier.h>

@interface IAmLazyPrefsCell : PSTableCell 
@property (nonatomic, retain) NSString *function;
@property (nonatomic, retain) UIImageView *functionIcon;
@property (nonatomic, retain) UILabel *label;	
@property (nonatomic, retain) NSString *purpose;
@end
