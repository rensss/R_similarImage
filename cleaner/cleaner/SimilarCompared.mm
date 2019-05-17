//
//  SimilarCompared.m
//  cleaner
//
//  Created by Rzk on 2019/5/15.
//  Copyright © 2019 Rzk. All rights reserved.
//

#import "SimilarCompared.h"

#import "UIImage+OpenCV.h"

#import <opencv2/highgui/highgui_c.h>
#import <opencv2/imgproc/imgproc_c.h>
#import <opencv2/core/core_c.h>
#import <opencv2/features2d/features2d.hpp>

@implementation SimilarCompared

#pragma mark - 初始化
static id sharedSingleton = nil;
+ (id)allocWithZone:(struct _NSZone *)zone {
    if (!sharedSingleton) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            sharedSingleton = [super allocWithZone:zone];
        });
    }
    return sharedSingleton;
}

- (id)init {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedSingleton = [super init];
    });
    return sharedSingleton;
}

+ (instancetype)sharedInstance {
    return [[self alloc] init];
}

#pragma mark - func
- (CGFloat)similarFromImage:(UIImage *)fromImage toImage:(UIImage *)toImage {
    
    CGFloat percent = 0;
    // 方法一
//    percent = [self calculateHammingDistanceWithHash:fromImage toImage:toImage];
    // 方法二
    percent = 1 - [self imgSimilarity:fromImage toImage:toImage];
    
    return percent;
}

/// 计算汉明距离
- (NSInteger)hammingDistance:(NSString *)from :(NSString *)to {
    if (from && to && from.length == to.length) {
        NSInteger count = 0;
        for (int i = 0; i < from.length; i++) {
            NSInteger fromInt = [[from substringWithRange:NSMakeRange(i, 1)] integerValue];
            NSInteger toInt = [[to substringWithRange:NSMakeRange(i, 1)] integerValue];
            if (fromInt != toInt) {
                count ++;
            }
        }
        return count;
    } else {
        return -1;
    }
}

#pragma mark - hash
/// 压缩图像  变幻灰度图  算出hash  计算汉明距离
- (CGFloat)calculateHammingDistanceWithHash:(UIImage *)fromImage toImage:(UIImage *)toImage {
    UIImage *from = [self OriginImage:fromImage scaleToSize:CGSizeMake(8, 8)];
    UIImage *grayFrom = [self getGrayImage:from];
    NSString *fromHash = [self getHashFrom:grayFrom];

    UIImage *to = [self OriginImage:toImage scaleToSize:CGSizeMake(8, 8)];
    UIImage *grayTo = [self getGrayImage:to];
    NSString *toHash = [self getHashFrom:grayTo];

    NSInteger hammingDistance = [self hammingDistance:fromHash :toHash];

    // 异常
    if (hammingDistance == -1) {
        return 0;
    }

    CGFloat percent = (CGFloat)(fromHash.length-hammingDistance)/fromHash.length;

    NSLog(@"\n%@\n%@\n%ld\n%f",fromHash,toHash,(long)hammingDistance,percent);

    return percent;
}

/// 缩放图片
- (UIImage *)OriginImage:(UIImage *)image scaleToSize:(CGSize)size {
    UIGraphicsBeginImageContext(size);  //size 为CGSize类型，即你所需要的图片尺寸
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage* scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaledImage;   //返回的就是已经改变的图片
}

/// 转为64级灰度 所有像素点总共只有64种颜色。
- (UIImage *)getGrayImage:(UIImage*)sourceImage {

    int width = sourceImage.size.width;
    int height = sourceImage.size.height;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGContextRef context = CGBitmapContextCreate (nil,width,height,8,0,colorSpace,kCGImageAlphaNone);
    CGColorSpaceRelease(colorSpace);
    if (context == NULL) {
        return nil;
    }
    CGContextDrawImage(context,CGRectMake(0, 0, width, height), sourceImage.CGImage);
    UIImage *grayImage = [UIImage imageWithCGImage:CGBitmapContextCreateImage(context)];
    CGContextRelease(context);
    return grayImage;
}

