//
//  VideoView.m
//  AVPlayerDemo
//
//  Created by lizhongfei on 28/7/17.
//  Copyright © 2017年 lizhongfei. All rights reserved.
//

#import "VideoView.h"
#import "MySlider.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MPVolumeView.h>

typedef enum  {
    ChangeNone,
    ChangeVoice,
    ChangeLigth,
    ChangeCMTime
}Change;


@interface VideoView ()

@property (nonatomic ,readwrite) AVPlayerItem *item;

@property (nonatomic ,readwrite) AVPlayerLayer *playerLayer;

@property (nonatomic ,readwrite) AVPlayer *player;
//AVPlayer的time Observer
@property (nonatomic ,strong)  id timeObser;
//视频总长度
@property (nonatomic ,assign) float videoLength;
//这个是记录要控制的哪种属性（音量、亮度、快进/快退）的枚举
@property (nonatomic ,assign) Change changeKind;
//上次的点坐标
@property (nonatomic ,assign) CGPoint lastPoint;
//在监测播放进度时是否复制给slider
@property (nonatomic, assign) BOOL shouldFlushSlider;
//播放和暂停按钮
@property (nonatomic,strong)UIButton * playAndPauseButton;
//右下角的全屏箭头
@property (nonatomic,strong)UIButton * fullScreenButton;
//滑动slider控制进度
@property (nonatomic ,strong) MySlider *videoSlider;
//显示下载进度的进度条
@property (nonatomic,strong) UIProgressView * progressView;
//显示总长度和播放时间
@property (nonatomic,strong) UILabel * playTimeAndResttime;

//Gesture
@property (nonatomic ,strong) UIPanGestureRecognizer *panGesture;
@property (nonatomic,strong) UITapGestureRecognizer * tapGesture;
@property (nonatomic ,strong) MPVolumeView *volumeView;
@property (nonatomic ,weak) UISlider *volumeSlider;
@property (nonatomic ,strong) UIView *darkView;
@end

@implementation VideoView

