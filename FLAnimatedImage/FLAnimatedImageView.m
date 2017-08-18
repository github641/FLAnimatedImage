//
//  FLAnimatedImageView.h
//  Flipboard
//
//  Created by Raphael Schaad on 7/8/13.
//  Copyright (c) 2013-2015 Flipboard. All rights reserved.
//


#import "FLAnimatedImageView.h"
#import "FLAnimatedImage.h"
#import <QuartzCore/QuartzCore.h>

/* lzy注170818：
 只在定义了debug和debug宏的值为1的时候，才会有的protocol
 */
#if defined(DEBUG) && DEBUG
@protocol FLAnimatedImageViewDebugDelegate <NSObject>
@optional
- (void)debug_animatedImageView:(FLAnimatedImageView *)animatedImageView waitingForFrame:(NSUInteger)index duration:(NSTimeInterval)duration;
@end
#endif


@interface FLAnimatedImageView ()

/* lzy注170817：
 在头文件的属性：
 @property (nonatomic, strong, readonly) UIImage *currentFrame;
 @property (nonatomic, assign, readonly) NSUInteger currentFrameIndex;
 
 在.m中把属性修饰符做了修改，把外边的修饰符重写了。
 
 其实就算是readonly修饰，也可以通过kvc的形式获取吧？
 */
// Override of public `readonly` properties as private `readwrite`
@property (nonatomic, strong, readwrite) UIImage *currentFrame;
@property (nonatomic, assign, readwrite) NSUInteger currentFrameIndex;

/* lzy注170818：
 循环计数
 */
@property (nonatomic, assign) NSUInteger loopCountdown;

/**
 参数名意思是累加器。是NSTImeINterval类型。
 */
@property (nonatomic, assign) NSTimeInterval accumulator;
@property (nonatomic, strong) CADisplayLink *displayLink;

/* lzy注170817：
 在检查这个值之前，需要调用一下『-updateShouldAnimate』方法，不管 『animated image』存在的状态做出了改变，还是 『animated image』的可见属性被改变了。
 */
@property (nonatomic, assign) BOOL shouldAnimate; // Before checking this value, call `-updateShouldAnimate` whenever the animated image or visibility (window, superview, hidden, alpha) has changed.
@property (nonatomic, assign) BOOL needsDisplayWhenImageBecomesAvailable;

/* lzy注170817：
 如果定义了DEBUG并且正处于DEBUG模式，本类有一个调试delegate属性
 */
#if defined(DEBUG) && DEBUG
@property (nonatomic, weak) id<FLAnimatedImageViewDebugDelegate> debug_delegate;
#endif

@end


@implementation FLAnimatedImageView
/* lzy注170817：
 使用@synthesize 指定.h中与runLoopMode属性对应的实例变量为_runLoopMode,即实际使用中是_runLoopMode
 
 
 4.@property，@dynamic与@synthesize的区别
 
 @property：在iOS5之后编译器从GCC转换为LLVM，@property声明的属性默认会生成一个_类型的成员变量，同时也会生成setter/getter方法。在iOS5之前，属性的正常写法需要 成员变量 + @property + @synthesize 成员变量三个步骤。如下：
 @interface ViewController ()
 {
 // 1.声明成员变量
 NSString *myString;
 }
 //2.在用@property
 @property(nonatomic, copy) NSString *myString;
 @end
 
 @implementation ViewController
 //3.最后在@implementation中用synthesize生成setter&getter方法
 @synthesize myString;
 @end
 @synthesize：于是synthesize两个作用：一是如果你没有手动实现setter方法和getter方法，那么编译器会自动为你加上这两个方法。二是可以指定与属性对应的实例变量（自定义Property所对应的实例变量）， 例如@synthesize myString = xxx，这时实例变量就是xxx。
 
 @synthesize自动生成setter方法和getter方法举例：
 
 实现文件(.m)中
 　　@synthesize count;
 　　等效于在实现文件(.m)中实现2个方法。
 　　- (int)count
 　　{
 　　return count;
 　　}
 　　-(void)setCount:(int)newCount
 　　{
 　　count = newCount;
 　　}
 @dynamic：@dynamic告诉编译器,属性的setter与getter方法由用户自己实现，不自动生成。
 
 作者：木格措的天空
 链接：http://www.jianshu.com/p/94fb8b816147
 來源：简书
 著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。
 
 */