/// 计算所有64个像素的灰度平均值
- (unsigned char*)grayscalePixels:(UIImage *)image {
    // The amount of bits per pixel, in this case we are doing grayscale so 1 byte = 8 bits
#define BITS_PER_PIXEL 8
    // The amount of bits per component, in this it is the same as the bitsPerPixel because only 1 byte represents a pixel
#define BITS_PER_COMPONENT (BITS_PER_PIXEL)
    // The amount of bytes per pixel, not really sure why it asks for this as well but it's basically the bitsPerPixel divided by the bits per component (making 1 in this case)
#define BYTES_PER_PIXEL (BITS_PER_PIXEL/BITS_PER_COMPONENT)

    // Define the colour space (in this case it's gray)
    CGColorSpaceRef colourSpace = CGColorSpaceCreateDeviceGray();

    // Find out the number of bytes per row (it's just the width times the number of bytes per pixel)
    size_t bytesPerRow = image.size.width * BYTES_PER_PIXEL;
    // Allocate the appropriate amount of memory to hold the bitmap context
    unsigned char* bitmapData = (unsigned char*) malloc(bytesPerRow*image.size.height);

    // Create the bitmap context, we set the alpha to none here to tell the bitmap we don't care about alpha values
    CGContextRef context = CGBitmapContextCreate(bitmapData,image.size.width,image.size.height,BITS_PER_COMPONENT,bytesPerRow,colourSpace,kCGImageAlphaNone);

    // We are done with the colour space now so no point in keeping it around
    CGColorSpaceRelease(colourSpace);

    // Create a CGRect to define the amount of pixels we want
    CGRect rect = CGRectMake(0.0,0.0,image.size.width,image.size.height);
    // Draw the bitmap context using the rectangle we just created as a bounds and the Core Graphics Image as the image source
    CGContextDrawImage(context,rect,image.CGImage);
    // Obtain the pixel data from the bitmap context
    unsigned char* pixelData = (unsigned char*)CGBitmapContextGetData(context);

    // Release the bitmap context because we are done using it
    CGContextRelease(context);

    return pixelData;
#undef BITS_PER_PIXEL
#undef BITS_PER_COMPONENT
}

/// 计算图像hash
- (NSString *)getHashFrom:(UIImage *)img {
    unsigned char* pixelData = [self grayscalePixels:img];

    int total = 0;
    int ave = 0;
    for (int i = 0; i < img.size.height; i++) {
        for (int j = 0; j < img.size.width; j++) {
            total += (int)pixelData[(i*((int)img.size.width))+j];
        }
    }
    ave = total/64;
    NSMutableString *result = [[NSMutableString alloc] init];
    for (int i = 0; i < img.size.height; i++) {
        for (int j = 0; j < img.size.width; j++) {
            int a = (int)pixelData[(i*((int)img.size.width))+j];
            if(a >= ave) {
                [result appendString:@"1"];
            } else {
                [result appendString:@"0"];
            }
        }
    }
    return result;
}

