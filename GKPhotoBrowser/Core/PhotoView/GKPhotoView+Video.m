//
//  GKPhotoView+Video.m
//  GKPhotoBrowser
//
//  Created by QuintGao on 2024/6/21.
//

#import "GKPhotoView+Video.h"
#import "GKPhotoBrowser.h"
#import <objc/runtime.h>

@implementation GKPhotoView (Video)

- (void)videoPlay {
    self.photo.isVideoClicked = YES;
    [self didScrollAppear];
}

- (void)videoPause {
    // Pause playback but keep player state so user can resume.
    if (!self.player) return;
    self.photo.isVideoClicked = NO;
    // show play button for resume
    if (self.configure.isShowPlayImage) {
        if (!self.playBtn.superview) {
            [self addSubview:self.playBtn];
            [self.playBtn sizeToFit];
            self.playBtn.center = CGPointMake(self.bounds.size.width * 0.5, self.bounds.size.height * 0.5);
        }
        self.playBtn.hidden = NO;
    }
    [self.player gk_pause];
}

- (void)showVideoLoading {
    if (!self.photo.isAutoPlay && !self.photo.isVideoClicked) return;
    if (!self.player) return;
    if (self.player.assetURL != self.photo.videoUrl) return;
    self.videoLoadingView.frame = self.bounds;
    [self addSubview:self.videoLoadingView];
    [self loadVideo:YES success:NO];
}

- (void)hideVideoLoading {
    if (!self.photo.isAutoPlay && !self.photo.isVideoClicked) return;
    if (!self.player) return;
    if (self.player.assetURL != self.photo.videoUrl) return;
    [self loadVideo:NO success:YES];
}

- (void)showVideoFailure:(NSError *)error {
    // Show failure UI and ensure any player resources are cleaned up for this view
    if (!self.photo.isAutoPlay && !self.photo.isVideoClicked) return;
    // show failure UI regardless of player state
    [self loadFailedWithError:error];
    [self loadVideo:NO success:NO];

    // Remove player view and clear asset to avoid black-screen when reused
    if (self.player) {
        [self.player gk_stop];
        // remove player view from imageView
        if (self.player.videoPlayView && self.player.videoPlayView.superview) {
            [self.player.videoPlayView removeFromSuperview];
        }
        // clear assetURL so future checks won't match stale url
        self.player.assetURL = nil;
    }

    // hide play button on video failure (keep failure text only)
    if (self.playBtn) {
        self.playBtn.hidden = YES;
    }
}

- (void)showVideoPlayBtn {
    if (!self.photo.isAutoPlay && !self.photo.isVideoClicked) return;
    if (!self.player) return;
    if (self.player.assetURL != self.photo.videoUrl) return;
    if (!self.configure.isShowPlayImage) return;
    self.playBtn.hidden = NO;
}

- (void)videoDidScrollAppear {
    if (!self.photo.isAutoPlay && !self.photo.isVideoClicked) {
        if (!self.playBtn.superview) {
            [self addSubview:self.playBtn];
            [self.playBtn sizeToFit];
            self.playBtn.center = CGPointMake(self.bounds.size.width * 0.5, self.bounds.size.height * 0.5);
        }
        self.playBtn.hidden = NO;
        return;
    }
    if (!self.player) return;

    // 如果没有设置，则设置播放内容
    if (!self.player.assetURL || self.player.assetURL != self.photo.videoUrl) {
        __weak __typeof(self) weakSelf = self;
        if ([self.player respondsToSelector:@selector(setPhoto:)]) {
            self.player.photo = self.photo;
        }
        [self.photo getVideo:^(NSURL * _Nullable url, NSError * _Nullable error) {
            __strong __typeof(weakSelf) self = weakSelf;
            if (!self) return;
            if (!self.player) return;
            if (error) {
                // show failure UI and cleanup player resources for this view
                [self loadFailedWithError:error];
                [self loadVideo:NO success:NO];
                if (self.player.videoPlayView && self.player.videoPlayView.superview) {
                    [self.player.videoPlayView removeFromSuperview];
                }
                self.player.assetURL = nil;
            } else {
                self.player.coverImage = self.imageView.image;
                self.player.assetURL = url;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (!self.player) return;
                    [self.player gk_prepareToPlay];
                    [self updateFrame];
                    [self.player gk_play];
                });
            }
        }];
    } else {
        // If the player has a matching assetURL but the playView is not attached, attach it.
        if (self.player.videoPlayView.superview != self.imageView) {
            [self.imageView addSubview:self.player.videoPlayView];
        }
        [self.player gk_play];
    }

    if (!self.configure.isShowPlayImage) return;
    if (!self.playBtn.superview) {
        [self addSubview:self.playBtn];
    }
    self.playBtn.hidden = YES;
}

