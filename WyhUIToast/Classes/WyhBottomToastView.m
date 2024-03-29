//
//  WyhBottomToastView.m
//  Arm
//
//  Created by Michael Wu on 2019/4/9.
//  Copyright © 2019 iTalkBB. All rights reserved.
//

#import "WyhBottomToastView.h"
#import "NSBundle+WyhUIToast.h"
#import "WyhUIToastStyle.h"

#import <Masonry/Masonry.h>

static CGFloat const kAnimationShowDuration = 0.5f;
static CGFloat const kAnimationDismissDuration = 0.25f;
NSTimeInterval const kDefaultDismissDuration = 3.0f;
static CGFloat kBottomBaseOnOffsetY;

#define kScreenMaxSide       (MAX([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height))
#define kScreenMinSide       (MIN([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height))
#define kScreenScaleTo6 (kScreenMinSide/375.f)
#define kSizeBasedOnIPhone6(float)      ((float)*kScreenScaleTo6)

@interface WyhBottomToastView ()

@property (nonatomic, strong) WyhUIToastStyle *style;

@property (nonatomic, weak) id<WyhBottomToastViewDelegate> delegate;

@property (nonatomic, assign) BOOL isAlreadyShow;
@property (nonatomic, assign) BOOL isAnimating;

@property (nonatomic, assign) NSString *message;
@property (nonatomic, assign) WyhBottomToastViewType type;
@property (nonatomic, assign) WyhBottomToastViewAccessoryType accessoryType;
@property (nonatomic, assign) WyhBottomToastViewDismissMode dismissMode;
@property (nonatomic, assign) NSTimeInterval dismissDuration;

@property (nonatomic, strong) UIView *windowBlackCoverView;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIImageView *tipImageView;
@property (nonatomic, strong) UILabel *tipLabel;
@property (nonatomic, strong) UIView *alphaBackgroundView;
@property (nonatomic, strong) UIImageView *accessoryView;


@property (nonatomic, strong) UITapGestureRecognizer *actionTapGestrueRecognizer;

@end

@implementation WyhBottomToastView

#define kOffsetX 20.f

#pragma mark - Initialize

+ (void)initialize {
    kBottomBaseOnOffsetY = kSizeBasedOnIPhone6(70.f);
}

- (instancetype)reset {
    _type = WyhBottomToastViewTypeUnknown;
    _accessoryType = WyhBottomToastViewAccessoryTypeNone;
    _dismissMode = WyhBottomToastViewDismissModeDuration;
    _dismissDuration = kDefaultDismissDuration;
    
    if ([self.gestureRecognizers containsObject:_actionTapGestrueRecognizer]) {
        [self removeGestureRecognizer:_actionTapGestrueRecognizer];
    }
    _actionTapGestrueRecognizer = nil;
    return self;
}

#pragma mark - API

- (instancetype)initWithMessage:(NSString *)msg
                          style:(WyhUIToastStyle *)style
                           type:(WyhBottomToastViewType)type
                  accessoryType:(WyhBottomToastViewAccessoryType)accessoryType
                    dismissMode:(WyhBottomToastViewDismissMode)dismissMode
                       duration:(NSTimeInterval)duration
                       delegate:(id<WyhBottomToastViewDelegate>)delegate {
    
    if (self = [super init]) {
        _style = style;
        _delegate = delegate;
        _message = msg;
        _type = type;
        _accessoryType = accessoryType;
        _dismissMode = dismissMode;
        if (dismissMode == WyhBottomToastViewDismissModeDuration) {
            _dismissDuration = duration;
        }
    }
    [self reconfigUI];
    
    return self;
}

+ (instancetype)showToastWithMessage:(NSString *)msg
                               style:(WyhUIToastStyle *)style
                                type:(WyhBottomToastViewType)type
                       accessoryType:(WyhBottomToastViewAccessoryType)accessoryType
                         dismissMode:(WyhBottomToastViewDismissMode)dismissMode
                            duration:(NSTimeInterval)duration
                            delegate:(id<WyhBottomToastViewDelegate>)delegate {
    
    WyhBottomToastView *Toast = [[WyhBottomToastView alloc] initWithMessage:msg
                                                                      style:style
                                                                       type:type
                                                              accessoryType:accessoryType
                                                                dismissMode:dismissMode
                                                                   duration:duration
                                                                   delegate:delegate];
    [Toast show];
    return Toast;
}

