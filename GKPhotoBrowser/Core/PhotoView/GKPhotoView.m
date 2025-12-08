//
//  GKPhotoView.m
//  GKPhotoBrowser
//
//  Created by QuintGao on 2017/10/23.
//  Copyright © 2017年 QuintGao. All rights reserved.
//

#import "GKPhotoView.h"
#import "GKPhotoView+Image.h"
#import "GKPhotoView+Video.h"
#import "GKPhotoView+LivePhoto.h"
static NSString * const colorStrPrefix1 = @"0X";
static NSString * const colorStrPrefix2 = @"#";
@implementation GKScrollView

#pragma mark - UIGestureRecognizerDelegate
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.panGestureRecognizer) {
        if (gestureRecognizer.state == UIGestureRecognizerStatePossible) {
            if ([self isScrollViewOnTopOrBottom]) {
                return NO;
            }
        }
    }
    return YES;
}

// 判断是否滑动到顶部或底部
- (BOOL)isScrollViewOnTopOrBottom {
    CGPoint translation = [self.panGestureRecognizer translationInView:self];
    if (translation.y > 0 && self.contentOffset.y <= 0) {
        return YES;
    }
    CGFloat maxOffsetY = floor(self.contentSize.height - self.bounds.size.height);
    if (translation.y < 0 && self.contentOffset.y >= maxOffsetY) {
        return YES;
    }
    return NO;
}

@end

@interface GKPhotoView()

@property (nonatomic, strong) GKScrollView   *scrollView;

@property (nonatomic, strong) UIImageView    *imageView;

@property (nonatomic, strong) UIButton       *playBtn;

@property (nonatomic, strong) GKLoadingView  *loadingView;

@property (nonatomic, strong) GKLoadingView  *videoLoadingView;

@property (nonatomic, strong) GKLoadingView  *liveLoadingView;
@property (nonatomic, strong) GKLivePhotoMarkView *liveMarkView;

@property (nonatomic, strong) GKPhoto        *photo;

@end

@implementation GKPhotoView

- (instancetype)initWithFrame:(CGRect)frame configure:(GKPhotoBrowserConfigure *)configure {
    if (self = [super initWithFrame:frame]) {
        self.configure = configure;
        self.imager = configure.imager;
        self.player = configure.player;
        self.livePhoto = configure.livePhoto;
        self.backgroundColor = [UIColor clearColor];
        [self addSubview:self.scrollView];
        [self.scrollView addSubview:self.imageView];
    }
    return self;
}

- (void)dealloc {
    [self cancelImageLoad];
}

- (void)prepareForReuse {
    self.imageSize = CGSizeZero;

    [self.loadingView stopLoading];
    [self.loadingView removeFromSuperview];

    // remove play button from hierarchy (if any)
    [self.playBtn removeFromSuperview];

    [self.videoLoadingView stopLoading];
    [self.videoLoadingView removeFromSuperview];

    [self.liveLoadingView stopLoading];
    [self.liveLoadingView removeFromSuperview];

    [self cancelImageLoad];

    // Ensure video-related resources are cleaned up when the view is reused
    [self cleanupVideoResources];

    if (self.imager && [self.imager respondsToSelector:@selector(setPhoto:)]) {
        self.imager.photo = self.photo;
    }
    if (self.configure.isClearMemoryWhenViewReuse && [self.imager respondsToSelector:@selector(clearMemoryForURL:)]) {
        [self.imager clearMemoryForURL:self.photo.url];
    }

    [self.imageView removeFromSuperview];
    self.imageView = nil;

    [self.liveMarkView removeFromSuperview];
    self.liveMarkView = nil;
    
    self.livePhoto.livePhotoView.livePhoto = nil;
    // Reset the photo reference to avoid keeping stale state
    self.photo = nil;
}

- (void)resetImageView {
    [self.imageView removeFromSuperview];
    self.imageView = nil;
    [self.scrollView addSubview:self.imageView];
}

- (void)setupPhoto:(GKPhoto *)photo {
    _photo = photo;
    
    [self loadImageWithPhoto:photo isOrigin:NO];
}

