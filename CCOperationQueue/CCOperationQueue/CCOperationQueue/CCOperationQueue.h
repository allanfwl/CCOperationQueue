//
//  CCOperationQueue.h
//  CCKit
//
//  Created by 冯文林  on 2021/5/30.
//  Copyright © 2021 com.allan. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CCOperationLifeCycle, CCAsyncOperationLifeCycle;

typedef enum : NSUInteger {
    CCOperationState_None = 0,
    CCOperationState_Pending, // 排队中
    CCOperationState_Ready, // 就绪。即将在指定线程执行（准确来说是系统的GCD队列）
    CCOperationState_Executing, // 执行中
    CCOperationState_Finish, // 执完结束
    CCOperationState_Cancel, // 被取消
} CCOperationState;

typedef void(^CCOperationExecBlcok)(void);

typedef CCOperationExecBlcok(^CCOperationInitBlcok)(CCOperationLifeCycle * _Nonnull lifeCycle);
typedef CCOperationExecBlcok(^CCAsyncOperationInitBlcok)(CCAsyncOperationLifeCycle * _Nonnull lifeCycle);

NS_ASSUME_NONNULL_BEGIN


#pragma mark - Operation

/// 任务类
@interface CCOperation : NSObject

/// 初始化方法
+(instancetype)operationWithBlock:(CCOperationInitBlcok)block;
-(instancetype)initWithBlock:(CCOperationInitBlcok)block NS_DESIGNATED_INITIALIZER;

+(instancetype)new NS_UNAVAILABLE;
-(instancetype)init NS_UNAVAILABLE;

/// 优先级
@property(nonatomic, assign) NSInteger priority;

/// 重试次数。默认-1
@property(nonatomic, assign) NSInteger retryTimes;

/// 独占（阻塞队列直到此任务执行结束）
@property(nonatomic, assign) BOOL isBarrier;

/// 状态
@property(nonatomic, assign, readonly) CCOperationState state;

/// 将在哪执行。默认dispatch_get_global_queue(0, 0)
@property(nonatomic, strong) dispatch_queue_t execSchedule;

/// 取消
-(void)cancel;

-(void)execute;

@property(nonatomic, copy) NSString *name;

@end


/// 任务生命周期
@interface CCOperationLifeCycle : NSObject

@property(atomic, assign) BOOL retry; // 标记是否重试

@property(nonatomic, copy) void(^onStateChanged)(CCOperationState state); // 状态回调

@end


#pragma mark - Operation（异步）

/// 异步任务类
///（需要在异步返回后，手动标记任务结束）
@interface CCAsyncOperation : CCOperation

+(instancetype)operationWithBlock:(CCAsyncOperationInitBlcok)block;

@end

@interface CCAsyncOperationLifeCycle : CCOperationLifeCycle

@property(nonatomic, copy, readonly) void(^finish)(void); // 标记任务结束（调一下这个block）

@end


#pragma mark - OperationQueue

/// 任务调度队列类
@interface CCOperationQueue : NSObject

/// 最大并发数。>1并发，=1就是串行
@property(nonatomic, assign) NSUInteger maxConcurrentCount;

/// 挂起队列
@property(nonatomic, assign) BOOL suspended;

/// 把任务添加到队列
-(void)addOperation:(CCOperation *)op;

/// 取消所有任务
-(void)cancelAll;

/// 单个任务结束回调
-(void)setAnOperationCompleteCallback:(void(^)(CCOperation *op))callback;

/// 所有任务结束回调
-(void)setAllOperationsCompleteCallback:(void(^)(void))callback;

@end

NS_ASSUME_NONNULL_END
