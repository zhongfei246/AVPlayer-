//
//  ViewController.m
//  AVPlayerDemo
//
//  Created by lizhongfei on 28/7/17.
//  Copyright © 2017年 lizhongfei. All rights reserved.
//

#import "ViewController.h"
#import "AVViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0, 0, 140, 30);
    button.center = self.view.center;
    [button setBackgroundColor:[UIColor grayColor]];
    [button setTitle:@"点我播放视频" forState:normal];
    [self.view addSubview:button];
    [button addTarget:self action:@selector(pushAVVC:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)pushAVVC:(id)sender {
    AVViewController *vc = [[AVViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