- (void)setScrollMaxZoomScale:(CGFloat)scale {
    if (self.scrollView.maximumZoomScale != scale) {
        self.scrollView.maximumZoomScale = scale;
    }
}

- (void)showLoading {
    if (self.photo.isLivePhoto) {
        [self showLiveLoading];
    }else if (self.photo.isVideo) {
        [self showVideoLoading];
    }
}

- (void)hideLoading {
    if (self.photo.isLivePhoto) {
        [self hideLiveLoading];
    }else{
        [self hideVideoLoading];
    }
}

- (void)showFailure:(NSError *)error {
    if (self.photo.isLivePhoto) {
        [self showLiveFailure:error];
    }else if (self.photo.isVideo) {
        [self showVideoFailure:error];
    }
}

- (void)showPlayBtn {
    [self showVideoPlayBtn];
}

- (void)didScrollAppear {
    if (self.photo.isLivePhoto) {
        [self liveDidScrollAppear];
    }else if (self.photo.isVideo) {
        [self videoDidScrollAppear];
    }
}
- (void)updateLoadingStatus {
    if (self.isDownloadingLivePhoto) {
        [self showNewShowLoading];
    } else {
        [self hideLiveLoading];
    }
}
- (void)willScrollDisappear {
    if (self.photo.isLivePhoto) {
        [self liveWillScrollDisappear];
    }else if (self.photo.isVideo) {
        [self videoWillScrollDisappear];
    }
}

- (void)didScrollDisappear {
    // Prefer calling the explicit handlers for live photo / video
    if (self.photo.isLivePhoto) {
        [self liveDidScrollDisappear];
    } else if (self.photo.isVideo) {
        [self videoDidScrollDisappear];
    } else {
        // If the photo is nil or not a video/livePhoto, still ensure any lingering video state is cleared
        [self cleanupVideoResources];
    }
}

- (void)didDismissAppear {
    if (self.photo.isLivePhoto) {
        [self liveDidDismissAppear];
    }else if (self.photo.isVideo) {
        [self videoDidDismissAppear];
    }
}

- (void)willDismissDisappear {
    if (self.photo.isLivePhoto) {
        [self liveWillDismissDisappear];
    }else if (self.photo.isVideo) {
        [self videoWillDismissDisappear];
    }
}

- (void)didDismissDisappear {
    if (self.photo.isLivePhoto) {
        [self liveDidDismissDisappear];
    }else if (self.photo.isVideo) {
        [self videoDidDismissDisappear];
    }
}

- (void)updateFrame {
    if (self.photo.isLivePhoto) {
        [self liveUpdateFrame];
    }else if (self.photo.isVideo) {
        [self videoUpdateFrame];
    }
}

- (void)playAction {
    [self videoPlay];
}

- (void)pauseAction {
    [self videoPause];
}

- (void)resetFrame {
    CGFloat width  = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    BOOL isLandscape = width > height;
    
    if (self.configure.isAdaptiveSafeArea) {
        UIEdgeInsets insets = UIDevice.gk_safeAreaInsets;
        if (isLandscape) {
            if (self.configure.isFollowSystemRotation) {
                width -= (insets.left + insets.right);
            }else {
                width -= (insets.top + insets.bottom);
            }
        }else {
            height -= (insets.top + insets.bottom);
        }
    }
    self.scrollView.bounds = CGRectMake(0, 0, width, height);
    self.scrollView.center = CGPointMake(self.bounds.size.width * 0.5, self.bounds.size.height * 0.5);
    self.loadingView.frame = self.bounds;
    self.videoLoadingView.frame = self.bounds;
    self.liveLoadingView.frame = self.bounds;
    
    if (self.photo) {
        [self adjustFrame];
    }
}