- (void)videoWillScrollDisappear {
    if (!self.player) return;
    if (!self.configure.isVideoPausedWhenScrollBegan) return;
    if (!self.photo.isAutoPlay && !self.photo.isVideoClicked) {
        if (self.player.isPlaying) {
            [self.player gk_pause];
        }
        return;
    }
    [self.player gk_pause];
}

- (void)videoDidScrollDisappear {
    // Ensure player is fully stopped and cleaned up when view scrolls away to avoid black screens or leaked player layers
    if (!self.player) return;

    // If autoplay is disabled, treat disappear as a full stop and cleanup
    if (!self.photo.isAutoPlay) {
        if (self.photo.isVideoClicked) {
            self.photo.isVideoClicked = NO;
        }
        [self.player gk_stop];
        // remove player view
        if (self.player.videoPlayView && self.player.videoPlayView.superview) {
            [self.player.videoPlayView removeFromSuperview];
        }
        self.player.assetURL = nil;
        if (self.configure.isShowPlayImage) {
            if (!self.playBtn.superview) {
                [self addSubview:self.playBtn];
                [self.playBtn sizeToFit];
                self.playBtn.center = CGPointMake(self.bounds.size.width * 0.5, self.bounds.size.height * 0.5);
            }
            self.playBtn.hidden = NO;
        }
        return;
    }

    // For autoplay enabled, just pause but still ensure play button is visible if configured
    [self.player gk_pause];
    if (self.configure.isShowPlayImage) {
        if (!self.playBtn.superview) {
            [self addSubview:self.playBtn];
            [self.playBtn sizeToFit];
            self.playBtn.center = CGPointMake(self.bounds.size.width * 0.5, self.bounds.size.height * 0.5);
        }
        self.playBtn.hidden = NO;
    }
}

- (void)videoDidDismissAppear {
    if (!self.player) return;
    if (!self.configure.isVideoPausedWhenDragged) return;
    if (self.isPlayingWhenPan) {
        if (self.player.status == GKVideoPlayerStatusEnded) {
            [self.player gk_replay];
        }else {
            [self.player gk_play];
        }
        if (!self.configure.isShowPlayImage) return;
        self.playBtn.hidden = YES;
    }
}

- (void)videoWillDismissDisappear {
    if (!self.player) return;
    if (!self.configure.isVideoPausedWhenDragged) return;
    if (self.player.status == GKVideoPlayerStatusEnded) {
        if (!self.configure.isShowPlayImage) return;
        self.playBtn.hidden = YES;
    }else {
        if (self.player.isPlaying) {
            self.isPlayingWhenPan = YES;
            [self.player gk_pause];
        } else{
            self.isPlayingWhenPan = NO;
        }
    }
}

- (void)videoDidDismissDisappear {
    if (!self.player) return;
    [self.player gk_stop];
    if (self.player.videoPlayView && self.player.videoPlayView.superview) {
        [self.player.videoPlayView removeFromSuperview];
    }
    self.player.assetURL = nil;
}

- (void)videoUpdateFrame {
    if (self.photo.isVideo && self.configure.isShowPlayImage) {
        [self.playBtn sizeToFit];
        self.playBtn.center = CGPointMake(self.bounds.size.width * 0.5, self.bounds.size.height * 0.5);
    }
    if (!self.photo.isAutoPlay && !self.photo.isVideoClicked) return;
    if (!self.player) return;

    // If the player's asset doesn't match the current photo, remove any existing playView to avoid showing wrong content
    if (self.player.assetURL != self.photo.videoUrl) {
        if (self.player.videoPlayView && self.player.videoPlayView.superview) {
            [self.player.videoPlayView removeFromSuperview];
        }
        return;
    }

    if (self.player.videoPlayView.superview != self.imageView) {
        [self.imageView addSubview:self.player.videoPlayView];
        self.imageView.userInteractionEnabled = YES;
    }
    [self.imageView bringSubviewToFront:self.player.videoPlayView];
    [self.player gk_updateFrame:self.imageView.bounds];
}

- (void)loadVideo:(BOOL)isStart success:(BOOL)success {
    self.loadingView.hidden = YES;
    if (self.configure.videoLoadStyle == GKPhotoBrowserLoadStyleCustom) {
        if ([self.delegate respondsToSelector:@selector(photoView:loadStart:success:)]) {
            [self.delegate photoView:self loadStart:isStart success:success];
        }
    }else {
        if (isStart) {
            [self.videoLoadingView startLoading];
        }else {
            if (success) {
                [self.videoLoadingView stopLoading];
            }else {
                [self.videoLoadingView showFailure];
            }
        }
    }
}



static char kIsPlayingWhenPan;
- (void)setIsPlayingWhenPan:(BOOL)isPlayingWhenPan {
    objc_setAssociatedObject(self, &kIsPlayingWhenPan, @(isPlayingWhenPan), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isPlayingWhenPan {
    return [objc_getAssociatedObject(self, &kIsPlayingWhenPan) boolValue];
}

@end