- (id)initWithUrl:(NSString *)path delegate:(id<VideoSomeDelegate>)delegate {
    if (self = [super init]) {
        _playerUrl = path;
        _someDelegate = delegate;
        [self setBackgroundColor:[UIColor blackColor]];
        //player
        [self setUpPlayer];
        //添加单击手势之后显示出来的控制视频播放相关的view
        [self addTapGesControlView];
        //左侧控制透明度的蒙层view
        [self addSwipeView];
        
    }
    return self;
}
- (void)setUpPlayer {
    NSURL *url = [NSURL URLWithString:_playerUrl];
    NSLog(@"%@",url);
    _item = [[AVPlayerItem alloc] initWithURL:url];
    _player = [AVPlayer playerWithPlayerItem:_item];
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
    _playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    /**
     AVLayerVideoGravityResizeAspect 1.保持纵横比；适合层范围内
     
     AVLayerVideoGravityResizeAspectFill 2.保持纵横比；填充层边界
     
     AVLayerVideoGravityResize 3.拉伸填充层边界
     */
    [self.layer addSublayer:_playerLayer];
    
    [self addVideoKVO];
    [self addVideoTimerObserver];
    [self addVideoNotic];
}
//拖动slider到视频的指定进度
- (void)seekValue:(float)value {
    
    _shouldFlushSlider = NO;
    
    float toBeTime = value *_videoLength;
    
    [_player seekToTime:CMTimeMake(toBeTime, 1) completionHandler:^(BOOL finished) {
        
        NSLog(@"seek Over finished:%@",finished ? @"success ":@"fail");
        
        _shouldFlushSlider = finished;
        
    }];
    
}
- (void)stop {
    
    [self removeVideoTimerObserver];
    
    [self removeVideoNotic];
    
    [self removeVideoKVO];
    
    [_player pause];
    
    [_playerLayer removeFromSuperlayer];
    
    _playerLayer = nil;
    
    [_player replaceCurrentItemWithPlayerItem:nil];
    
    _player = nil;
    
    _item = nil;
}
#pragma mark - KVO
- (void)addVideoKVO
{
    //KVO
    [_item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [_item addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    [_item addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
}
- (void)removeVideoKVO {
    [_item removeObserver:self forKeyPath:@"status"];
    [_item removeObserver:self forKeyPath:@"loadedTimeRanges"];
    [_item removeObserver:self forKeyPath:@"playbackBufferEmpty"];
}
- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSString*, id> *)change context:(nullable void *)context {
    
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItemStatus status = _item.status;
        switch (status) {
            case AVPlayerItemStatusReadyToPlay:
            {
                NSLog(@"AVPlayerItemStatusReadyToPlay（KVO：准备完毕，可以播放）");
                [_player play];
                _shouldFlushSlider = YES;
                _videoLength = floor(_item.asset.duration.value * 1.0/ _item.asset.duration.timescale);//向下取整
            }
                break;
            case AVPlayerItemStatusUnknown:
            {
                NSLog(@"AVPlayerItemStatusUnknown（KVO：未知状态，此时不能播放）");
            }
                break;
            case AVPlayerItemStatusFailed:
            {
                NSLog(@"AVPlayerItemStatusFailed（KVO：加载失败，网络或者服务器出现问题）");
                NSLog(@"%@",_item.error);
            }
                break;
                
            default:
                break;
        }
    } else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {//缓冲进度
        NSTimeInterval timeInterval = [self availableDuration];// 计算缓冲进度
        NSLog(@"Time Interval:%f",timeInterval);
        CMTime duration = _item.duration;
        CGFloat totalDuration = CMTimeGetSeconds(duration);
        [self.progressView setProgress:timeInterval / totalDuration animated:YES];
    } else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
        
    }
}
- (NSTimeInterval)availableDuration {
    NSArray *loadedTimeRanges = [[_player currentItem] loadedTimeRanges];
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
    float startSeconds = CMTimeGetSeconds(timeRange.start);
    float durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval result = startSeconds + durationSeconds;// 计算缓冲总进度
    return result;
}
#pragma mark - Notic
- (void)addVideoNotic {
    
    //Notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];// 添加视频播放结束通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieJumped:) name:AVPlayerItemTimeJumpedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieStalle:) name:AVPlayerItemPlaybackStalledNotification object:nil];//添加视频异常中断通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backGroundPauseMoive) name:UIApplicationDidEnterBackgroundNotification object:nil];//进入后台
    
}
- (void)removeVideoNotic {
    //
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemPlaybackStalledNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemTimeJumpedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
//视频播放结束通知
- (void)movieToEnd:(NSNotification *)notic {
    NSLog(@"%@",NSStringFromSelector(_cmd));
}
- (void)movieJumped:(NSNotification *)notic {
    NSLog(@"%@",NSStringFromSelector(_cmd));
}
//视频异常中断通知
- (void)movieStalle:(NSNotification *)notic {
    NSLog(@"%@",NSStringFromSelector(_cmd));
}
//进入后台
- (void)backGroundPauseMoive {
    NSLog(@"%@",NSStringFromSelector(_cmd));
}

#pragma mark - TimerObserver 给AVPlayer 添加time Observer 有利于我们去检测播放进度 但是添加以后一定要记得移除，其实不移除程序不会崩溃，但是这个线程是不会释放的，会占用你大量的内存资源（其实就是播放进度条的值实时跟新监测：监听播放进度）
- (void)addVideoTimerObserver {
    __weak typeof (self)self_ = self;
    _timeObser = [_player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:NULL usingBlock:^(CMTime time) {
        float currentTimeValue = time.value*1.0/time.timescale/self_.videoLength;
        if (self_.shouldFlushSlider) {
            self_.videoSlider.value = currentTimeValue;
        }
        [self_ showStarLabletimeToEndLableTime:[self_ getStringFromCMTime:time] totalTime:[self_ getVideoLengthFromTimeLength:self_.videoLength]];
    }];
}
//显示播放时间比
-(void)showStarLabletimeToEndLableTime:(NSString *)currentTime totalTime:(NSString *)totalTime
{
    _playTimeAndResttime.text = [NSString stringWithFormat:@"%@/%@",currentTime,totalTime];
    //    _playTimeAndResttime.text = @"200:36/200:16";
    
    
    //下面是对时间的另一种处理方式
    //    if(startime<=0){
    //        [starTimeLab setText:@"00:00"];
    //    }else{
    //
    //        int sec = startime/60;
    //        int mmin = (int)startime%60;
    //        if(sec<10 && mmin<10){
    //            [starTimeLab setText:[NSString stringWithFormat:@"0%d:0%d",sec,mmin]];
    //        }else if(sec<10 && mmin>=10){
    //            [starTimeLab setText:[NSString stringWithFormat:@"0%d:%d",sec,mmin]];
    //        }else if (sec>=10 && mmin<10){
    //            [starTimeLab setText:[NSString stringWithFormat:@"%d:0%d",sec,mmin]];
    //        }else{
    //            [starTimeLab setText:[NSString stringWithFormat:@"%d:%d",sec,mmin]];
    //        }
    //    }
    //
    //    if(endttime<=0){
    //        [endTimeLab setText:@"00:00"];
    //    }else{
    //
    //        int sec = endttime/60;
    //        int mmin = (int)endttime%60;
    //
    //        if(sec<10 && mmin<10){
    //            [endTimeLab setText:[NSString stringWithFormat:@"0%d:0%d",sec,mmin]];
    //        }else if(sec<10 && mmin>=10){
    //            [endTimeLab setText:[NSString stringWithFormat:@"0%d:%d",sec,mmin]];
    //        }else if (sec>=10 && mmin<10){
    //            [endTimeLab setText:[NSString stringWithFormat:@"%d:0%d",sec,mmin]];
    //        }else{
    //            [endTimeLab setText:[NSString stringWithFormat:@"%d:%d",sec,mmin]];
    //        }
    //    }
}

- (void)removeVideoTimerObserver {
    NSLog(@"%@",NSStringFromSelector(_cmd));
    [_player removeTimeObserver:_timeObser];
    _timeObser =  nil;
}


#pragma mark - Utils
//获取当前播放时间字符串
- (NSString *)getStringFromCMTime:(CMTime)time
{
    float currentTimeValue = (CGFloat)time.value/time.timescale;//得到当前的播放时间（s）
    
    NSDate * currentDate = [NSDate dateWithTimeIntervalSince1970:currentTimeValue];
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSInteger unitFlags = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond ;
    NSDateComponents *components = [calendar components:unitFlags fromDate:currentDate];
    
    if (currentTimeValue >= 3600 )
    {
        return [NSString stringWithFormat:@"%ld:%ld:%ld",components.hour,components.minute,components.second];
    }
    else
    {
        return [NSString stringWithFormat:@"%ld:%ld",components.minute,components.second];
    }
}
//获取视频总长字符串
- (NSString *)getVideoLengthFromTimeLength:(float)timeLength
{
    NSDate * date = [NSDate dateWithTimeIntervalSince1970:timeLength];
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSInteger unitFlags = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond ;
    NSDateComponents *components = [calendar components:unitFlags fromDate:date];
    
    if (timeLength >= 3600 )
    {
        return [NSString stringWithFormat:@"%ld:%ld:%ld",components.hour,components.minute,components.second];
    }
    else
    {
        return [NSString stringWithFormat:@"%ld:%ld",components.minute,components.second];
    }
}

//隐藏单击之后的view
-(void)hideControlsWithDelay:(NSTimeInterval)delay{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.4
                         animations:^{
                             self.playAndPauseButton.hidden = true;
                             self.fullScreenButton.hidden = YES;
                             self.progressView.hidden = YES;
                             self.videoSlider.hidden = YES;
                             self.playTimeAndResttime.hidden = YES;
                         }];
    });
}
//显示单击之后的控制view
-(void)showControlsWithAnimation{
    [UIView animateWithDuration:0.4
                     animations:^{
                         self.playAndPauseButton.hidden = false;
                         self.fullScreenButton.hidden = NO;
                         self.progressView.hidden = NO;
                         self.videoSlider.hidden = NO;
                         self.playTimeAndResttime.hidden = NO;
                     }];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _playerLayer.frame = self.bounds;
}

