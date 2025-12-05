//
//  GKPhotoView+LivePhoto.m
//  GKPhotoBrowser
//
//  Created by QuintGao on 2024/6/21.
//

#import "GKPhotoView+LivePhoto.h"
#import "GKPhotoBrowser.h"

@interface GKLivePhotoMarkView()

@property (nonatomic, strong) UIImageView *liveImgView;

@property (nonatomic, strong) UILabel *liveLabel;

@property (nonatomic, strong) UIButton *tagAction;

@end

@implementation GKLivePhotoMarkView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self initUI];
    }
    return self;
}

- (void)initUI {
    [self addSubview:self.liveImgView];
    [self addSubview:self.liveLabel];
    [self addSubview:self.tagAction];
    [_tagAction addTarget:self action:@selector(tagPlayLiveAction) forControlEvents:UIControlEventTouchUpInside];
}
- (void)tagPlayLiveAction {
    if (self.playBlockAction) {
        self.playBlockAction();
    }
}
- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGRect frame = self.liveImgView.frame;
    frame.origin.x = 10;
    frame.origin.y = (self.frame.size.height - frame.size.height) / 2;
    self.liveImgView.frame = frame;
    
    frame = self.liveLabel.frame;
    frame.origin.x = CGRectGetMaxX(self.liveImgView.frame) + 5;
    frame.origin.y = (self.frame.size.height - frame.size.height) / 2;
    self.liveLabel.frame = frame;
    
    
    self.tagAction.frame = self.bounds;
    
}

#pragma mark - lazy
- (UIImageView *)liveImgView {
    if (!_liveImgView) {
        _liveImgView = [[UIImageView alloc] init];
        _liveImgView.image = GKPhotoBrowserImage(@"gk_photo_live");
        [_liveImgView sizeToFit];
    }
    return _liveImgView;
}

- (UILabel *)liveLabel {
    if (!_liveLabel) {
        _liveLabel = [[UILabel alloc] init];
        _liveLabel.font = [UIFont systemFontOfSize:12];
        _liveLabel.textColor = UIColor.whiteColor;
        _liveLabel.text = @"实况";
        [_liveLabel sizeToFit];
    }
    return _liveLabel;
}

- (UIButton *)tagAction {
    if (!_tagAction) {
        _tagAction = [UIButton buttonWithType:UIButtonTypeCustom];
    }
    return _tagAction;
}
@end

@implementation GKPhotoView (LivePhoto)

- (void)showLiveLoading {
    if (!self.livePhoto) return;
    self.loadingView.hidden = YES;
    self.liveLoadingView.frame = self.bounds;
    [self.liveLoadingView hideFailure];
    [self addSubview:self.liveLoadingView];
//    [self.liveLoadingView startLoading];
    if (self.configure.isShowLivePhotoMark) {
        [self addSubview:self.liveMarkView];
    }else {
        [self.liveMarkView removeFromSuperview];
    }
}

- (void)hideLiveLoading {
    if (!self.livePhoto) return;
    [self.liveLoadingView stopLoading];
}

- (void)showLiveFailure:(NSError *)error {
    if (!self.livePhoto) return;
}

