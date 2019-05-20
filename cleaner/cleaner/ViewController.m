//
//  ViewController.m
//  cleaner
//
//  Created by Rzk on 2019/5/15.
//  Copyright © 2019 Rzk. All rights reserved.
//

#import "ViewController.h"
#import "SimilarCompared.h"

#import <malloc/malloc.h>

#import <CocoaImageHashing/CocoaImageHashing.h>

#import <Photos/Photos.h>

//#define kImageNum 11
#define kImageNum 10
#define kTargetSizeWidth 300
#define kTargetSize CGSizeMake(kTargetSizeWidth, kTargetSizeWidth)

@interface ViewController () <UICollectionViewDelegate,UICollectionViewDataSource,PHPhotoLibraryChangeObserver>

/*
 PHAsset: 代表照片库中的一个资源，跟 ALAsset 类似，通过 PHAsset 可以获取和保存资源
 PHFetchOptions: 获取资源时的参数，可以传 nil，即使用系统默认值
 PHFetchResult: 表示一系列的资源集合，也可以是相册的集合
 PHAssetCollection: 表示一个相册或者一个时刻，或者是一个「智能相册（系统提供的特定的一系列相册，例如：最近删除，视频列表，收藏等等，如下图所示）
 PHImageManager: 用于处理资源的加载，加载图片的过程带有缓存处理，可以通过传入一个 PHImageRequestOptions 控制资源的输出尺寸，同异步获取，是否获取iCloud图片等
 PHCachingImageManager: 继承 PHImageManager ，对Photos的图片或视频资源提供了加载或生成预览缩略图和全尺寸图片的方法，针对预处理巨量的资源进行了优化。
 PHImageRequestOptions: 如上面所说，控制加载图片时的一系列参数
 */

@property (nonatomic, strong) PHFetchResult<PHAsset *> *allPhotos; /**< 全部相片*/
@property (nonatomic, strong) PHFetchResult<PHAssetCollection *> *smartAlbums; /**< 全部相册*/
@property (nonatomic, strong) PHFetchResult<PHAssetCollection *> *userCollections; /**< 用户创建的相册*/

@property (nonatomic, strong) PHCachingImageManager *imageManager; /**< 缓存管理*/
@property (nonatomic, strong) PHImageRequestOptions *requestOption; /**< 控制加载图片时的一系列参数*/

@property (nonatomic, strong) UICollectionView *collectionView; /**< 展示view*/
@property (nonatomic, strong) NSMutableArray *dataArray; /**< 数据源*/

@property (nonatomic, strong) PHFetchResult *fetchResult; /**< 操作对象*/

#pragma mark -
@property (nonatomic, strong) NSMutableArray *imageArray; /**< 图像数组*/
@property (nonatomic, strong) UILabel *similar; /**< 相似度*/
@property (nonatomic, assign) NSInteger selectNum; /**< 选中数*/
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	
	// 添加collectionView
	[self.view addSubview:self.collectionView];
    // 获取相册权限
    [self fetchAssetCollection];
    // 获取全部照片
    [self getAllPhoto];
}

#pragma mark - 方向一 相册
#pragma mark - 获取相册权限
- (void)fetchAssetCollection {
    PHFetchOptions *allPhotosOptions = [[PHFetchOptions alloc] init];
    // 按创建时间升序
    allPhotosOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES]];
    // 获取所有照片（按创建时间升序）
    _allPhotos = [PHAsset fetchAssetsWithOptions:allPhotosOptions];
    // 获取所有智能相册
    _smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
    // 获取所有用户创建相册
    _userCollections = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary options:nil];
    //_userCollections = [PHCollectionList fetchTopLevelUserCollectionsWithOptions:nil];
}

/// 获取全部照片
- (void)getAllPhoto {
	
    self.imageManager = [[PHCachingImageManager alloc] init];
    
    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
    
    NSMutableArray *requestIDArray = [NSMutableArray array];
    NSMutableArray *allPhotoData = [NSMutableArray array];
	
	// 计算代码运行时间
	CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
	
    // 获取全部图像
    for (PHAsset *asset in self.allPhotos) {
        [requestIDArray addObject:asset.localIdentifier];
		
        [self.imageManager requestImageDataForAsset:asset options:self.requestOption resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
            if (imageData) {
                [allPhotoData addObject:imageData];
                if ([allPhotoData count] == [self.allPhotos count]) {
					CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
					// 打印运行时间
					NSLog(@"获取所有照片所花时间 %f ms", linkTime * 1000.0);
					
                    [self compareImages:allPhotoData andIDs:requestIDArray];
                }
            }
        }];
    }
}