#pragma mark - release
- (void)dealloc {
    NSLog(@"dealloc %@",NSStringFromSelector(_cmd));
    [self removeVideoTimerObserver];
    [self removeVideoNotic];
    [self removeVideoKVO];
}

@end

#pragma mark - VideoView (Guester)

@implementation VideoView (Guester)

- (void)addSwipeView {
    _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(swipeAction:)];
    [self addGestureRecognizer:_panGesture];//调节亮度、音量等手势
    
    [self setUpDarkView];//控制透明度也就是亮度的蒙层吧
}
//单击显示出来的view（播放暂停、全屏、进度等）
-(void)addTapGesControlView{
    _tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(gesTapAction:)];
    [self addGestureRecognizer:_tapGesture];
    
    //播放和暂停按钮
    [self setUpPlayAndPauseView];
    
    //播放和总时间时间label
    [self setUpPlayTimeView];
    
    //缓冲指示进度
    [self initProgress];
    
    //快进/快退滑块
    [self initVideoSlider];
    
    //全屏的按钮
    [self setUpFullScreenView];
    
}

//显示播放时间的label
-(void)setUpPlayTimeView{
    _playTimeAndResttime = [[UILabel alloc] init];
    _playTimeAndResttime.backgroundColor = [UIColor clearColor];
    _playTimeAndResttime.font = [UIFont systemFontOfSize:10.0];
    _playTimeAndResttime.textColor = [UIColor whiteColor];
    _playTimeAndResttime.textAlignment = NSTextAlignmentCenter;
    [_playTimeAndResttime setTranslatesAutoresizingMaskIntoConstraints:NO];
    _playTimeAndResttime.hidden = YES;
    [self addSubview:_playTimeAndResttime];
    
    [_playTimeAndResttime addConstraint:[NSLayoutConstraint constraintWithItem:_playTimeAndResttime
                                                                     attribute:NSLayoutAttributeHeight
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:nil
                                                                     attribute:NSLayoutAttributeNotAnAttribute
                                                                    multiplier:1.0f
                                                                      constant:40.0]];
    [_playTimeAndResttime addConstraint:[NSLayoutConstraint constraintWithItem:_playTimeAndResttime
                                                                     attribute:NSLayoutAttributeWidth
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:nil
                                                                     attribute:NSLayoutAttributeNotAnAttribute
                                                                    multiplier:1.0f
                                                                      constant:80.0]];
    NSArray * playTimeAndResttimeContainsArray = @[[NSLayoutConstraint constraintWithItem:_playTimeAndResttime
                                                                                attribute:NSLayoutAttributeLeading
                                                                                relatedBy:NSLayoutRelationEqual
                                                                                   toItem:self
                                                                                attribute:NSLayoutAttributeLeading
                                                                               multiplier:1.0f
                                                                                 constant:0],
                                                   [NSLayoutConstraint constraintWithItem:_playTimeAndResttime
                                                                                attribute:NSLayoutAttributeBottom
                                                                                relatedBy:NSLayoutRelationEqual
                                                                                   toItem:self
                                                                                attribute:NSLayoutAttributeBottom
                                                                               multiplier:1.0f
                                                                                 constant:0]];
    [self addConstraints:playTimeAndResttimeContainsArray];
}