- (void)liveDidScrollAppear {
    if (!self.livePhoto) return;

    if (!self.livePhoto.photo || self.livePhoto.photo != self.photo) {
        [self showLoading];
        __weak __typeof(self) weakSelf = self;
        if ([self.livePhoto respondsToSelector:@selector(setPhoto:)]) {
            self.livePhoto.photo = self.photo;
        }
        [self.livePhoto loadLivePhotoWithPhoto:self.photo targetSize:self.configure.liveTargetSize progressBlock:^(float progress) {
            __strong __typeof(weakSelf) self = weakSelf;
            dispatch_async(dispatch_get_main_queue(), ^{
                self.liveLoadingView.progress = progress;
                if (progress >= 1.0) {
                    [self hideLoading];
                    self.liveMarkView.hidden = NO;
                    self.liveMarkView.tag = 1;
                }
            });
        } completion:^(BOOL success,NSError * _Nullable error) {
            __strong __typeof(weakSelf) self = weakSelf;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    self.livePhoto.livePhotoView.hidden = NO;
                    [self adjustFrame];
                }else{
                    self.liveLoadingView.failText = self.configure.failureText;
                    //video is not local path
                    if ([error.userInfo.allKeys containsObject:@"NSLocalizedDescription"]) {
                        if ([[error.userInfo objectForKey:@"NSLocalizedDescription"] isEqualToString:@"image is not local path"] || [[error.userInfo objectForKey:@"NSLocalizedDescription"] isEqualToString:@"video is not local path"]) {
                            self.livePhoto.livePhotoView.hidden = YES;
                            self.imageView.hidden = YES;
                            self.photo.failed = YES;
                            self.photo.url = nil;
                            [self.liveLoadingView showFailure];
                        }else{
                           [self hideLoading];
                        }
                    }
                    self.liveMarkView.tag = 1001;
                    self.liveMarkView.hidden = YES;
                }
            });
        }];
    }else {
        if (self.photo.failed) {
            [self.liveLoadingView showFailure];
        }
//        [self.livePhoto gk_play];
    }
}

- (void)liveWillScrollDisappear {
    if (!self.livePhoto) return;
    if (!self.configure.isLivePhotoPausedWhenScrollBegan) return;
    [self.livePhoto gk_stop];
}
- (void)showNewShowLoading {
    self.loadingView.hidden = NO;
    [self.liveLoadingView startLoading];
}
- (void)hiddenNewLoading {
    [self hideLoading];
}
- (void)liveDidScrollDisappear {
    if (!self.livePhoto) return;
    [self.livePhoto liveDidScrollDisappear];
    [self.livePhoto gk_stop];
}

- (void)liveDidDismissAppear {
    if (!self.livePhoto) return;
    if (!self.configure.isShowLivePhotoMark) return;
    if (self.liveMarkView.tag != 1001) {
        self.liveMarkView.hidden = NO;
    }
}

- (void)liveWillDismissDisappear {
    if (!self.livePhoto) return;
    if (self.configure.isLivePhotoPausedWhenDragged) {
        [self.livePhoto gk_stop];
    }
    if (!self.configure.isShowLivePhotoMark) return;
    self.liveMarkView.hidden = YES;
}

- (void)liveDidDismissDisappear {
    if (!self.livePhoto) return;
    [self.livePhoto gk_stop];
    if (self.configure.isClearMemoryForLivePhoto && [self.livePhoto respondsToSelector:@selector(gk_clear)]) {
        [self.livePhoto gk_clear];
    }
}

- (void)liveUpdateFrame {
    if (!self.livePhoto) return;
    if (self.livePhoto.photo != self.photo) return;
    if (self.livePhoto.livePhotoView.superview != self.imageView) {
        [self.imageView addSubview:self.livePhoto.livePhotoView];
        self.imageView.userInteractionEnabled = YES;
    }
    [self.imageView bringSubviewToFront:self.livePhoto.livePhotoView];
    [self.livePhoto gk_updateFrame:self.imageView.bounds];
    if (self.liveMarkView.superview) {
        CGFloat y = CGRectGetMinY(self.imageView.frame) + 10;
        CGFloat H = CGRectGetHeight(self.frame);
        self.liveMarkView.frame = CGRectMake(16.f, self.frame.size.height - kSafeBottomSpace-32.f-16.f, 66.f, 32.f);
        if (self.imageView.frame.size.height > (self.frame.size.height - kSafeTopSpace - kSafeBottomSpace)) {
            CGPoint center = self.liveMarkView.center;
            center.x = (KIsiPhoneX && self.livePhoto.browser.isLandscape) ? (kSafeTopSpace + 16) : 16;
            center.y = H-32;
            self.liveMarkView.center = center;
        }
    }
}

@end
