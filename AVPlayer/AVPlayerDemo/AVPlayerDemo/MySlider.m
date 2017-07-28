//
//  MySlider.m
//  aVideo
//
//  Created by lizhongfei on 25/7/17.
//  Copyright © 2017年 SomeBoy. All rights reserved.
//

#import "MySlider.h"

@implementation MySlider

//滑块滑到的高度
-(CGRect)trackRectForBounds:(CGRect)bounds{
    bounds = [super trackRectForBounds:bounds];
    // 必须通过调用父类的trackRectForBounds 获取一个 bounds 值，否则 Autolayout 会失效，UISlider 的位置会跑偏。
    
    // 这里面的h即为你想要设置的高度。
    return CGRectMake(bounds.origin.x, bounds.origin.y, bounds.size.width, 2);
}

////滑块大小
//- (CGRect)thumbRectForBounds:(CGRect)bounds trackRect:(CGRect)rect value:(float)value {
//    bounds = [super thumbRectForBounds:bounds trackRect:rect value:value];
//    // 这次如果不调用的父类的方法 Autolayout 倒是不会有问题，但是滑块根本就不动~
//    return CGRectMake(bounds.origin.x, bounds.origin.y, 8, 8);
//    // w 和 h 是滑块可触摸范围的大小，跟通过图片改变的滑块大小应当一致。
//}



@end