//下载进度显示view
-(void)initProgress{
    _progressView = [[UIProgressView alloc] init];
    _progressView.progressViewStyle=UIProgressViewStyleDefault;
    _progressView.trackTintColor= [UIColor blueColor];
    _progressView.progressTintColor= [UIColor redColor];
    _progressView.progress=0.0;
    _progressView.hidden = YES;
    [_progressView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:_progressView];
    
    NSArray * progressViewContainsArray = @[[NSLayoutConstraint constraintWithItem:_progressView
                                                                         attribute:NSLayoutAttributeLeading
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:self
                                                                         attribute:NSLayoutAttributeLeading
                                                                        multiplier:1.0f
                                                                          constant:80],
                                            [NSLayoutConstraint constraintWithItem:_progressView
                                                                         attribute:NSLayoutAttributeTrailing
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:self
                                                                         attribute:NSLayoutAttributeTrailing
                                                                        multiplier:1.0f
                                                                          constant:-30],
                                            [NSLayoutConstraint constraintWithItem:_progressView
                                                                         attribute:NSLayoutAttributeBottom
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:self
                                                                         attribute:NSLayoutAttributeBottom
                                                                        multiplier:1.0f
                                                                          constant:-20]];
    [self addConstraints:progressViewContainsArray];
}
//拖动快进快退的slider
- (void)initVideoSlider {
    
    _videoSlider = [[MySlider alloc] init];
    [_videoSlider setTranslatesAutoresizingMaskIntoConstraints:NO];//不添加隐含约束
    [_videoSlider setThumbImage:[UIImage imageNamed:@"sliderButton"] forState:UIControlStateNormal];
    [_videoSlider addTarget:self action:@selector(sliderValueChange:) forControlEvents:UIControlEventValueChanged];
    _videoSlider.hidden = YES;
    [_videoSlider setMinimumTrackTintColor:[UIColor grayColor]];//这个是设置圆球左边播放过的条的颜色
    [_videoSlider setMaximumTrackTintColor:[UIColor clearColor]];//这个是设置圆球右边条目的颜色
    //    [_videoSlider setThumbImage:[UIImage imageNamed:@"slider_icon"] forState:UIControlStateNormal];//切得图片一定要和子类中大小一致
    [self addSubview:_videoSlider];
    
    NSArray * videoSliderContainsArray = @[[NSLayoutConstraint constraintWithItem:_videoSlider
                                                                        attribute:NSLayoutAttributeLeading
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:self
                                                                        attribute:NSLayoutAttributeLeading
                                                                       multiplier:1.0f
                                                                         constant:80],
                                           [NSLayoutConstraint constraintWithItem:_videoSlider
                                                                        attribute:NSLayoutAttributeTrailing
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:self
                                                                        attribute:NSLayoutAttributeTrailing
                                                                       multiplier:1.0f
                                                                         constant:-30],
                                           [NSLayoutConstraint constraintWithItem:_videoSlider
                                                                        attribute:NSLayoutAttributeBottom
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:self
                                                                        attribute:NSLayoutAttributeBottom
                                                                       multiplier:1.0f
                                                                         constant:-7]];//因为细条在中间
    [self addConstraints:videoSliderContainsArray];
    
    /**
     设置图片：
     
     [progressSlider setMinimumTrackImage:minImage forState:UIControlStateNormal];
     
     [progressSlider setMaximumTrackImage:maxImage forState:UIControlStateNormal];
     
     [progressSlider setThumbImage:thumbImage forState:UIControlStateNormal];
     */
}

