//
//  HMCycleView.m
//  HMCycleView
//
//  Created by HaoYoson on 16/1/29.
//  Copyright © 2016年 YosonHao. All rights reserved.
//

#import "HMCycleView.h"

@interface NSTimer (Addition)

/**
 *  暂定当前时间对象
 */
- (void)pauseTimer;

/**
 * 当前时间对象
 */
- (void)resumeTimer;

/**
 *  一定时间后恢复定时器对象
 *
 *  @param interval 时间
 */
- (void)resumeTimerAfterTimeInterval:(NSTimeInterval)interval;
@end

@implementation NSTimer (Addition)

- (void)pauseTimer
{
    if (![self isValid]) {
        return;
    }
    [self setFireDate:[NSDate distantFuture]];
}

- (void)resumeTimer
{
    if (![self isValid]) {
        return;
    }
    [self setFireDate:[NSDate date]];
}

- (void)resumeTimerAfterTimeInterval:(NSTimeInterval)interval
{
    if (![self isValid]) {
        return;
    }
    [self setFireDate:[NSDate dateWithTimeIntervalSinceNow:interval]];
}

@end

@interface HMCycleView () <UICollectionViewDelegate, UICollectionViewDataSource>

@property (assign, nonatomic) NSInteger currentViewIndex;

@property (assign, nonatomic) CGFloat currentOffsetX;

@property (strong, nonatomic) NSTimer *animationTimer;

@end

@implementation HMCycleView

// 重用标识符
static NSString *const reuseIdentifier = @"cycleViewCell";

#pragma mark - init

// 初始化的时候创建layout布局
- (instancetype)initWithFrame:(CGRect)frame
{

    // 注册单元格
    [self registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:reuseIdentifier];

    // 创建流水布局
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];

    // cell大小为自身大小
    layout.itemSize = frame.size;
    // 横向滚动
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    // cell间距为0
    layout.minimumLineSpacing = 0;

    return [super initWithFrame:frame collectionViewLayout:layout];
}

#pragma mark - 公有方法

/**
 *  初始化数据 并且添加在view上
 *
 *  @param view 需要添加到的view
 */
- (void)showInView:(UIView *)view
{

    // 初始化当前view的index为0
    self.currentViewIndex = 0;

    // 设置collectionView的offset为
    if (self.itemViews.count > 1) {
        self.contentOffset = CGPointMake(self.itemViews.count * self.frame.size.width, 0);
    }

    // 记录当前offsetX用来判断翻页
    self.currentOffsetX = self.contentOffset.x;

    // 设置代理和数据源
    self.delegate = self;
    self.dataSource = self;

    self.pagingEnabled = YES;

    self.bounces = NO;

    self.showsHorizontalScrollIndicator = NO;
    self.showsVerticalScrollIndicator = NO;

    // 把所有需要现实的子控件的frame设置和当前view一样大小
    for (UIView *itemView in self.itemViews) {
        itemView.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    }
    [view addSubview:self];

    // 开启定时器 默认两秒向右滚动 - 单张图片不开启时钟
    if (self.itemViews.count > 1) {
        self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:self.duration target:self selector:@selector(scrollToRight) userInfo:nil repeats:YES];
    }
}

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    [super willMoveToWindow:newWindow];

    self.contentInset = UIEdgeInsetsZero;
}

- (void)removeFromSuperview
{
    [super removeFromSuperview];

    [self.animationTimer invalidate];
}

//// 测试循环引用
//- (void)dealloc {
//    NSLog(@"%s", __FUNCTION__);
//}

#pragma mark - 私有方法

// 向右滚动
- (void)scrollToRight
{
    CGPoint newOffset = CGPointMake(self.contentOffset.x + CGRectGetWidth(self.frame), self.contentOffset.y);
    [self setContentOffset:newOffset animated:YES];
}

/**
 *  根据当前的显示的view下标"获取"上一个view下标
 */
- (NSInteger)loadLastIndexWithCurrentIndex:(NSInteger)index
{
    return index == 0 ? self.itemViews.count - 1 : index - 1;
}

/**
 *  根据当前的显示的view下标"获取"下一个view下标
 */
- (NSInteger)loadNextIndexWithCurrentIndex:(NSInteger)index
{
    return index == self.itemViews.count - 1 ? 0 : index + 1;
}

#pragma mark - collectionView数据源方法

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.itemViews.count * 100;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    // 缓存池复用cell
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];

    [cell.contentView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [cell.contentView addSubview:self.itemViews[indexPath.row % self.itemViews.count]];

    return cell;
}

#pragma mark - scrollView代理方法

// 开始拖拽CycleView的时候 暂定定时器
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [self.animationTimer pauseTimer];
}

// 结束拖拽CycleView的时候 默认两秒以后开启定时器
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    [self.animationTimer resumeTimerAfterTimeInterval:self.duration];
}

// offset动画改变完成后调用
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    // 滚动完成后 更改当前view的下标 并刷新
    [self scrollViewDidEndDecelerating:self];
}

// scrollView减速完成-切换一次图片
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    NSInteger offset = (NSInteger)scrollView.contentOffset.x / scrollView.bounds.size.width;
    NSInteger count = [self collectionView:self numberOfItemsInSection:0];

    // 仅处理最末一页和第一页
    if (offset == count - 1 || offset == 0) {
        offset = self.itemViews.count + (offset == 0 ? 0 : -1);

        [self setContentOffset:CGPointMake(offset * scrollView.bounds.size.width, 0) animated:NO];
        [self reloadItemsAtIndexPaths:@[ [NSIndexPath indexPathForItem:offset inSection:0] ]];
    }
}

#pragma mark - get方法

// 如果没有设置默认时间 那么默认时间为2秒钟一次滚动
- (NSTimeInterval)duration
{
    return _duration ?: 2;
}

@end