- (void)updateStatusWithMessage:(NSString *)msg
                           type:(WyhBottomToastViewType)type
                  accessoryType:(WyhBottomToastViewAccessoryType)accessoryType
                    dismissMode:(WyhBottomToastViewDismissMode)dismissMode
                       duration:(NSTimeInterval)duration {
    
    if (!self.isAlreadyShow) {
        return;
    }
    
    _tipLabel.text = msg;
    
    // icon
    if (type == WyhBottomToastViewTypeLoading) {
        [_loadingIndicator startAnimating];
        _tipImageView.hidden = YES;
    }else {
        [_loadingIndicator stopAnimating];
        _tipImageView.image = [self private_getImageFromType:type];
        
        // zoomin if last type is loading
        if (_type == WyhBottomToastViewTypeLoading) {
            
            _tipImageView.transform = CGAffineTransformIdentity;
            [UIView animateWithDuration:0.2 animations:^{
                self.tipImageView.transform = CGAffineTransformMakeScale(1.2f, 1.2f);
                self.tipImageView.transform = CGAffineTransformIdentity;
            }];
        }
    }
    
    // accessory
    _accessoryView.hidden = (accessoryType == WyhBottomToastViewAccessoryTypeActionable) ? NO : YES;
    [_tipLabel  mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(_contentView.mas_top).offset(15);
        make.left.equalTo(_tipImageView.mas_right).offset(12);
        if (!_accessoryView.hidden) {
            make.right.equalTo(_accessoryView.mas_left).offset(-15);
        }else {
            make.right.equalTo(_contentView.mas_right).offset(-20);
        }
    }];
    
    // dismiss
    if (dismissMode == WyhBottomToastViewDismissModeNerver) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
    }else {
        [self performSelector:@selector(dismiss) withObject:nil afterDelay:kDefaultDismissDuration];
    }
    
    [self autoFitToastViewBounds];
    
}

#pragma mark - Method

- (void)show {
    
    if (_isAlreadyShow || _isAnimating) {
        return;
    }
    
    _isAlreadyShow = YES;
    _isAnimating = YES;
    
    // show in main thread
    [self performInMainThread:^{
        
        if (self.type == WyhBottomToastViewTypeLoading) {
            [self.loadingIndicator startAnimating];
        }else {
            [self.loadingIndicator stopAnimating];
        }
        
        // will show call back
        if ([self.delegate respondsToSelector:@selector(bottomToastViewWillShow:)]) {
            [self.delegate bottomToastViewWillShow:self];
        }
        
        [[UIApplication sharedApplication].keyWindow addSubview:self];
        
        CGRect frame = self.frame;
        frame.origin.y = kScreenMaxSide;
        self.frame = frame;
        
        [UIView animateWithDuration:kAnimationShowDuration delay:0.f usingSpringWithDamping:0.5 initialSpringVelocity:0 options:(UIViewAnimationOptionCurveEaseInOut) animations:^{
            
            CGRect frame = self.frame;
            frame.origin.y = kScreenMaxSide - self.bounds.size.height - kBottomBaseOnOffsetY;
            self.frame = frame;
            
        } completion:^(BOOL finished) {
            self->_isAnimating = NO;
            // did show call back
            if ([self.delegate respondsToSelector:@selector(bottomToastViewDidShow:)]) {
                [self.delegate bottomToastViewDidShow:self];
            }
        }];
        
    }];
    
    if (_dismissMode == WyhBottomToastViewDismissModeDuration) {
        [self performSelector:@selector(dismiss) withObject:nil afterDelay:_dismissDuration];
    }
    
}

- (void)dismiss {
    
    [self dismissComplete:nil];
}

- (void)dismissComplete:(void(^)(void))completion {
    
    if (!_isAlreadyShow) {
        // Toast already will dimiss , don't perform twice dismiss!
        return;
    }
    
    if (_isAnimating) {
        return;
    }
    
    _isAnimating = YES;
    
    if ([self.delegate respondsToSelector:@selector(bottomToastViewWillDismiss:)]) {
        [self.delegate bottomToastViewWillDismiss:self];
    }
    
    [self performInMainThread:^{
        
        [UIView animateWithDuration:kAnimationDismissDuration animations:^{
            
            CGRect frame = self.frame;
            frame.origin.y = kScreenMaxSide;
            self.frame = frame;
            
        } completion:^(BOOL finished) {
            
            self->_isAlreadyShow = NO;
            self->_isAnimating = NO;
            [self removeFromSuperview];
            [self reset];
            // call back
            if ([self.delegate respondsToSelector:@selector(bottomToastViewDidDismiss:)]) {
                [self.delegate bottomToastViewDidDismiss:self];
            }
            if(completion) completion();
        }];
        
    }];
    
}

#pragma mark - Event

- (void)tapToastAction:(UITapGestureRecognizer *)tap {
    
    if ([self.delegate respondsToSelector:@selector(bottomToastViewDidClickAccessory:)]) {
        [self.delegate bottomToastViewDidClickAccessory:self];
    }
    
    [self performSelector:@selector(dismiss) withObject:nil afterDelay:1.f]; // dismiss after 1s
}

#pragma mark - Private

- (void)performInMainThread:(void(^)(void))performBlock {
    
    if ([NSThread isMainThread]) {
        performBlock();
    }else {
        dispatch_async(dispatch_get_main_queue(), ^{
            performBlock();
        });
    }
}

