//
//  GKDefaultCoverView.m
//  GKPhotoBrowser
//
//  Created by QuintGao on 2024/12/11.
//

#import "GKDefaultCoverView.h"
#import "GKPhotoBrowser.h"

@interface GKDefaultCoverView()
@property (nonatomic, strong) UIButton *originalBtn; // 原图
@property (nonatomic, strong) UIButton *translateBtn; // 译图

@property (nonatomic, strong) UIButton *tipBtn; // 译图提示文字

@end
@implementation GKDefaultCoverView

#pragma mark - GKCoverViewProtocol
@synthesize browser;

- (void)addCoverToView:(UIView *)view {
    [view addSubview:self.countLabel];
    [view addSubview:self.pageControl];
    [view addSubview:self.saveBtn];
    [view addSubview:self.translateView];
    [view addSubview:self.tipBtn];

    self.pageControl.numberOfPages = self.browser.photos.count;
    CGSize size = [self.pageControl sizeForNumberOfPages:self.browser.photos.count];
    self.pageControl.bounds = CGRectMake(0, 0, size.width, size.height);
}

- (void)updateLayoutWithFrame:(CGRect)frame {
    CGFloat width = frame.size.width;
    CGFloat height = frame.size.height;
    
    CGFloat centerX = width * 0.5;
    CGFloat centerY = 0;
    if (self.browser.isLandscape) {
        centerY = height - 20;
    }else {
        centerY = height - 20 - (self.browser.configure.isAdaptiveSafeArea ? kSafeBottomSpace : 0);
    }
    
    self.countLabel.center = CGPointMake(centerX, (KIsiPhoneX && !self.browser.isLandscape) ? (kSafeTopSpace + 10) : 30);
    CGSize size = [self.pageControl sizeForNumberOfPages:self.browser.photos.count];
    self.pageControl.bounds = CGRectMake(0, 0, size.width, size.height);
    self.pageControl.center = CGPointMake(centerX, centerY);
    self.saveBtn.center = CGPointMake(width - 60, centerY);
    if (self.browser.configure.hidesPageControl) {
        self.pageControl.hidden = YES;
    }
    
    self.translateView.center = CGPointMake(centerX, (KIsiPhoneX && !self.browser.isLandscape) ? (kSafeTopSpace + 30) : 50);
    self.translateView.bounds = CGRectMake(0, 0, 97, 34);

    self.originalBtn.center = CGPointMake(25, 17);
    self.translateBtn.center = CGPointMake(25+48, 17);
}