/// 对比
- (void)compareImages:(NSMutableArray *)allDatas andIDs:(NSMutableArray *)requestIDArray {
    
    NSMutableArray<OSTuple<OSImageId *, NSData *> *> *dataArr = [NSMutableArray new];
    
    for (int i = 0; i < [allDatas count]; i++) {
        OSTuple<OSImageId *, NSData *> *tuple = [OSTuple tupleWithFirst:requestIDArray[i] andSecond:allDatas[i]];
        [dataArr addObject:tuple];
    }
	// 计算代码运行时间
	CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
	
	NSArray<OSTuple<OSImageId *, OSImageId *> *> *similarImageIdsAsTuples = [[OSImageHashing sharedInstance] similarImagesWithHashingQuality:OSImageHashingQualityHigh forImages:dataArr];
	
	CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
	// 打印运行时间
	NSLog(@"对比所花时间 %f ms", linkTime * 1000.0);
	
    NSLog(@"Similar image ids: %@", similarImageIdsAsTuples);
    
    NSMutableArray *similarImageDimensionArray = [NSMutableArray array];
    for (OSTuple *tuple in similarImageIdsAsTuples) {
        NSMutableArray *subArray = [NSMutableArray array];
        [subArray addObject:tuple.first];
        [subArray addObject:tuple.second];
        [similarImageDimensionArray addObject:subArray];
    }
    self.dataArray = similarImageDimensionArray;
    [self.collectionView reloadData];
}

/// 根据ID获取照片                  
- (void)getResultWithRequestID:(NSString *)requestID withHandler:(void(^)(UIImage *image))callBack {
    
    PHImageRequestOptions *option = [[PHImageRequestOptions alloc] init];
    option.synchronous = true;
//    option.resizeMode = PHImageRequestOptionsResizeModeFast;
    option.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    
    // 根据asset的localidentifier（唯一标识）来获取asset
    PHFetchResult *result = [PHAsset fetchAssetsWithLocalIdentifiers:@[requestID] options:nil];
    // 根据获取的results 来获取相应的asset（此时的asset是完整的）
    [result enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        PHAsset *imageAsset = obj;
        // targetSize 是以像素计量的，所以需要实际的 size * UIScreen.mainScreen.scale
        [self.imageManager requestImageForAsset:imageAsset targetSize:kTargetSize contentMode:PHImageContentModeAspectFill options:option resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
            if (callBack) {
                callBack(result);
            }
        }];
    }];
}

#pragma mark - delegate
#pragma mark -- UICollectionViewDelegate
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
//    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
    // 点击的照片
    self.fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[self.dataArray[indexPath.section][indexPath.item]] options:nil];
    // 删除照片
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest deleteAssets:self.fetchResult];
    } completionHandler:^(BOOL success, NSError *error) {
        NSLog(@"Finished updating asset. %@", (success ? @"Success." : error));
        if (!success) {
            NSLog(@"%@",error.description);
        }
    }];
}

#pragma mark -- UICollectionViewDataSource
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
	return self.dataArray.count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
	return 2;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
	UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"UICollectionViewCell" forIndexPath:indexPath];
    cell.contentView.layer.contents = nil;
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self getResultWithRequestID:self.dataArray[indexPath.section][indexPath.item] withHandler:^(UIImage *image) {
            dispatch_async(dispatch_get_main_queue(), ^{
                cell.contentView.layer.contents = (id)image.CGImage;
            });
        }];
    });
    
	return cell;
}

#pragma mark -- PHPhotoLibraryChangeObserver
- (void)photoLibraryDidChange:(PHChange *)changeInstance {
    // Photos may call this method on a background queue;
    // switch to the main queue to update the UI.
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"--------");
//        PHObject *obj =
//        PHObjectChangeDetails *albumChanges = [changeInstance changeDetailsForObject:changeInstance];
//        changeDetailsForFetchResult
    });
}