- (UIImage *)private_getImageFromType:(WyhBottomToastViewType)type {
    UIImage *image ;
    switch (type) {
        case WyhBottomToastViewTypeUnknown:
        case WyhBottomToastViewTypeLoading:
        {
            return nil;
        }
            break;
        case WyhBottomToastViewTypeWarning:
        {
            image = _style.warningImage ? : [NSBundle wyhGetImageFromBundleWithImageName:@"img_flag_warning"];
        }
            break;
        case WyhBottomToastViewTypeInformation:
        {
            image = _style.infoImage ? : [NSBundle wyhGetImageFromBundleWithImageName:@"img_flag_info"];
        }
            break;
        case WyhBottomToastViewTypeSuccess:
        {
            image = _style.successImage ? : [NSBundle wyhGetImageFromBundleWithImageName:@"img_flag_success"];
        }
            break;
        default:
            break;
    }
    return image;
}

#pragma mark - UI

- (void)reconfigUI {
    
    NSAssert(_type != WyhBottomToastViewTypeUnknown, @"unknown type !");
    NSAssert(_message.length != 0, @"message is null !");
    
    CGFloat offsetX = kSizeBasedOnIPhone6(20);
    
    self.frame = CGRectMake(offsetX, kScreenMaxSide, kScreenMinSide - 2*offsetX, 0);
    self.layer.masksToBounds = YES;
    self.layer.cornerRadius = 12.f;
    
    _alphaBackgroundView = ({
        UIView *alpha = [[UIView alloc]init];
        alpha.backgroundColor = [_style.toastBackgroundColor colorWithAlphaComponent:_style.toastBackgroundAlpha];        
        [self addSubview:alpha];
        [alpha mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self);
        }];
        alpha;
    });
    
    _contentView = ({
        UIView *content = [[UIView alloc]init];
        [self addSubview:content];
        [content mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.left.right.equalTo(self);
        }];
        content;
    });
    
    _tipImageView = ({
        UIImageView *imageView = [[UIImageView alloc]init];
        if (_type == WyhBottomToastViewTypeLoading) {
            imageView.hidden = YES;
        }else {
            imageView.image = [self private_getImageFromType:_type];
        }
        [_contentView addSubview:imageView];
        [imageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(_contentView.mas_left).offset(15);
            make.centerY.equalTo(_contentView.mas_centerY);
            make.size.mas_equalTo(CGSizeMake(kSizeBasedOnIPhone6(24.f), kSizeBasedOnIPhone6(24.f)));
        }];
        imageView;
    });
    
    _loadingIndicator = ({
        UIActivityIndicatorView *hud = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:(UIActivityIndicatorViewStyleWhite)];
        hud.hidesWhenStopped = YES;
        [_contentView addSubview:hud];
        [hud mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerX.equalTo(_tipImageView.mas_centerX);
            make.centerY.equalTo(_tipImageView.mas_centerY);
        }];
        hud;
    });
    
    _accessoryView = ({
        
        UIImageView *imageView = [[UIImageView alloc]init];
        imageView.image = [NSBundle wyhGetImageFromBundleWithImageName:@"img_action_arrow"];
        [_contentView addSubview:imageView];
        [imageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(_contentView.mas_right).offset(-15);
            make.centerY.equalTo(_contentView.mas_centerY);
            make.size.mas_equalTo(CGSizeMake(kSizeBasedOnIPhone6(10), kSizeBasedOnIPhone6(16)));
        }];
        if (_accessoryType == WyhBottomToastViewAccessoryTypeActionable) {
            imageView.hidden = NO;
        }else {
            imageView.hidden = YES;
        }
        // add tap gesture
        _actionTapGestrueRecognizer = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapToastAction:)];
        [self addGestureRecognizer:_actionTapGestrueRecognizer];
        
        imageView;
    });
    
    _tipLabel = ({
        UILabel *label = [[UILabel alloc]init];
        label.text = _message;
        label.numberOfLines = 5;
        label.textColor = UIColor.whiteColor;
        label.font = [UIFont systemFontOfSize:15.f];
        [_contentView addSubview:label];
        [label mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(_contentView.mas_top).offset(15);
            make.left.equalTo(_tipImageView.mas_right).offset(12);
            if (!_accessoryView.hidden) {
                make.right.equalTo(_accessoryView.mas_left).offset(-15);
            }else {
                make.right.equalTo(_contentView.mas_right).offset(-20);
            }          
        }];
        label;
    });
    
    [self autoFitToastViewBounds];
}

- (void)autoFitToastViewBounds {
    
    [self layoutIfNeeded];
    
    CGFloat height = CGRectGetMaxY(_tipLabel.frame) + 15;
    
    [_contentView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.offset(height);
    }];
    
    self.bounds = CGRectMake(0, 0, self.bounds.size.width, height);
}


@end