- (void)sliderValueChange:(UISlider *)slider {
    
    [self seekValue:slider.value];
    
}

//停止和播放按钮
-(void)setUpPlayAndPauseView{
    _playAndPauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_playAndPauseButton addTarget:self action:@selector(playAndPauseButtonAction) forControlEvents:UIControlEventTouchUpInside];
    [_playAndPauseButton setImage:[UIImage imageNamed:@"stopSmall.png"] forState:normal];
    [_playAndPauseButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:_playAndPauseButton];
    _playAndPauseButton.hidden = YES;
    
    NSArray * playAndPauseButtonContainsArray = @[[NSLayoutConstraint constraintWithItem:_playAndPauseButton
                                                                               attribute:NSLayoutAttributeCenterX
                                                                               relatedBy:NSLayoutRelationEqual
                                                                                  toItem:self
                                                                               attribute:NSLayoutAttributeCenterX
                                                                              multiplier:1.0f
                                                                                constant:0],
                                                  [NSLayoutConstraint constraintWithItem:_playAndPauseButton
                                                                               attribute:NSLayoutAttributeCenterY
                                                                               relatedBy:NSLayoutRelationEqual
                                                                                  toItem:self
                                                                               attribute:NSLayoutAttributeCenterY
                                                                              multiplier:1.0f
                                                                                constant:0]];
    [self addConstraints:playAndPauseButtonContainsArray];
}