@synthesize runLoopMode = _runLoopMode;

#pragma mark - Initializers
// 在文档中不是指定的初始化方法
// -initWithImage: isn't documented as a designated initializer of UIImageView, but it actually seems to be.
// Using -initWithImage: doesn't call any of the other designated initializers.
- (instancetype)initWithImage:(UIImage *)image
{
    self = [super initWithImage:image];
    if (self) {
        [self commonInit];
    }
    return self;
}
// 没有在文档中出现的方法

// -initWithImage:highlightedImage: also isn't documented as a designated initializer of UIImageView, but it doesn't call any other designated initializers.
- (instancetype)initWithImage:(UIImage *)image highlightedImage:(UIImage *)highlightedImage
{
    self = [super initWithImage:image highlightedImage:highlightedImage];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}
/* lzy注170816：
 重写上面那么多方法，目的就是这个方法中，对runLoopMode进行默认的配置。
 -defaultRunLoopMode是本类的一个方法，返回一个字符串。NSRunLoopCommonModes （集合） NSDefaultRunLoopMode（默认的一个runloop模式）
 */
- (void)commonInit
{
    self.runLoopMode = [[self class] defaultRunLoopMode];
}


#pragma mark - Accessors （访问器）
#pragma mark Public

- (void)setAnimatedImage:(FLAnimatedImage *)animatedImage
{

    if (![_animatedImage isEqual:animatedImage]) {
        // 进入这个大括号，符合下面条件之一
        // 1、图片不存在FLAnimatedImageView.animatedImage不存在或者animatedImage不存在
        // 2、两者存在但是notEqual
        
        // 这个if else#处理『传入参数』存在和不存在的情况#
        if (animatedImage) {
            // 传入参数存在
  
            // Clear out the image.
            super.image = nil;
            // Ensure disabled highlighting; it's not supported (see `-setHighlighted:`).
            super.highlighted = NO;
            // UIImageView seems to bypass some accessors when calculating its intrinsic content size, so this ensures its intrinsic content size comes from the animated image.
            // UIImageView在计算它本身内容的size的时候，似乎绕开了一些『accessors』。保证它本身内容的size来自animated image。
            /* lzy注170816：
             Invalidates the view’s intrinsic content size.
             Call this when something changes in your custom view that invalidates its intrinsic content size. This allows the constraint-based layout system to take the new intrinsic content size into account in its next layout pass.
             Availability	iOS (6.0 and later), tvOS (6.0 and later)
             这个是UIView的方法。
             http://www.jianshu.com/p/69358b33e0f6
             ntrinsic Contenet Size – Intrinsic Content Size：固有的大小。
             
             在AutoLayout中，它作为UIView的属性（不是语法上的属性），意思就是说我知道自己的大小，如果你没有为我指定大小，我就按照这个大小来。
             
             比如：大家都知道在使用AutoLayout的时候，UILabel是不用指定尺寸大小的，只需指定位置即可，就是因为，只要确定了文字内容，字体等信息，它自己就能计算出大小来。
             
             同样的UILabel，UIImageView，UIButton等这些组件及某些包含它们的系统组件都有 Intrinsic Content Size 属性，也就说他们都有自己计算size的能力。
             */
            [self invalidateIntrinsicContentSize];
        } else {
            // 传入参数为空
            // Stop animating before the animated image gets cleared out.
            [self stopAnimating];
        }
        

//        把UIImageView.image转移到他的『posterImage』。然后将持有本类的currentFrame并开始做动画。
        
        // setter本来应该做的事情，持有新变量
        _animatedImage = animatedImage;
        
        // 这是UIImage对象
        self.currentFrame = animatedImage.posterImage;
        self.currentFrameIndex = 0;
        if (animatedImage.loopCount > 0) {// gif轮播次数处理
            self.loopCountdown = animatedImage.loopCount;
        } else {
            self.loopCountdown = NSUIntegerMax;
        }
        self.accumulator = 0.0;
        
        // Start animating after the new animated image has been set.
        
        // self.shouldAnimate = self.animatedImage && self.window && self.superview && ![self isHidden] && self.alpha > 0.0;
        [self updateShouldAnimate];
        
        if (self.shouldAnimate) {
            [self startAnimating];
        }
        
        [self.layer setNeedsDisplay];
    }
}


#pragma mark - Life Cycle

