//
//  AVViewController.m
//  AVPlayerDemo
//
//  Created by lizhongfei on 28/7/17.
//  Copyright © 2017年 lizhongfei. All rights reserved.
//

#import "AVViewController.h"
#import "VideoView.h"

@interface AVViewController ()

@property (nonatomic ,strong) VideoView *videoView;

@property (nonatomic ,strong) NSMutableArray<NSLayoutConstraint *> *array;

@end

@implementation AVViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor whiteColor]];
    [self initVideoView];
}

- (void)initVideoView {
    
    NSString *path = @"http://static.tripbe.com/videofiles/20121214/9533522808.f4v.mp4";
    @autoreleasepool {
        _videoView = [[VideoView alloc] initWithUrl:path delegate:nil];
        //将自适应向布局约束的转化关掉(根据情况有时需要有时不需要)在translatesAutoresizingMaskIntoConstraints 设置为NO之后，没有添加隐含constraint,这样就不容易与新添加的约束形成冲突（假设v1是一个不使用autolayout的view，而v2是一个使用autolayout的view，但v1成为v2的subview时，v2需要四条隐含的constraint来确定v1的位置，这些约束都是从v1的frame转化而来，这时一般还会在v2上添加一些新的约束，如果不设置为No，很容易冲突，如果不设置新的约束很可能不能满足要求（设置为NO之后v2不添加隐含的constraint，以至于不和v2新添加的约束冲突）。）
        [_videoView setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self.view addSubview:_videoView];
    }
    
    /**
     iPhone4S,iPhone5/5s,iPhone6(Compact：紧凑，Regular：正常，any：包含他两)
     竖屏：(w:Compact h:Regular)
     横屏：(w:Compact h:Compact)
     
     iPhone6 Plus
     竖屏：(w:Compact h:Regular)
     横屏：(w:Regular h:Compact)
     
     iPad
     竖屏：(w:Regular h:Regular)
     横屏：(w:Regular h:Regular)
     
     Apple Watch(猜测)
     竖屏：(w:Compact h:Compact)
     横屏：(w:Compact h:Compact)
     */
    if (self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact) {//比较可发现横竖屏的h是不一样的，横屏就是Compact，竖屏就是Regular。
        [self installLandspace];//横屏（剩下的都是竖屏）
    } else {
        [self installVertical];//竖屏
    }
}

/**
 H:   表示水平方向
 V:   表示垂直方向
 |   表示父控件
 — ：表示距离
 控件需要使用[]括起来(eg:<1> H:|-20-[blueView]-20-|表示水平方向，蓝色blueView距离父控件左边20，距离父控件右边20
 <2> V:[redView(==blueView)]-20-[blueView(20)]-20-|  表示blueView距离上面redView 20的距离，redView的高度与blueView的高度相等，blueView的高度为20，blueView下面距离父控件的距离为20 )
 
 + (NSArray *)constraintsWithVisualFormat:(NSString *)format options:(NSLayoutFormatOptions)opts metrics:(NSDictionary *)metrics views:(NSDictionary *)views;
 Format:表示vfl约束语句
 Options:表示对其方式
 
 Metrics:表示vfl中对应的占位符
 
 Views:表示vfl中对应的view控件
 
 当我们将一个创建好的约束添加到View上时，添加的目标View要遵循以下的规则:
 
 对于两个同层级View之间的约束关系，添加到他们的父View上。
 对于两个不同层级View之间的约束关系，添加到他们最近的共同的父View上
 对于有层次关系的两个View之间的约束关系，添加到层次较高的父View上
 
 */

//竖屏添加约束
- (void)installVertical {
    if (_array != nil) {
        [self.view removeConstraints:_array];
        [_array removeAllObjects];
    } else {
        _array = [NSMutableArray array];
    }
    id topGuide = self.topLayoutGuide;
    NSDictionary *dic = @{@"top":@100,@"height":@180,@"edge":@20,@"space":@80};
    [_array addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_videoView]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_videoView)]];//VFL（Visual Format Language）可视化格式语言
    [_array addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[topGuide]-(top)-[_videoView(==height)]" options:0 metrics:dic views:NSDictionaryOfVariableBindings(_videoView,topGuide)]];
    [self.view addConstraints:_array];
    
}
//横屏添加约束
- (void)installLandspace {
    if (_array != nil) {
        
        [self.view removeConstraints:_array];
        [_array removeAllObjects];
    } else {
        
        _array = [NSMutableArray array];
    }
    
    id topGuide = self.topLayoutGuide;
    
    [_array addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_videoView]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_videoView)]];
    [_array addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[topGuide][_videoView]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_videoView,topGuide)]];
    [self.view addConstraints:_array];
}
/**
 *  当设备改变朝向时
 *  返回当前屏幕sizeClaeese的尺寸信息的代理方法
 */
- (void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>)coordinator {
    
    [super willTransitionToTraitCollection:newCollection withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id <UIViewControllerTransitionCoordinatorContext> context) {
        
        if (newCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact) {
            [self installLandspace];
        } else {
            [self installVertical];
        }
        [self.view setNeedsLayout];
    } completion:nil];
    
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}
- (void)sliderValueChange:(UISlider *)slider {
    
    [_videoView seekValue:slider.value];
    
}
- (void)dealloc {
    [_videoView stop];
    _videoView = nil;
    NSLog(@"dealloc of VC");
}

@end