- (void)updateCoverWithCount:(NSInteger)count index:(NSInteger)index {
    self.countLabel.text = [NSString stringWithFormat:@"%zd/%zd", (long)(index + 1), (long)count];
    self.pageControl.currentPage = index;
    if (!self.browser.configure.hidesTranslateView && index < self.browser.photos.count) {
        if (index == 0) {
            self.tipBtn.hidden = YES;
            [self.originalBtn setTitleColor:[UIColor colorWithRed:8/255.0 green:20/255.0 blue:42/255.0 alpha:1] forState:UIControlStateNormal];
            [self.originalBtn setBackgroundColor:[UIColor whiteColor]];
            [self.translateBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [self.translateBtn setBackgroundColor:[UIColor clearColor]];
        } else {
            self.tipBtn.hidden = NO;
            [self.originalBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [self.originalBtn setBackgroundColor:[UIColor clearColor]];
            [self.translateBtn setTitleColor:[UIColor colorWithRed:8/255.0 green:20/255.0 blue:42/255.0 alpha:1] forState:UIControlStateNormal];
            [self.translateBtn setBackgroundColor:[UIColor whiteColor]];
        }
    }
}

- (void)updateCoverWithPhoto:(GKPhoto *)photo {
    if (photo.isVideo) {
        self.countLabel.hidden = YES;
        self.pageControl.hidden = YES;
        self.saveBtn.hidden = YES;
    }else {
        if (self.browser.configure.hidesCountLabel) {
            self.countLabel.hidden = YES;
        }else {
            self.countLabel.hidden = self.browser.photos.count <= 1;
        }
        
        if (self.browser.configure.hidesPageControl) {
            self.pageControl.hidden = YES;
        }else {
            if (self.pageControl.hidesForSinglePage) {
                self.pageControl.hidden = self.browser.photos.count <= 1;
            }
        }
        self.saveBtn.hidden = self.browser.configure.hidesSavedBtn;
        self.translateView.hidden = self.browser.configure.hidesTranslateView;
        NSString *tipText = [NSString stringWithFormat:@"文A 已翻译 · %@", photo.extraInfo];
        [self.tipBtn setTitle:tipText forState:UIControlStateNormal];

        CGSize textSize = [tipText sizeWithAttributes:@{NSFontAttributeName:self.tipBtn.titleLabel.font}];
        CGFloat btnW = textSize.width + 16;
        CGFloat btnH = 28;
        self.tipBtn.frame = CGRectMake(0, (KIsiPhoneX && !self.browser.isLandscape) ? (kSafeTopSpace + 90) : 110, btnW, btnH);
    }
}

#pragma mark - action
- (void)saveBtnClick:(UIButton *)btn {
    if ([self.browser.delegate respondsToSelector:@selector(photoBrowser:onSaveBtnClick:image:)]) {
        [self.browser.delegate photoBrowser:self.browser onSaveBtnClick:self.browser.currentIndex image:self.browser.curPhotoView.imageView.image];
    }
}

/// 原图点击
-(void)originalBtnClick:(UIButton *)btn {
    [self.browser selectedPhotoWithIndex:0 animated:YES];
}

/// 译图点击
-(void)translateBtnClick:(UIButton *)btn {
    [self.browser selectedPhotoWithIndex:1 animated:YES];
}

#pragma mark - lazy
- (UILabel *)countLabel {
    if (!_countLabel) {
        UILabel *countLabel = [UILabel new];
        countLabel.textColor = UIColor.whiteColor;
        countLabel.font = [UIFont systemFontOfSize:16.0f];
        countLabel.textAlignment = NSTextAlignmentCenter;
        countLabel.bounds = CGRectMake(0, 0, 80, 30);
        countLabel.hidden = YES;
        _countLabel = countLabel;
    }
    return _countLabel;
}

- (UIPageControl *)pageControl {
    if (!_pageControl) {
        UIPageControl *pageControl = [UIPageControl new];
        pageControl.hidesForSinglePage = YES;
        pageControl.hidden = YES;
        pageControl.enabled = NO;
        if (@available(iOS 14.0, *)) {
            pageControl.backgroundStyle = UIPageControlBackgroundStyleMinimal;
        }
        _pageControl = pageControl;
    }
    return _pageControl;
}

- (UIButton *)saveBtn {
    if (!_saveBtn) {
        UIButton *saveBtn = [UIButton new];
        saveBtn.bounds = CGRectMake(0, 0, 50, 30);
        [saveBtn setTitle:@"保存" forState:UIControlStateNormal];
        [saveBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        saveBtn.titleLabel.font = [UIFont systemFontOfSize:15.0f];
        saveBtn.layer.cornerRadius = 5;
        saveBtn.layer.masksToBounds = YES;
        saveBtn.layer.borderColor = UIColor.whiteColor.CGColor;
        saveBtn.layer.borderWidth = 1;
        saveBtn.hidden = YES;
        [saveBtn addTarget:self action:@selector(saveBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        _saveBtn = saveBtn;
    }
    return _saveBtn;
}

- (UIView *)translateView {
    if (!_translateView) {
        UIView *translateView = [UIView new];
        translateView.bounds = CGRectMake(0, 0, 97, 34);
        translateView.backgroundColor = [UIColor colorWithRed:61/255.0 green:62/255.0 blue:61/255.0 alpha:1];
        translateView.hidden = YES;
        translateView.layer.cornerRadius = 5;
        translateView.layer.masksToBounds = YES;
        [translateView addSubview:self.originalBtn];
        [translateView addSubview:self.translateBtn];
        _translateView = translateView;
    }
    return _translateView;
}

- (UIButton *)originalBtn {
    if (!_originalBtn) {
        UIButton *originalBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        originalBtn.bounds = CGRectMake(0, 0, 44, 28);
        [originalBtn setTitle:@"原图" forState:UIControlStateNormal];
        [originalBtn setTitleColor:[UIColor colorWithRed:8/255.0 green:20/255.0 blue:42/255.0 alpha:1] forState:UIControlStateNormal];
        [originalBtn setBackgroundColor:[UIColor whiteColor]];
        originalBtn.titleLabel.font = [UIFont systemFontOfSize:12.0f weight:UIFontWeightMedium];
        [originalBtn addTarget:self action:@selector(originalBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        originalBtn.layer.cornerRadius = 2.5;
        originalBtn.layer.masksToBounds = YES;
        _originalBtn = originalBtn;
    }
    return _originalBtn;
}

- (UIButton *)translateBtn {
    if (!_translateBtn) {
        UIButton *translateBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        translateBtn.bounds = CGRectMake(48, 0, 44, 28);
        [translateBtn setTitle:@"译图" forState:UIControlStateNormal];
        [translateBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [translateBtn setBackgroundColor:[UIColor clearColor]];
        translateBtn.titleLabel.font = [UIFont systemFontOfSize:12.0f weight:UIFontWeightMedium];
        [translateBtn addTarget:self action:@selector(translateBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        translateBtn.layer.cornerRadius = 2.5;
        translateBtn.layer.masksToBounds = YES;
        _translateBtn = translateBtn;
    }
    return _translateBtn;
}

- (UIButton *)tipBtn {
    if (!_tipBtn) {
        UIButton *tipBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        tipBtn.bounds = CGRectMake(0, 0, 123, 23);
        [tipBtn setTitle:@"文A 已翻译 · English" forState:UIControlStateNormal];
        [tipBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [tipBtn setBackgroundColor:[UIColor colorWithRed:61/255.0 green:62/255.0 blue:61/255.0 alpha:1]];
        tipBtn.titleLabel.font = [UIFont systemFontOfSize:12.0f weight:UIFontWeightMedium];
        [tipBtn addTarget:self action:@selector(translateBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        tipBtn.layer.cornerRadius = 5;
        tipBtn.layer.masksToBounds = YES;
        tipBtn.hidden = YES;
        _tipBtn = tipBtn;
    }
    return _tipBtn;
}

@end
