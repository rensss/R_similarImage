//
//  SimilarCompared.h
//  cleaner
//
//  Created by Rzk on 2019/5/15.
//  Copyright © 2019 Rzk. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SimilarCompared : NSObject
/// 图像相似度对比单例
+ (instancetype)sharedInstance;

/// 比较两个图片的相似度
- (CGFloat)similarFromImage:(UIImage *)fromImage toImage:(UIImage *)toImage;

@end

NS_ASSUME_NONNULL_END
