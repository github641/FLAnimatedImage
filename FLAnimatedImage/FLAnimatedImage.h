//
//  FLAnimatedImage.h
//  Flipboard
//
//  Created by Raphael Schaad on 7/8/13.
//  Copyright (c) 2013-2015 Flipboard. All rights reserved.
//

/* lzy注170816：
 SDWebImage在4.1时，取消了原来的UIImage+Gif的分类来加载动图。
 而是add subModule的形式，使用了本类库来加载动图，并写了一个工具类来和SDWebImage进行契合。
 */

/**
 一个FLAnimatedImage imageView 分类，用于把FLAnimatedImage、imageView放到SDWebImage中来。
 
 与基本分类UIImageView(WebCache)的使用非常相似

 使用给定的url，加载image，图片可能是下载的、缓存的。
 并把image放到控件上。
 它对静态图片和动态图片都有效。
 
 根据url下载图片的操作是异步的，并且带有缓存处理。
 在图片下载完成之前，都将使用占位图片。

 */
//- (void)sd_setImageWithURL:(nullable NSURL *)url
//placeholderImage:(nullable UIImage *)placeholder
//options:(SDWebImageOptions)options
//progress:(nullable SDWebImageDownloaderProgressBlock)progressBlock
//completed:(nullable SDExternalCompletionBlock)completedBlock {
//    // 为避免循环引用，使用了weakSelf
//    __weak typeof(self)weakSelf = self;
//    // 使用 UIView+WebCache，即所有的UIImageView和UIButton等调用分类方法后，内部统一会调用的共用的代码（对占位图片、下载图片操作进行管理的代码），抽取出来的类中的方法。
//
//    [self sd_internalSetImageWithURL:url
//                    placeholderImage:placeholder
//                             options:options
//                        operationKey:nil
//                       setImageBlock:^(UIImage *image, NSData *imageData) {
//                           // 回调
//                           // 判断二进制数据是哪种图片数据
//                           SDImageFormat imageFormat = [NSData sd_imageFormatForImageData:imageData];
//                           // 是Gif，把图片二进制使用FLAnimatedImage生成动图image并赋值给UIImageView的animatedImage，置空UIImageView的image属性。
//                           if (imageFormat == SDImageFormatGIF) {
//                               weakSelf.animatedImage = [FLAnimatedImage animatedImageWithGIFData:imageData];
//                               weakSelf.image = nil;
//                           } else {
//                               weakSelf.image = image;
//                               weakSelf.animatedImage = nil;
//                           }
//                       }
//                            progress:progressBlock
//                           completed:completedBlock];
//}

#import <UIKit/UIKit.h>

// Allow user classes conveniently just importing one header.
#import "FLAnimatedImageView.h"

/* lzy注170818：
 这个宏用来定义下，哪个是 指定的初始化方法
 */
#ifndef NS_DESIGNATED_INITIALIZER
    #if __has_attribute(objc_designated_initializer)
        #define NS_DESIGNATED_INITIALIZER __attribute((objc_designated_initializer))
    #else
        #define NS_DESIGNATED_INITIALIZER
    #endif
#endif

extern const NSTimeInterval kFLAnimatedImageDelayTimeIntervalMinimum;

// 非常重要的类库描述，需要仔细看
//  An `FLAnimatedImage`'s job is to deliver frames in a highly performant way and works in conjunction with `FLAnimatedImageView`.
//  It subclasses `NSObject` and not `UIImage` because it's only an "image" in the sense that a sea lion is a lion.
//  It tries to intelligently（理智的、聪明的） choose the frame cache size depending on the image and memory situation with the goal to lower CPU usage for smaller ones, lower memory usage for larger ones and always deliver frames for high performant play-back.
//  Note: `posterImage`, `size`, `loopCount`, `delayTimes` and `frameCount` don't change after successful initialization.
//

@interface FLAnimatedImage : NSObject

@property (nonatomic, strong, readonly) UIImage *posterImage; // Guaranteed to be loaded; usually equivalent to `-imageLazilyCachedAtIndex:0`
@property (nonatomic, assign, readonly) CGSize size; // The `.posterImage`'s `.size`

@property (nonatomic, assign, readonly) NSUInteger loopCount; // 0 means repeating the animation indefinitely
@property (nonatomic, strong, readonly) NSDictionary *delayTimesForIndexes; // Of type `NSTimeInterval` boxed in `NSNumber`s。内部是 `NSTimeInterval`（实际上是double）装箱后的NSNumber`
@property (nonatomic, assign, readonly) NSUInteger frameCount; // Number of valid frames; equal to `[.delayTimes count]`

@property (nonatomic, assign, readonly) NSUInteger frameCacheSizeCurrent; // Current size of intelligently chosen buffer window; can range in the interval [1..frameCount]
@property (nonatomic, assign) NSUInteger frameCacheSizeMax; // Allow to cap（帽子，覆盖） the cache size; 0 means no specific limit (default)

// Intended to be called from main thread synchronously; will return immediately.
// If the result isn't cached, will return `nil`; the caller should then pause playback, not increment frame counter and keep polling（投票、轮询）.
// After an initial loading time, depending on `frameCacheSize`, frames should be available immediately from the cache.
- (UIImage *)imageLazilyCachedAtIndex:(NSUInteger)index;

// Pass either a `UIImage` or an `FLAnimatedImage` and get back its size
+ (CGSize)sizeForImage:(id)image;

// On success, the initializers return an `FLAnimatedImage` with all fields initialized, on failure they return `nil` and an error will be logged.
- (instancetype)initWithAnimatedGIFData:(NSData *)data;
// Pass 0 for optimalFrameCacheSize to get the default, predrawing is enabled by default.
//  optimal 最佳的
- (instancetype)initWithAnimatedGIFData:(NSData *)data optimalFrameCacheSize:(NSUInteger)optimalFrameCacheSize predrawingEnabled:(BOOL)isPredrawingEnabled NS_DESIGNATED_INITIALIZER;
+ (instancetype)animatedImageWithGIFData:(NSData *)data;

@property (nonatomic, strong, readonly) NSData *data; // The data the receiver was initialized with; read-only

@end

typedef NS_ENUM(NSUInteger, FLLogLevel) {
    FLLogLevelNone = 0,
    FLLogLevelError,
    FLLogLevelWarn,
    FLLogLevelInfo,
    FLLogLevelDebug,
    FLLogLevelVerbose// 冗长的、啰嗦的
};

@interface FLAnimatedImage (Logging)

+ (void)setLogBlock:(void (^)(NSString *logString, FLLogLevel logLevel))logBlock logLevel:(FLLogLevel)logLevel;
+ (void)logStringFromBlock:(NSString *(^)(void))stringBlock withLevel:(FLLogLevel)level;

@end

#define FLLog(logLevel, format, ...) [FLAnimatedImage logStringFromBlock:^NSString *{ return [NSString stringWithFormat:(format), ## __VA_ARGS__]; } withLevel:(logLevel)]

/* lzy注170816：
 大部分接触到的是NSObject的子类。虽然也了解过还有其他的基类。但是没有经历过，子类化一个非NSObject类的情况。
 */
@interface FLWeakProxy : NSProxy

+ (instancetype)weakProxyForObject:(id)targetObject;

@end