- (void)dealloc
{
    // Removes the display link from all run loop modes.
    /* Removes the object from all runloop modes (releasing the receiver if
     * it has been implicitly retained) and releases the 'target' object. */
    [_displayLink invalidate];
}


#pragma mark - UIView Method Overrides
#pragma mark Observing View-Related Changes
/* lzy注170818：
 重写UIView的方法。
 监听的是 View相关的改变
 */

/* lzy注170818：
 Tells the view that its superview changed.
 The default implementation of this method does nothing. Subclasses can override it to perform additional actions whenever the superview changes.
 Availability	iOS (2.0 and later), tvOS (9.0 and later)
 
 1.调用super的方法。
 2.检查图片『是否应该做动画』的标识
 3.应当就开始，不应该就停止
 */
- (void)didMoveToSuperview
{
    [super didMoveToSuperview];
    
    [self updateShouldAnimate];
    if (self.shouldAnimate) {
        [self startAnimating];
    } else {
        [self stopAnimating];
    }
}

/* lzy注170818：
 Tells the view that its window object changed.
 The default implementation of this method does nothing. Subclasses can override it to perform additional actions whenever the window changes.
 The window property may be nil by the time that this method is called, indicating that the receiver does not currently reside in any window. This occurs when the receiver has just been removed from its superview or when the receiver has just been added to a superview that is not attached to a window. Overrides of this method may choose to ignore such cases if they are not of interest.
 Availability	iOS (2.0 and later), tvOS (9.0 and later)
 */
- (void)didMoveToWindow
{
    [super didMoveToWindow];
    
    [self updateShouldAnimate];
    if (self.shouldAnimate) {
        [self startAnimating];
    } else {
        [self stopAnimating];
    }
}
/* lzy注170818：
 The view’s alpha value.
 The value of this property is a floating-point number in the range 0.0 to 1.0, where 0.0 represents totally transparent and 1.0 represents totally opaque. This value affects only the current view and does not affect any of its embedded subviews.
 Changes to this property can be animated.
 Availability	iOS (2.0 and later), tvOS (9.0 and later)

 联想到有一个注意事项：设置SFSafariViewController的view的最小值是0.05，如果为0，系统直接就展示了。
 
 */
- (void)setAlpha:(CGFloat)alpha
{
    [super setAlpha:alpha];

    [self updateShouldAnimate];
    if (self.shouldAnimate) {
        [self startAnimating];
    } else {
        [self stopAnimating];
    }
}
/* lzy注170818：
 A Boolean value that determines whether the view is hidden.
 Setting the value of this property to YES hides the receiver and setting it to NO shows the receiver. The default value is NO.
 A hidden view disappears from its window and does not receive input events. It remains in its superview’s list of subviews, however, and participates in autoresizing as usual. Hiding a view with subviews has the effect of hiding those subviews and any view descendants they might have. This effect is implicit and does not alter the hidden state of the receiver’s descendants（后代、子视图、子节点）.
 Hiding the view that is the window’s current first responder causes the view’s next valid key view to become the new first responder.
 The value of this property reflects the state of the receiver only and does not account for the state of the receiver’s ancestors in the view hierarchy. Thus this property can be NO but the receiver may still be hidden if an ancestor is hidden.
 Availability	iOS (2.0 and later), tvOS (9.0 and later)
 */
- (void)setHidden:(BOOL)hidden
{
    [super setHidden:hidden];

    [self updateShouldAnimate];
    if (self.shouldAnimate) {
        [self startAnimating];
    } else {
        [self stopAnimating];
    }
}


#pragma mark Auto Layout
/* lzy注170818：
 @property(nonatomic, readonly) CGSize intrinsicContentSize;
 Description
 The natural size for the receiving view, considering only properties of the view itself.
 Custom views typically have content that they display of which the layout system is unaware. Setting this property allows a custom view to communicate to the layout system what size it would like to be based on its content. This intrinsic size must be independent of the content frame, because there’s no way to dynamically communicate a changed width to the layout system based on a changed height, for example.
 If a custom view has no intrinsic size for a given dimension, it can use UIViewNoIntrinsicMetric for that dimension.
 Availability	iOS (6.0 and later), tvOS (6.0 and later)
 */