#pragma mark - getting
- (UICollectionView *)collectionView {
	if (!_collectionView) {
		
		// 设置 flowLayout
		UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
		flowLayout.minimumInteritemSpacing = 40;
		flowLayout.minimumLineSpacing = 40;
		flowLayout.sectionInset = UIEdgeInsetsMake(10, 40, 10, 40);
		CGFloat width = (self.view.frame.size.width - flowLayout.minimumInteritemSpacing*3)/2;
		flowLayout.itemSize = CGSizeMake(width, width);
		flowLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
		
		_collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:flowLayout];
		
		_collectionView.contentInset = UIEdgeInsetsMake(40, 0, 40, 0);
		_collectionView.delegate = self;
		_collectionView.dataSource = self;
		_collectionView.backgroundColor = [UIColor clearColor];
		
		// 注册 cell
		[_collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"UICollectionViewCell"];
	}
	return _collectionView;
}

- (PHImageRequestOptions *)requestOption {
    if (!_requestOption) {
        _requestOption = [[PHImageRequestOptions alloc] init];
        _requestOption.synchronous = false;
        // 若设置 PHImageRequestOptionsResizeModeExact 则 requestImageForAsset 下来的图片大小是 targetSize 的
        _requestOption.resizeMode = PHImageRequestOptionsResizeModeExact;
        // 图像质量。
        // 有三种值：Opportunistic，在速度与质量中均衡；
        // HighQualityFormat，不管花费多长时间，提供高质量图像；
        // FastFormat，以最快速度提供好的质量。这个属性只有在 synchronous 为 NO 时有效。
        _requestOption.deliveryMode = PHImageRequestOptionsDeliveryModeFastFormat;
    }
    return _requestOption;
}

#pragma mark - 方向二 图片对比
#pragma mark - InitUI
- (void)initUI {
    self.imageArray = [NSMutableArray array];
    
    CGFloat width = 140;
    CGFloat xPadding = 10;
    CGFloat yPadding = 10;
    
    CGFloat x = (self.view.frame.size.width - (width+xPadding) * 2 + xPadding)/2;
    
    for (int i = 0; i < kImageNum; i++) {
        UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(x + (i%2)*(width+xPadding), 50 + (i/2)*(width+yPadding), width, width)];
        
        NSString *preStr;
        if (kImageNum == 10) {
            preStr = @"image_";
        } else {
            preStr = @"image_0_";
        }
        
        NSString *imageName = [NSString stringWithFormat:@"%@%d",preStr,i];
        UIImage *image = [UIImage imageNamed:imageName];
        
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
    
    dispatch_sync(dispatch_get_global_queue(0, 0), ^{
        // 计算代码运行时间
        CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
        
        [self findDuplicates];
        
        CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
        // 打印运行时间
        NSLog(@"Linked in %f ms", linkTime * 1000.0);
    });
}

#pragma mark - 点击事件
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
        
        // 计算代码运行时间
        CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
        
        CGFloat percent = [[SimilarCompared sharedInstance] similarFromImage:image1 toImage:image2];
        
        CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
        // 打印运行时间
        NSLog(@"Linked in %f ms", linkTime * 1000.0);
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

#pragma mark - func
- (void)findDuplicates {
    
    NSMutableArray<OSTuple<OSImageId *, NSData *> *> *dataArr = [NSMutableArray new];
    
    NSUInteger i = 1;
    for (NSData *data in self.imageArray) {
        OSTuple<OSImageId *, NSData *> *tuple = [OSTuple tupleWithFirst:[NSString stringWithFormat:@"%@", @(i++)] andSecond:data];
        [dataArr addObject:tuple];
    }
    
    NSArray<OSTuple<OSImageId *, OSImageId *> *> *similarImageIdsAsTuples = [[OSImageHashing sharedInstance] similarImagesWithHashingQuality:OSImageHashingQualityHigh forImages:dataArr];
    
    NSLog(@"Similar image ids: %@", similarImageIdsAsTuples);
    
//    OSHashDistanceType distence = [[OSImageHashing sharedInstance] hashDistanceSimilarityThresholdWithProvider:OSImageHashingProviderAHash];
//    NSLog(@"阀值---OSImageHashingProviderAHash---%lld",distence);
//    distence = [[OSImageHashing sharedInstance] hashDistanceSimilarityThresholdWithProvider:OSImageHashingProviderDHash];
//    NSLog(@"阀值---OSImageHashingProviderDHash---%lld",distence);
//    distence = [[OSImageHashing sharedInstance] hashDistanceSimilarityThresholdWithProvider:OSImageHashingProviderPHash];
//    NSLog(@"阀值---OSImageHashingProviderPHash---%lld",distence);
//    distence = [[OSImageHashing sharedInstance] hashDistanceSimilarityThresholdWithProvider:OSImageHashingProviderNone];
//    NSLog(@"阀值---OSImageHashingProviderNone---%lld",distence);
}

@end