#pragma mark - OpenCV
/// 相似度
- (CGFloat)imgSimilarity:(UIImage *)fromImage toImage:(UIImage *)toImage {
    // 读取图片
//    img1 = cv2.imread(img1_path, cv2.IMREAD_GRAYSCALE);
//    img2 = cv2.imread(img2_path, cv2.IMREAD_GRAYSCALE);

    // 初始化ORB检测器
//    orb = cv2.ORB_create();
//    kp1, des1 = orb.detectAndCompute(img1, None);
//    kp2, des2 = orb.detectAndCompute(img2, None);

    // 提取并计算特征点
//    bf = cv2.BFMatcher(cv2.NORM_HAMMING);

    // knn筛选结果
//    matches = bf.knnMatch(des1, trainDescriptors=des2, k=2);

    // 查看最大匹配点数目
//    good = [m for (m, n) in matches if m.distance < 0.75 * n.distance];
//    print(len(good));
//    print(len(matches));
//    CGFloat similary = len(good) / len(matches);
//    NSLog(@"两张图片相似度为:%s",similary);
    
    

    // 两张图尺寸不一致
    if (fromImage.size.width != toImage.size.width || fromImage.size.height != toImage.size.height) {
        if (fromImage.size.width * fromImage.size.width > toImage.size.width * toImage.size.height) {
            fromImage = [self OriginImage:fromImage scaleToSize:toImage.size];
        } else {
            toImage = [self OriginImage:toImage scaleToSize:fromImage.size];
        }
    }
    
    IplImage *fromIplImage = [self convertToIplImage:fromImage];
    // 创建图像header并分配图像数据 图像深度为原图像深度
    IplImage *fromDscIpl = cvCreateImage(cvGetSize(fromIplImage), fromIplImage->depth, 1);
    // 创建图像header并分配图像数据 图像深度为8
    IplImage *fromDscIplNew = cvCreateImage(cvGetSize(fromIplImage),  IPL_DEPTH_8U, 3);
    // 将输入数组像素从一个颜色空间转换为另一个颜色空间 (灰度图)
    cvCvtColor(fromDscIpl, fromDscIplNew, CV_GRAY2BGR);
//    UIImage *from = [self convertToUIImage:fromDscIplNew];


    IplImage *toIplImage = [self convertToIplImage:toImage];
    IplImage *toDscIplImage = cvCreateImage(cvGetSize(toIplImage), toIplImage ->depth, 1);
    IplImage *toDscIplNew = cvCreateImage(cvGetSize(toIplImage), IPL_DEPTH_8U, 3);
    cvCvtColor(toDscIplImage, toDscIplNew, CV_GRAY2BGR);
//    UIImage *to = [self convertToUIImage:toDscIplNew];

    UIImage *tempImage = fromImage;
    IplImage *tempIplImage = [self convertToIplImage:tempImage];
    CGFloat rst = [self ComparePPKImage:fromIplImage withAnotherImage:toIplImage withTempleImage:tempIplImage];
    
    return rst;
}

/// UIImage类型转换为IPlImage类型
- (IplImage*)convertToIplImage:(UIImage*)image {
    CGImageRef imageRef = image.CGImage;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    IplImage *iplImage = cvCreateImage(cvSize(image.size.width, image.size.height), IPL_DEPTH_8U, 4);
    CGContextRef contextRef = CGBitmapContextCreate(iplImage->imageData, iplImage->width, iplImage->height, iplImage->depth, iplImage->widthStep, colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault);
    CGContextDrawImage(contextRef, CGRectMake(0, 0, image.size.width, image.size.height), imageRef);
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);
    IplImage *ret = cvCreateImage(cvGetSize(iplImage), IPL_DEPTH_8U, 3);
    cvCvtColor(iplImage, ret, CV_RGB2BGR);
    cvReleaseImage(&iplImage);
    return ret;
}

/// 图片匹配
- (CGFloat)ComparePPKImage:(IplImage*)fromIplImage withAnotherImage:(IplImage*)toIplImage withTempleImage:(IplImage*)templeIplImage {
    // 第一次模板标记
    CvPoint fromMinLoc = [self CompareTempleImage:templeIplImage withImage:fromIplImage];
    if (fromMinLoc.x==fromIplImage->width || fromMinLoc.y==fromIplImage->height) {
        NSLog(@"第一个图片的模板标记失败");
        return false;
    }
    
    // 第二次模板标记
    CvPoint toMinLoc = [self CompareTempleImage:templeIplImage withImage:toIplImage];
    if (toMinLoc.x==toIplImage->width || toMinLoc.y==toIplImage->height) {
        NSLog(@"第二个图片的模板标记失败");
        return false;
    }
    
    // 裁切图片
    IplImage *fromCropImage,*toCropImage;
    fromCropImage = [self cropIplImage:fromIplImage withStartPoint:fromMinLoc withWidth:templeIplImage->width withHeight:templeIplImage->height];
    
    toCropImage = [self cropIplImage:toIplImage withStartPoint:toMinLoc withWidth:templeIplImage->width withHeight:templeIplImage->height];
    
    return [self CompareHist:fromCropImage withParam2:toCropImage];
}