- (void)cleanupVideoResources {
    // Stop playback and clear video related UI to avoid stale/black-screen states when the view is reused or recycled.
    @try {
        // If categories implement videoPause / videoDidScrollDisappear, call them to stop playback
        if ([self respondsToSelector:@selector(videoPause)]) {
            [self videoPause];
        }
        if ([self respondsToSelector:@selector(videoDidScrollDisappear)]) {
            [self videoDidScrollDisappear];
        }

        // Hide the play button if present
        if (self.playBtn) {
            self.playBtn.hidden = YES;
            [self.playBtn removeFromSuperview];
        }

        // Stop & remove video loading UI
        if (self.videoLoadingView) {
            [self.videoLoadingView stopLoading];
            [self.videoLoadingView removeFromSuperview];
        }
        if (self.loadingView && self.photo.isVideo) {
            [self.loadingView stopLoading];
            [self.loadingView removeFromSuperview];
        }

        // Remove any AV player layers that might remain on the imageView.layer
        Class avPlayerLayerClass = NSClassFromString(@"AVPlayerLayer");
        if (avPlayerLayerClass && self.imageView && self.imageView.layer.sublayers) {
            NSArray *sublayers = [self.imageView.layer.sublayers copy];
            for (CALayer *sublayer in sublayers) {
                if ([sublayer isKindOfClass:avPlayerLayerClass]) {
                    [sublayer removeFromSuperlayer];
                }
            }
        }

    } @catch (NSException *exception) {
        // defensively ignore any exception during cleanup
    }
}

#pragma mark - 调整frame
- (void)adjustFrame {
    [self adjustImageFrame];
}

- (CGPoint)centerOfScrollViewContent:(UIScrollView *)scrollView {
    CGFloat offsetX = (scrollView.bounds.size.width > scrollView.contentSize.width) ? (scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5 : 0;
    CGFloat offsetY = (scrollView.bounds.size.height > scrollView.contentSize.height) ? (scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5 : 0;
    CGPoint actualCenter = CGPointMake(scrollView.contentSize.width * 0.5 + offsetX, scrollView.contentSize.height * 0.5 + offsetY);
    return actualCenter;
}

- (void)zoomToRect:(CGRect)rect animated:(BOOL)animated {
    [self.scrollView zoomToRect:rect animated:animated];
}

#pragma mark - UIScrollViewDelegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (self.photo.isZooming && scrollView.zoomScale != 1.0f && (scrollView.isDragging || scrollView.isDecelerating)) {
        CGPoint offset = scrollView.contentOffset;
        if (offset.x < 0) offset.x = 0; // 处理快速滑动时的bug
        self.photo.zoomOffset = offset;
    }
    
    if (scrollView.zoomScale == 1.0f) {
        self.photo.offset = scrollView.contentOffset;
    }
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.imageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    self.imageView.center = [self centerOfScrollViewContent:scrollView];
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale {
    self.photo.zoomScale = scale;
    self.photo.isZooming = scale != 1;
    [self zoomEndedWithScale:scale];
    [self setScrollMaxZoomScale:self.realZoomScale];
}

#pragma mark - Private
- (void)zoomEndedWithScale:(CGFloat)scale {
    if ([self.delegate respondsToSelector:@selector(photoView:zoomEndedWithScale:)]) {
        [self.delegate photoView:self zoomEndedWithScale:scale];
    }
}

- (void)loadFailedWithError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(photoView:loadFailedWithError:)]) {
        [self.delegate photoView:self loadFailedWithError:error];
    }
}

#pragma mark - 懒加载
- (GKScrollView *)scrollView {
    if (!_scrollView) {
        _scrollView                      = [GKScrollView new];
        _scrollView.backgroundColor      = [UIColor clearColor];
        _scrollView.delegate             = self;
        _scrollView.clipsToBounds        = NO;
        _scrollView.multipleTouchEnabled = YES; // 多点触摸开启
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.showsHorizontalScrollIndicator = NO;
        if (@available(iOS 11.0, *)) {
            _scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        }
    }
    return _scrollView;
}