//播放和暂停按钮响应函数
-(void)playAndPauseButtonAction{
    if (_player.rate>0 && !_player.error) { //当前处于正在播放状态
        [_player pause];
        [_playAndPauseButton setImage:[UIImage imageNamed:@"playSmall"] forState:normal];
    } else {//当前处于暂停状态
        [_playAndPauseButton setImage:[UIImage imageNamed:@"stopSmall"] forState:normal];
        [self hideControlsWithDelay:1.0];
        [_player play];
    }
}
//全屏的按钮
-(void)setUpFullScreenView{
    _fullScreenButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_fullScreenButton addTarget:self action:@selector(fullScreenButtonAction) forControlEvents:UIControlEventTouchUpInside];
    [_fullScreenButton setImage:[UIImage imageNamed:@"fullScreen"] forState:normal];
    [_fullScreenButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:_fullScreenButton];
    _fullScreenButton.hidden = YES;
    
    NSArray * fullScreenButtonContainsArray = @[[NSLayoutConstraint constraintWithItem:_fullScreenButton
                                                                             attribute:NSLayoutAttributeTrailing
                                                                             relatedBy:NSLayoutRelationEqual
                                                                                toItem:self
                                                                             attribute:NSLayoutAttributeTrailing
                                                                            multiplier:1.0f
                                                                              constant:-5.0],
                                                [NSLayoutConstraint constraintWithItem:_fullScreenButton
                                                                             attribute:NSLayoutAttributeBottom
                                                                             relatedBy:NSLayoutRelationEqual
                                                                                toItem:self
                                                                             attribute:NSLayoutAttributeBottom
                                                                            multiplier:1.0f
                                                                              constant:-5.0]];
    [self addConstraints:fullScreenButtonContainsArray];
}
//全屏/缩小
-(void)fullScreenButtonAction{
    if ([UIDevice currentDevice].orientation != UIDeviceOrientationPortrait) {
        NSNumber *value = [NSNumber numberWithInt:UIInterfaceOrientationPortrait];
        [[UIDevice currentDevice] setValue:value forKey:@"orientation"];
    }else{
        NSNumber *value = [NSNumber numberWithInt:UIInterfaceOrientationLandscapeLeft];
        [[UIDevice currentDevice] setValue:value forKey:@"orientation"];
    }
}

- (void)setUpDarkView {
    _darkView = [[UIView alloc] init];
    [_darkView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_darkView setBackgroundColor:[UIColor blackColor]];
    _darkView.alpha = 0.0;
    [self addSubview:_darkView];
    
    NSMutableArray *darkArray = [NSMutableArray array];
    [darkArray addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_darkView]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_darkView)]];
    [darkArray addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_darkView]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_darkView)]];
    [self addConstraints:darkArray];
}

#pragma mark -手势响应

- (void)swipeAction:(UISwipeGestureRecognizer *)gesture {
    
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
        {
            _changeKind = ChangeNone;
            _lastPoint = [gesture locationInView:self];
        }
            break;
        case  UIGestureRecognizerStateChanged:
        {
            [self getChangeKindValue:[gesture locationInView:self]];
            
        }
            break;
        case UIGestureRecognizerStateEnded:
        {
            if (_changeKind == ChangeCMTime) {
                [self changeEndForCMTime:[gesture locationInView:self]];
            }
            _changeKind = ChangeNone;
            _lastPoint = CGPointZero;
        }
        default:
            break;
    }
    
}

