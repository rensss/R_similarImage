//
//  ViewController.m
//  cleaner
//
//  Created by Rzk on 2019/5/15.
//  Copyright © 2019 Rzk. All rights reserved.
//

#import "ViewController.h"
#import "SimilarCompared.h"

#import <CocoaImageHashing/CocoaImageHashing.h>

//#define kImageNum 11
#define kImageNum 10

@interface ViewController ()

@property (nonatomic, strong) NSMutableArray *imageArray; /**< 图像数组*/
@property (nonatomic, strong) UILabel *similar; /**< 相似度*/
@property (nonatomic, assign) NSInteger selectNum; /**< 选中数*/

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.imageArray = [NSMutableArray array];
    
    CGFloat width = 140;
    CGFloat xPadding = 10;
    CGFloat yPadding = 10;
    
    CGFloat x = (self.view.frame.size.width - (width+xPadding) * 2 - xPadding)/2;
    
    for (int i = 0; i < kImageNum; i++) {
        UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(x + (i%2)*(width+xPadding), 50 + (i/2)*(width+yPadding), width, width)];
        
        NSString *preStr;
        if (kImageNum == 10) {
            preStr = @"image_";
        } else {
            preStr = @"image_0_";
        }
        
        UIImage *image = [UIImage imageNamed:[NSString stringWithFormat:@"%@%d",preStr,i]];
        
        [self.imageArray addObject:UIImagePNGRepresentation(image)];
        
        [button setImage:image forState:UIControlStateNormal];
        button.imageView.contentMode = UIViewContentModeScaleAspectFit;
        button.layer.borderColor = [UIColor lightGrayColor].CGColor;
        button.tag = i + 1000;
        [button addTarget:self action:@selector(buttonClick:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:button];
    }
    
    self.similar = [[UILabel alloc] initWithFrame:CGRectMake(0, 50 + kImageNum/2*(width+yPadding), self.view.frame.size.width, 30)];
    self.similar.text = @"0%";
    self.similar.font = [UIFont systemFontOfSize:30];
    self.similar.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.similar];
    
    [self findDuplicates];
}

- (void)buttonClick:(UIButton *)btn {
    
    if (btn.selected) {
        btn.layer.borderWidth = 0.0f;
        self.selectNum --;
        btn.selected = NO;
        return;
    }
    
    if (self.selectNum > 1) {
        UIImage *image1;
        UIImage *image2;
        for (int i = 0; i<kImageNum; i++) {
            UIButton *btn = (UIButton *)[self.view viewWithTag:i+1000];
            if (btn.selected) {
                if (!image1) {
                    image1 = btn.imageView.image;
                } else {
                    image2 = btn.imageView.image;
                }
            }
        }
        
        CGFloat percent = [[SimilarCompared sharedInstance] similarFromImage:image1 toImage:image2];
        self.similar.text = [NSString stringWithFormat:@"%.2f%%",percent*100];
        
//        BOOL rst = [[OSImageHashing sharedInstance] compareImageData:UIImagePNGRepresentation(image1) to:UIImagePNGRepresentation(image2) withQuality:OSImageHashingQualityHigh];
        BOOL rst = [[OSImageHashing sharedInstance] compareImageData:UIImagePNGRepresentation(image1) to:UIImagePNGRepresentation(image2) withProviderId:OSImageHashingProviderDHash];
        NSLog(@"是否相似 ---- %@",rst?@"YES":@"NO");
        return;
    }
    
    if (!btn.selected) {
        btn.layer.borderWidth = 1.0f;
        self.selectNum ++;
        btn.selected = YES;
        return;
    }
}


- (void)findDuplicates {
    
    NSMutableArray<OSTuple<OSImageId *, NSData *> *> *dataArr = [NSMutableArray new];
    
    NSUInteger i = 1;
    for (NSData *data in self.imageArray) {
        OSTuple<OSImageId *, NSData *> *tuple = [OSTuple tupleWithFirst:[NSString stringWithFormat:@"%@", @(i++)] andSecond:data];
        [dataArr addObject:tuple];
    }
    
    NSArray<OSTuple<OSImageId *, OSImageId *> *> *similarImageIdsAsTuples = [[OSImageHashing sharedInstance] similarImagesWithHashingQuality:OSImageHashingQualityHigh forImages:dataArr];
    
    NSLog(@"Similar image ids: %@", similarImageIdsAsTuples);
    
    OSHashDistanceType distence = [[OSImageHashing sharedInstance] hashDistanceSimilarityThresholdWithProvider:OSImageHashingProviderAHash];
    NSLog(@"阀值---OSImageHashingProviderAHash---%lld",distence);
    distence = [[OSImageHashing sharedInstance] hashDistanceSimilarityThresholdWithProvider:OSImageHashingProviderDHash];
    NSLog(@"阀值---OSImageHashingProviderDHash---%lld",distence);
    distence = [[OSImageHashing sharedInstance] hashDistanceSimilarityThresholdWithProvider:OSImageHashingProviderPHash];
    NSLog(@"阀值---OSImageHashingProviderPHash---%lld",distence);
    distence = [[OSImageHashing sharedInstance] hashDistanceSimilarityThresholdWithProvider:OSImageHashingProviderNone];
    NSLog(@"阀值---OSImageHashingProviderNone---%lld",distence);
}

@end