- (UIImageView *)imageView {
    if (!_imageView) {
        _imageView = self.imager ? [self.imager.imageViewClass new] : [UIImageView new];
        _imageView.frame = self.scrollView.bounds;
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    return _imageView;
}

- (UIButton *)playBtn {
    if (!_playBtn) {
        _playBtn = [[UIButton alloc] init];
        [_playBtn setImage:self.configure.videoPlayImage ?: GKPhotoBrowserImage(@"gk_video_play") forState:UIControlStateNormal];
        [_playBtn addTarget:self action:@selector(playAction) forControlEvents:UIControlEventTouchUpInside];
        _playBtn.hidden = YES;
        [_playBtn sizeToFit];
        _playBtn.center = CGPointMake(self.bounds.size.width * 0.5, self.bounds.size.height * 0.5);
    }
    return _playBtn;
}

- (GKLoadingView *)loadingView {
    if (!_loadingView) {
        _loadingView = [GKLoadingView loadingViewWithFrame:self.bounds style:(GKLoadingStyle)self.configure.loadStyle];
        _loadingView.failStyle   = self.configure.failStyle;
        _loadingView.lineWidth   = 3;
        _loadingView.radius      = 12;
        _loadingView.bgColor     = [UIColor blackColor];
        _loadingView.strokeColor = [UIColor whiteColor];
    }
    return _loadingView;
}

- (GKLoadingView *)videoLoadingView {
    if (!_videoLoadingView) {
        _videoLoadingView = [GKLoadingView loadingViewWithFrame:self.bounds style:(GKLoadingStyle)self.configure.videoLoadStyle];
        _videoLoadingView.failStyle = self.configure.videoFailStyle;
        _videoLoadingView.lineWidth = 3;
        _videoLoadingView.radius = 12;
        _videoLoadingView.bgColor = UIColor.blackColor;
        _videoLoadingView.strokeColor = UIColor.whiteColor;
    }
    return _videoLoadingView;
}

- (GKLoadingView *)liveLoadingView {
    if (!_liveLoadingView) {
        _liveLoadingView = [GKLoadingView loadingViewWithFrame:self.bounds style:(GKLoadingStyle)self.configure.liveLoadStyle];
        _liveLoadingView.lineWidth   = 3;
        _liveLoadingView.radius      = 12;
        _liveLoadingView.bgColor     = [UIColor grayColor];
        _liveLoadingView.strokeColor = [UIColor whiteColor];
    }
    return _liveLoadingView;
}
 
- (UIView *)liveMarkView {
    if (!_liveMarkView) {
        _liveMarkView = [[GKLivePhotoMarkView alloc] init];
        __weak typeof(self) weakSelf = self;
        _liveMarkView.playBlockAction = ^{
            __strong typeof(self) strongSelf = weakSelf;
            if (!weakSelf.livePhoto.isPlaying) {
                [weakSelf.livePhoto gk_play];
            }
        };
        _liveMarkView.backgroundColor = [self yh_colorWithHexString:@"#3C3A46"];
        _liveMarkView.hidden = YES;
        _liveMarkView.layer.cornerRadius = 16.f;
        _liveMarkView.layer.masksToBounds = YES;
    }
    return _liveMarkView;
}

-(UIColor *)yh_colorWithHexString:(NSString *)hexColor{
    // 替换空格&统一变大写
    NSString *colorStr = [[hexColor stringByReplacingOccurrencesOfString:@" " withString:@""] uppercaseString];
    // 替换头部
    if ([colorStr hasPrefix:colorStrPrefix1]) {
        colorStr = [colorStr stringByReplacingOccurrencesOfString:colorStrPrefix1 withString:@""];
    }
    if ([colorStr hasPrefix:colorStrPrefix2]) {
        colorStr = [colorStr stringByReplacingOccurrencesOfString:colorStrPrefix2 withString:@""];
    }
    // 检查字符串长度
    if (colorStr.length != 6) {
        return [UIColor clearColor];
    }
    NSRange range;
    range.location = 0;
    range.length = 2;
    //red
    NSString *redString = [colorStr substringWithRange:range];
    //green
    range.location = 2;
    NSString *greenString = [colorStr substringWithRange:range];
    //blue
    range.location = 4;
    NSString *blueString= [colorStr substringWithRange:range];
    
    // Scan values
    unsigned int red, green, blue;
    [[NSScanner scannerWithString:redString] scanHexInt:&red];
    [[NSScanner scannerWithString:greenString] scanHexInt:&green];
    [[NSScanner scannerWithString:blueString] scanHexInt:&blue];
    return [UIColor colorWithRed:((CGFloat)red/ 255.0f) green:((CGFloat)green/ 255.0f) blue:((CGFloat)blue/ 255.0f) alpha:1.0f];
}
@end