/// 多通道彩色图片的直方图比对
- (double)CompareHist:(IplImage*)image1 withParam2:(IplImage*)image2 {
    int hist_size = 256;
    IplImage *gray_plane = cvCreateImage(cvGetSize(image1), 8, 1);
    // 将输入数组像素从一个颜色空间转换为另一个颜色空间
    cvCvtColor(image1, gray_plane, CV_BGR2GRAY);
    // 创建直方图
    CvHistogram *gray_hist = cvCreateHist(1, &hist_size, CV_HIST_ARRAY);
    // 计算直方数据
    cvCalcHist(&gray_plane, gray_hist);

    IplImage *gray_plane2 = cvCreateImage(cvGetSize(image2), 8, 1);
    cvCvtColor(image2, gray_plane2, CV_BGR2GRAY);
    CvHistogram *gray_hist2 = cvCreateHist(1, &hist_size, CV_HIST_ARRAY);
    cvCalcHist(&gray_plane2, gray_hist2);
    double rst = cvCompareHist(gray_hist, gray_hist2, CV_COMP_BHATTACHARYYA);
    NSLog(@"对比结果=%f",rst);
    return rst;
}

/// 单通道彩色图片的直方图
- (double)CompareHistSignle:(IplImage*)image1 withParam2:(IplImage*)image2 {
    int hist_size = 256;
    CvHistogram *gray_hist = cvCreateHist(1, &hist_size, CV_HIST_ARRAY);
    cvCalcHist(&image1, gray_hist);

    CvHistogram *gray_hist2 = cvCreateHist(1, &hist_size, CV_HIST_ARRAY);
    cvCalcHist(&image2, gray_hist2);

    return cvCompareHist(gray_hist, gray_hist2, CV_COMP_BHATTACHARYYA);
}

/// IplImage类型转换为UIImage类型
- (UIImage*)convertToUIImage:(IplImage*)image {
    cvCvtColor(image, image, CV_BGR2RGB);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSData *data = [NSData dataWithBytes:image->imageData length:image->imageSize];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
    CGImageRef imageRef = CGImageCreate(image->width, image->height, image->depth, image->depth * image->nChannels, image->widthStep, colorSpace, kCGImageAlphaNone | kCGBitmapByteOrderDefault, provider, NULL, false, kCGRenderingIntentDefault);
    UIImage *ret = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    return ret;
}

/// 基于模板图片的标记识别
- (CvPoint)CompareTempleImage:(IplImage *)templeIpl withImage:(IplImage *)mIplImage {
    IplImage *src = mIplImage;
    IplImage *templat = templeIpl;
    IplImage *result;
    int srcW, srcH, templatW, templatH, resultH, resultW;
    srcW = src->width;
    srcH = src->height;
    templatW = templat->width;
    templatH = templat->height;
    resultW = srcW - templatW + 1;
    resultH = srcH - templatH + 1;
    result = cvCreateImage(cvSize(resultW, resultH), 32, 1);
    // 测量源图像中模板和重叠窗口之间的相似性，并用测量值填充结果图像
    cvMatchTemplate(src, templat, result, CV_TM_SQDIFF);
    
    double minValue, maxValue;
    CvPoint minLoc, maxLoc;
    // 查找全局最小值，最大值和位置
    cvMinMaxLoc(result, &minValue, &maxValue, &minLoc, &maxLoc);
    
    if (minLoc.y+templatH>srcH || minLoc.x+templatW>srcW) {
        NSLog(@"未找到标记图片");
        minLoc.x=srcW;
        minLoc.y=srcH;
    }
    return minLoc;
}

/// 裁切
- (IplImage*)cropIplImage:(IplImage*)srcIpl withStartPoint:(CvPoint)mPoint withWidth:(int)width withHeight:(int)height {
    //裁剪后的图片
    IplImage *cropImage;
    // 为给定矩形设置图像感兴趣区域（ROI）
    cvSetImageROI(srcIpl, cvRect(mPoint.x, mPoint.y, width, height));
    // 创建IplImage图像
    cropImage = cvCreateImage(cvGetSize(srcIpl), IPL_DEPTH_8U, 3);
    // 该函数将所选元素从输入数组复制到输出数组
    cvCopy(srcIpl, cropImage);
    // 重置图像ROI以包括整个图像并释放ROI结构
    cvResetImageROI(srcIpl);
    return cropImage;
}


@end
