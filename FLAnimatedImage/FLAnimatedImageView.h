//
//  FLAnimatedImageView.h
//  Flipboard
//
//  Created by Raphael Schaad on 7/8/13.
//  Copyright (c) 2013-2015 Flipboard. All rights reserved.
//
/* lzy注170816：
 本类库的基本使用方法：
 1、图片data已经请求会来了，或者缓存了：已经有可用的二进制数据。
 2、FLAnimatedImage *image = [[FLAnimatedImage alloc] initWithAnimatedGIFData:data];
 使用data创建FLAnimatedImage对象。
 3、FLAnimatedImageView *imageView = [[FLAnimatedImageView alloc] init];
 创建视图
 4、imageView.animatedImage = image;
 */

#import <UIKit/UIKit.h>
/* lzy注170816：
 再次看到这个现象。看到不少开源类库，会先声明一个类存在，并将protocol的代码前置。
 
 我个人常常是先声明protocol，把类完善，涉及到protocol再写。
 如果是惯例的话，需要遵循。
 */
@class FLAnimatedImage;
@protocol FLAnimatedImageViewDebugDelegate;



//  An `FLAnimatedImageView` can take an `FLAnimatedImage` and plays it automatically when in view hierarchy and stops when removed.
//  The animation can also be controlled with the `UIImageView` methods `-start/stop/isAnimating`.
//  It is a fully compatible `UIImageView` subclass and can be used as a drop-in component to work with existing code paths expecting to display a `UIImage`.
//  Under the hood it uses a `CADisplayLink` for playback, which can be inspected with `currentFrame` & `currentFrameIndex`.
//
/* lzy注170816：
 自动播放『FLAnimatedImage』，图片控件被移除自动停止播放。
 动画可以使用『UIImageView』本身的startAnimating、stopAnimating、isAnimating
 "UIImageView的子类"，完全兼容。
 使用『CADisplayLink』作播放，CADisplayLink可以使用`currentFrame` & `currentFrameIndex`做检查。`currentFrame` & `currentFrameIndex`
 */
@interface FLAnimatedImageView : UIImageView

// Setting `[UIImageView.image]` to a non-`nil` value clears out existing `animatedImage`.
// And vice versa, setting `animatedImage` will initially populate the `[UIImageView.image]` to its `posterImage` and then start animating and hold `currentFrame`.
/* lzy注170816：
 对UIImageView.image赋值图片对象，将把本类已经存在的animatedImage清除。
 反之亦然，给本类的animatedImage赋值，将做初始化处理工作：把UIImageView.image转移到他的『posterImage』。然后将持有本类的currentFrame并开始做动画。
 */
@property (nonatomic, strong) FLAnimatedImage *animatedImage;
/* lzy注170818：
 //播放了一帧播放之后都会回调
 */
@property (nonatomic, copy) void(^loopCompletionBlock)(NSUInteger loopCountRemaining);
/* lzy注170818：
 当前帧图片
 */
@property (nonatomic, strong, readonly) UIImage *currentFrame;
/* lzy注170818：
 当前帧索引
 */
@property (nonatomic, assign, readonly) NSUInteger currentFrameIndex;

// The animation runloop mode. Enables playback during scrolling by allowing timer events (i.e. animation) with NSRunLoopCommonModes.
// To keep scrolling smooth on single-core devices such as iPhone 3GS/4 and iPod Touch 4th gen, the default run loop mode is NSDefaultRunLoopMode. Otherwise, the default is NSDefaultRunLoopMode.
/* lzy注170816：
 动画的runloop模式。
 模式决定了，在滚动视图时是否允许 定时器 时间的 回调。
 为了在单核设备（iPhone 3GS/4 and iPod T ouch 4th gen）上滚动流畅。默认的runloop模式是NSDefaultRunLoopMode。
 */
@property (nonatomic, copy) NSString *runLoopMode;

@end