- (CGSize)intrinsicContentSize
{
    // Default to let UIImageView handle the sizing of its image, and anything else it might consider.
    CGSize intrinsicContentSize = [super intrinsicContentSize];
    
    // If we have have an animated image, use its image size.
    // UIImageView's intrinsic content size seems to be the size of its image. The obvious approach, simply calling `-invalidateIntrinsicContentSize` when setting an animated image, results in UIImageView steadfastly returning `{UIViewNoIntrinsicMetric, UIViewNoIntrinsicMetric}` for its intrinsicContentSize.
    // (Perhaps UIImageView bypasses its `-image` getter in its implementation of `-intrinsicContentSize`, as `-image` is not called after calling `-invalidateIntrinsicContentSize`.)
    if (self.animatedImage) {
        intrinsicContentSize = self.image.size;
    }
    
    return intrinsicContentSize;
}


#pragma mark - UIImageView Method Overrides
#pragma mark Image Data

/* lzy注170818：
 重写UIImageView的方法
 */

/* lzy注170818：
 @property(nonatomic, strong) UIImage *image;
 Description
 The image displayed in the image view.
 This property contains the main image displayed by the image view. This image is displayed when the image view is in its natural state. When highlighted, the image view displays the image in its highlightedImage property instead. If that property is set to nil, the image view applies a default highlight to this image. If the animationImages property contains a valid set of images, those images are used instead.
 Changing the image in this property does not automatically change the size of the image view. After setting the image, call the sizeToFit method to recompute the image view’s size based on the new image and the active constraints.
 This property is set to the image you specified at initialization time. If you did not use the initWithImage: or initWithImage:highlightedImage: method to initialize your image view, the initial value of this property is nil.
 Availability	iOS (2.0 and later), tvOS (9.0 and later)
 */
- (UIImage *)image
{
    UIImage *image = nil;
    if (self.animatedImage) {
        // Initially set to the poster image.
        image = self.currentFrame;
    } else {
        image = super.image;
    }
    return image;
}


- (void)setImage:(UIImage *)image
{
    if (image) {
        // Clear out the animated image and implicitly pause animation playback.
        self.animatedImage = nil;
    }
    
    super.image = image;
}


#pragma mark Animating Images
/* lzy注170817：
 MAX函数的参数之一
 */
- (NSTimeInterval)frameDelayGreatestCommonDivisor
{
    /* lzy注170817：
     这个单词应该打错了吧，
     precision n. 精度。
     
     `kFLAnimatedImageDelayTimeIntervalMinimum`最快的浏览器一般定义的：动图延迟时间间隔最小值。
     
     
     */
    // Presision is set to half of the `kFLAnimatedImageDelayTimeIntervalMinimum` in order to minimize frame dropping.
    
    const NSTimeInterval kGreatestCommonDivisorPrecision = 2.0 / kFLAnimatedImageDelayTimeIntervalMinimum;

    NSArray *delays = self.animatedImage.delayTimesForIndexes.allValues;

    // Scales the frame delays by `kGreatestCommonDivisorPrecision`
    // then converts it to an UInteger for in order to calculate the GCD.
    // lrint 转为一个double类型
    NSUInteger scaledGCD = lrint([delays.firstObject floatValue] * kGreatestCommonDivisorPrecision);
    for (NSNumber *value in delays) {
        // 求最大公约数
        scaledGCD = gcd(lrint([value floatValue] * kGreatestCommonDivisorPrecision), scaledGCD);
    }

    // Reverse to scale to get the value back into seconds.
    return scaledGCD / kGreatestCommonDivisorPrecision;
}


static NSUInteger gcd(NSUInteger a, NSUInteger b)
{
    /* lzy注170817：
     最大公约数
     */
    // http://en.wikipedia.org/wiki/Greatest_common_divisor
    if (a < b) {
        return gcd(b, a);
    } else if (a == b) {
        return b;
    }

    while (true) {
        NSUInteger remainder = a % b;
        if (remainder == 0) {
            return b;
        }
        a = b;
        b = remainder;
    }
}

/* lzy注170817：
 animatedImage的setter方法中，将调用这个方法。
 */