//单击手势响应：显示播放/暂停、返回和分享等功能性按钮
-(void)gesTapAction:(UITapGestureRecognizer *)tapGes{
    if (_playAndPauseButton.isHidden) {
        [self showControlsWithAnimation];
    } else {
        [self hideControlsWithDelay:0.0];
    }
}
#pragma mark -功能辅助函数
- (void)getChangeKindValue:(CGPoint)pointNow {
    
    switch (_changeKind) {
            
        case ChangeNone:
        {
            [self changeForNone:pointNow];
        }
            break;
        case ChangeCMTime://快进/快退
        {
            [self changeForCMTime:pointNow];
        }
            break;
        case ChangeLigth://亮度
        {
            [self changeForLigth:pointNow];
        }
            break;
        case ChangeVoice://音量
        {
            [self changeForVoice:pointNow];
        }
            break;
            
        default:
            break;
    }
}
//这个函数给_changeKind（决定要设置的是音量还是亮度、快进快退）、_lastPoint设置值
- (void)changeForNone:(CGPoint) pointNow {
    if (fabs(pointNow.x - _lastPoint.x) > fabs(pointNow.y - _lastPoint.y)) {//x方向的偏移量大
        _changeKind = ChangeCMTime;
    } else {
        float halfWight = self.bounds.size.width / 2;//以中间为界，右侧为音量，左侧为亮度
        if (_lastPoint.x < halfWight) {
            _changeKind =  ChangeLigth;
        } else {
            _changeKind =   ChangeVoice;
        }
        _lastPoint = pointNow;
    }
}
//快进或快退时间打印（不是执行的快进或快退）
- (void)changeForCMTime:(CGPoint) pointNow {
    float number = fabs(pointNow.x - _lastPoint.x);
    if (pointNow.x > _lastPoint.x && number > 10) {
        float currentTime = _player.currentTime.value / _player.currentTime.timescale;
        float tobeTime = currentTime + number*0.5;
        NSLog(@"forwart to  changeTo  time:%f",tobeTime);//快进时间打印
    } else if (pointNow.x < _lastPoint.x && number > 10) {
        float currentTime = _player.currentTime.value / _player.currentTime.timescale;
        float tobeTime = currentTime - number*0.5;
        NSLog(@"back to  time:%f",tobeTime);//快退时间打印
    }
}
//亮度
- (void)changeForLigth:(CGPoint) pointNow {
    float number = fabs(pointNow.y - _lastPoint.y);
    if (pointNow.y > _lastPoint.y && number > 10) {
        _lastPoint = pointNow;
        [self minLigth];
        
    } else if (pointNow.y < _lastPoint.y && number > 10) {
        _lastPoint = pointNow;
        [self upperLigth];
    }
}
//改变音量大小
- (void)changeForVoice:(CGPoint)pointNow {
    float number = fabs(pointNow.y - _lastPoint.y);
    if (pointNow.y > _lastPoint.y && number > 10) {
        _lastPoint = pointNow;
        [self minVolume];
    } else if (pointNow.y < _lastPoint.y && number > 10) {
        _lastPoint = pointNow;
        [self upperVolume];
    }
}
//快进快退调节
- (void)changeEndForCMTime:(CGPoint)pointNow {
    if (pointNow.x > _lastPoint.x ) {
        NSLog(@"end for CMTime Upper");
        float length = fabs(pointNow.x - _lastPoint.x);
        [self upperCMTime:length];
    } else {
        NSLog(@"end for CMTime min");
        float length = fabs(pointNow.x - _lastPoint.x);
        [self mineCMTime:length];
    }
}
//变亮
- (void)upperLigth {
    
    if (_darkView.alpha >= 0.1) {
        _darkView.alpha =  _darkView.alpha - 0.1;
    }
    
}
//变暗
- (void)minLigth {
    if (_darkView.alpha <= 1.0) {
        _darkView.alpha =  _darkView.alpha + 0.1;
    }
}

//增加音量
- (void)upperVolume {
    if (self.volumeSlider.value <= 1.0) {
        self.volumeSlider.value =  self.volumeSlider.value + 0.1 ;
    }
}
//减小音量
- (void)minVolume {
    if (self.volumeSlider.value >= 0.0) {
        self.volumeSlider.value =  self.volumeSlider.value - 0.1 ;
    }
}
#pragma mark -CMTIME（CMTimeMake(a,b)   a当前第几帧, b每秒钟多少帧.当前播放时间a/b：eg：CMTimeMake(60, 30);当前是60帧，每秒钟30帧，所以当前播放时间是第二秒）
//快进
- (void)upperCMTime:(float)length {
    
    float currentTime = _player.currentTime.value / _player.currentTime.timescale;
    float tobeTime = currentTime + length*0.5;
    if (tobeTime > _videoLength) {
        [_player seekToTime:_item.asset.duration];//快进到最后
    } else {
        [_player seekToTime:CMTimeMake(tobeTime, 1)];
    }
}
//快退
- (void)mineCMTime:(float)length {
    
    float currentTime = _player.currentTime.value / _player.currentTime.timescale;
    float tobeTime = currentTime - length*0.5;
    if (tobeTime <= 0) {
        [_player seekToTime:kCMTimeZero];//快退到刚开始
    } else {
        [_player seekToTime:CMTimeMake(tobeTime, 1)];
    }
}

//获取音量控制view
- (MPVolumeView *)volumeView {
    
    if (_volumeView == nil) {
        _volumeView = [[MPVolumeView alloc] init];//控制系统的音量改变
        _volumeView.hidden = YES;
        [self addSubview:_volumeView];
    }
    return _volumeView;
}
//获取音量滑块（改变滑块值就是改变了音量）
- (UISlider *)volumeSlider {
    if (_volumeSlider== nil) {
        NSLog(@"%@",[self.volumeView subviews]);
        for (UIView  *subView in [self.volumeView subviews]) {
            if ([subView.class.description isEqualToString:@"MPVolumeSlider"]) {
                _volumeSlider = (UISlider*)subView;
                break;
            }
        }
    }
    return _volumeSlider;
}

@end
