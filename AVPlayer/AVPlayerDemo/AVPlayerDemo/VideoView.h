//
//  VideoView.h
//  AVPlayerDemo
//
//  Created by lizhongfei on 28/7/17.
//  Copyright © 2017年 lizhongfei. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>


@protocol VideoSomeDelegate <NSObject>


@end

@interface VideoView : UIView

@property (nonatomic ,strong) NSString *playerUrl;

@property (nonatomic ,readonly) AVPlayerItem *item;

@property (nonatomic ,readonly) AVPlayerLayer *playerLayer;

@property (nonatomic ,readonly) AVPlayer *player;

@property (nonatomic ,weak) id <VideoSomeDelegate> someDelegate;

- (id)initWithUrl:(NSString *)path delegate:(id<VideoSomeDelegate>)delegate;

- (void)seekValue:(float)value;

- (void)stop;

@end

@interface VideoView  (Guester)

- (void)addSwipeView;

-(void)addTapGesControlView;

@end