- (void)startAnimating
{
    if (self.animatedImage) {
        // Lazily create the display link.
        if (!self.displayLink) {
            // It is important to note the use of a weak proxy here to avoid a retain cycle. `-displayLinkWithTarget:selector:`
            
            // will retain its target until it is invalidated. We use a weak proxy so that the image view will get deallocated
            
            // independent of the display link's lifetime. Upon image view deallocation, we invalidate the display
            
            // link which will lead to the deallocation of both the display link and the weak proxy.
            
            /* lzy注170816：
             为避免循环引用。采用 weak proxy。
             FLWeakProxy继承自 root class ：NSProxy。
             */
            FLWeakProxy *weakProxy = [FLWeakProxy weakProxyForObject:self];
            self.displayLink = [CADisplayLink displayLinkWithTarget:weakProxy selector:@selector(displayDidRefresh:)];
            
            [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:self.runLoopMode];
        }

        // Note: The display link's `.frameInterval` value of 1 (default) means getting callbacks at the refresh rate of the display (~60Hz).
        // Setting it to 2 divides the frame rate by 2 and hence calls back at every other display refresh.
        
        
        const NSTimeInterval kDisplayRefreshRate = 60.0; // 60Hz
        
//     [self frameDelayGreatestCommonDivisor]方法，是下面MAX函数的参数之一
        self.displayLink.frameInterval = MAX([self frameDelayGreatestCommonDivisor] * kDisplayRefreshRate, 1);

        self.displayLink.paused = NO;
    } else {
        // 调用UIImageView的方法
        [super startAnimating];
    }
}

- (void)setRunLoopMode:(NSString *)runLoopMode
{
    if (![@[NSDefaultRunLoopMode, NSRunLoopCommonModes] containsObject:runLoopMode]) {
        NSAssert(NO, @"Invalid run loop mode: %@", runLoopMode);
        _runLoopMode = [[self class] defaultRunLoopMode];
    } else {
        _runLoopMode = runLoopMode;
    }
}

- (void)stopAnimating
{
    // 如果传入参数为nil，但是self.animatedImage有值，定时器暂停
    if (self.animatedImage) {
        self.displayLink.paused = YES;
    } else {
        [super stopAnimating];
    }
}

/* lzy注170818：
 Returns a Boolean value indicating whether the animation is running.
 Returns
 YES if the animation is running; otherwise, NO.
 Availability	iOS (10.0 and later), tvOS (10.0 and later)
 */
- (BOOL)isAnimating
{
    BOOL isAnimating = NO;
    if (self.animatedImage) {
        isAnimating = self.displayLink && !self.displayLink.isPaused;
    } else {
        isAnimating = [super isAnimating];
    }
    return isAnimating;
}


#pragma mark Highlighted Image Unsupport

/* lzy注170818：
 不支持高亮图片状态
 */

/* lzy注170818：
 @property(nonatomic, getter=isHighlighted) BOOL highlighted;
 Description
 A Boolean value that determines whether the image is highlighted.
 This property determines whether the regular or highlighted images are used. When highlighted is set to YES, a non-animated image will use the highlightedImage property and an animated image will use the highlightedAnimationImages. If both of those properties are set to nil or if highlighted is set to NO, it will use the image and animationImages properties.
 Availability	iOS (3.0 and later), tvOS (3.0 and later)
 */
- (void)setHighlighted:(BOOL)highlighted
{
    // Highlighted image is unsupported for animated images, but implementing it breaks the image view when embedded in a UICollectionViewCell.
    if (!self.animatedImage) {
        [super setHighlighted:highlighted];
    }
}


#pragma mark - Private Methods
#pragma mark Animation

// Don't repeatedly check our window & superview in `-displayDidRefresh:` for performance reasons.
// Just update our cached value whenever the animated image or visibility (window, superview, hidden, alpha) is changed.
- (void)updateShouldAnimate
{
    BOOL isVisible = self.window && self.superview && ![self isHidden] && self.alpha > 0.0;
    self.shouldAnimate = self.animatedImage && isVisible;
}

/* lzy注170817：
 self.dispalyLink 定时调用的方法
 */
- (void)displayDidRefresh:(CADisplayLink *)displayLink
{
    // If for some reason a wild call makes it through when we shouldn't be animating, bail.
    // Early return!
    if (!self.shouldAnimate) {
        FLLog(FLLogLevelWarn, @"Trying to animate image when we shouldn't: %@", self);
        return;
    }
    
    // 从animatedImage对象中的字典（存放每一帧图片播放完毕之后应该延迟的时间）
    NSNumber *delayTimeNumber = [self.animatedImage.delayTimesForIndexes objectForKey:@(self.currentFrameIndex)];
    // If we don't have a frame delay (e.g. corrupt frame), don't update the view but skip the playhead to the next frame (in else-block).
    
    // 播放完毕一帧之后，加入从animatedImage
    if (delayTimeNumber) {
        NSTimeInterval delayTime = [delayTimeNumber floatValue];
        
        // 获取懒缓存的当前帧的图片
        // If we have a nil image (e.g. waiting for frame), don't update the view nor playhead.
        UIImage *image = [self.animatedImage imageLazilyCachedAtIndex:self.currentFrameIndex];
        
        // 懒缓存图片存在做处理，不存在，打印log和debug回调，其他什么也不做
        if (image) {
            FLLog(FLLogLevelVerbose, @"Showing frame %lu for animated image: %@", (unsigned long)self.currentFrameIndex, self.animatedImage);// 打印要展示的帧索引和帧图片
            self.currentFrame = image;
            if (self.needsDisplayWhenImageBecomesAvailable) {// 当图片变得可用了，需要展示标识为真
                [self.layer setNeedsDisplay];// 刷新layer，并至标志位为NO
                self.needsDisplayWhenImageBecomesAvailable = NO;
            }
            
            /* lzy注170818：
             1.duration属性:提供了每帧之间的时间，也就是屏幕每次刷新之间的的时间。该属性在target的selector被首次调用以后才会被赋值。selector的调用间隔时间计算方式是：时间=duration×frameInterval。 我们可以使用这个时间来计算出下一帧要显示的UI的数值。但是 duration只是个大概的时间，如果CPU忙于其它计算，就没法保证以相同的频率执行屏幕的绘制操作，这样会跳过几次调用回调方法的机会。
             2.frameInterval属性:是可读可写的NSInteger型值，标识间隔多少帧调用一次selector 方法，默认值是1，即每帧都调用一次。如果每帧都调用一次的话，对于iOS设备来说那刷新频率就是60HZ也就是每秒60次，如果将 frameInterval 设为2 那么就会两帧调用一次，也就是变成了每秒刷新30次。
             
             作者：huanghy
             链接：http://www.jianshu.com/p/62d6d1c21456
             來源：简书
             著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。
             */
            
            self.accumulator += displayLink.duration * displayLink.frameInterval;
            
            // While-loop first inspired by & good Karma to: https://github.com/ondalabs/OLImageView/blob/master/OLImageView.m
            while (self.accumulator >= delayTime) {
                self.accumulator -= delayTime;
                self.currentFrameIndex++;
                if (self.currentFrameIndex >= self.animatedImage.frameCount) {
                    // If we've looped the number of times that this animated image describes, stop looping.
                    self.loopCountdown--;
                    if (self.loopCompletionBlock) {
                        self.loopCompletionBlock(self.loopCountdown);
                    }
                    
                    if (self.loopCountdown == 0) {
                        [self stopAnimating];
                        return;
                    }
                    self.currentFrameIndex = 0;
                }
                // Calling `-setNeedsDisplay` will just paint the current frame, not the new frame that we may have moved to.
                // Instead, set `needsDisplayWhenImageBecomesAvailable` to `YES` -- this will paint the new image once loaded.
                self.needsDisplayWhenImageBecomesAvailable = YES;
            }
        } else {
            FLLog(FLLogLevelDebug, @"Waiting for frame %lu for animated image: %@", (unsigned long)self.currentFrameIndex, self.animatedImage);
#if defined(DEBUG) && DEBUG
            if ([self.debug_delegate respondsToSelector:@selector(debug_animatedImageView:waitingForFrame:duration:)]) {
                [self.debug_delegate debug_animatedImageView:self waitingForFrame:self.currentFrameIndex duration:(NSTimeInterval)displayLink.duration * displayLink.frameInterval];
            }
#endif
        }
    } else {
        self.currentFrameIndex++;
    }
}

+ (NSString *)defaultRunLoopMode
{
    // Key off `activeProcessorCount` (as opposed to `processorCount`) since the system could shut down cores in certain situations.
    /* lzy注170816：
     在本类的common init中回调用这个方法。
     根据设备当前活跃的处理器核心个数，来决定runloop 模式
     */
    return [NSProcessInfo processInfo].activeProcessorCount > 1 ? NSRunLoopCommonModes : NSDefaultRunLoopMode;
}


#pragma mark - CALayerDelegate (Informal)
#pragma mark Providing the Layer's Content

- (void)displayLayer:(CALayer *)layer
{
    layer.contents = (__bridge id)self.image.CGImage;
}


@end
