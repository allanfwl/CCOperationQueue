//
//  CCOperationQueue.m
//  CCKit
//
//  Created by 冯文林  on 2021/5/30.
//  Copyright © 2021 com.allan. All rights reserved.
//

#import "CCOperationQueue.h"

#include <queue>
using namespace std;

@implementation CCOperationLifeCycle

@end

#pragma mark - Operation

@interface CCOperation ()

@property(nonatomic, strong) CCOperationLifeCycle *lifeCycle;
@property(nonatomic, assign) CCOperationState state;
@property(nonatomic, copy) CCOperationExecBlcok execBlock;

@end

@implementation CCOperation

-(void)dealloc {
    
}

+(instancetype)operationWithBlock:(CCOperationInitBlcok)block {
    return [[self alloc] initWithBlock:block];
}

-(instancetype)initWithBlock:(CCOperationInitBlcok)block {
    self = [super init];
    if (self) {
        self.execBlock = block(self.lifeCycle);
        self.execSchedule = dispatch_get_global_queue(0, 0);
    }
    return self;
}

-(void)execute {
    if (self.execBlock) {
        self.execBlock();
    }
}

-(CCOperationLifeCycle *)lifeCycle {
    if (!_lifeCycle) {
        _lifeCycle = [CCOperationLifeCycle new];
    }
    return _lifeCycle;
}

-(void)setState:(CCOperationState)state {
    _state = state;

    if (self.lifeCycle.onStateChanged) {
        self.lifeCycle.onStateChanged(state);
    }
}

-(void)cancel {
    self.state = CCOperationState_Cancel;
}

@end


#pragma mark - Operation（异步）

@interface CCAsyncOperation () {
    CCAsyncOperationLifeCycle *_lifeCycle;
}

@end

@implementation CCAsyncOperation

+(instancetype)operationWithBlock:(CCAsyncOperationInitBlcok)block {
    return [[super alloc] initWithBlock:(CCOperationInitBlcok)block];
}

-(CCOperationLifeCycle *)lifeCycle {
    if (!_lifeCycle) {
        _lifeCycle = [CCAsyncOperationLifeCycle new];
    }
    return _lifeCycle;
}



@end


@implementation CCAsyncOperationLifeCycle

@end


#pragma mark - OperationQueue

namespace {
    struct cmp_less {
       bool operator()(CCOperation *a, CCOperation *b){
           return a.priority < b.priority;
       }
    };
};

@interface CCOperationQueue () {
    
}

@property(nonatomic, assign) priority_queue<CCOperation *,vector<CCOperation *>,cmp_less> *queueImpl; // 优先级队列（大顶堆）

@property(nonatomic, assign) NSUInteger curConcurrent;

@property(nonatomic, assign) BOOL hasBarrier;

// hooks
@property(nonatomic, copy) void(^anOperationComplete)(CCOperation *op);
@property(nonatomic, copy) void(^allOperationsComplete)(void);

@end

@implementation CCOperationQueue

-(void)dealloc {
    delete self.queueImpl;
}

-(instancetype)init {
    if (self = [super init]) {
        self.maxConcurrentCount = UINT_MAX;
    }
    return self;
}

- (void)addOperation:(CCOperation *)op {
    op.state = CCOperationState_Pending;
    @synchronized (self) {
        self.queueImpl->push(op);
    }
    [self loop];
}

-(void)setSuspended:(BOOL)suspended {
    @synchronized (self) {
        _suspended = suspended;
    }
    if (suspended == NO) {
        [self loop];
    }
}

-(void)cancelAll {
    @synchronized (self) {
        while (!self.queueImpl->empty()) {
            auto op = self.queueImpl->top();
            [op cancel];
            self.queueImpl->pop();
            [self callHook_anOperationComplete:op];
        }
    }
}

-(void)callHook_anOperationComplete:(CCOperation *)op {
    if (self.anOperationComplete) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.anOperationComplete(op);
        });
    }
    @synchronized (self) {
        if (self.curConcurrent == 0 && self.queueImpl->empty()) {
            [self callHook_allOperationsComplete];
        }
    }
}

-(void)callHook_allOperationsComplete {
    if (self.allOperationsComplete) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.allOperationsComplete();
        });
    }
}

-(void)loop {
    dispatch_async(dispatch_get_main_queue(), ^{
        @synchronized (self)
        {

            while (!self.suspended && !self.queueImpl->empty() && self.curConcurrent<self.maxConcurrentCount && !(self.hasBarrier && self.curConcurrent>0)) {
                
                auto op = self.queueImpl->top();
                self.queueImpl->pop();
                
                if (op.isBarrier) { // 独占任务
                    
                    self.hasBarrier = YES; // 标记独占标志位
                    
                    if (self.curConcurrent > 0) { // 等待其它任务执行结束
                        op.priority = INT_MAX; // 防止独占任务被插队
                        self.queueImpl->push(op);
                        break;
                    }
                }
                
                if (op.state != CCOperationState_Pending) { // 已取消的任务
                    NSAssert(op.state == CCOperationState_Cancel, @"按理来说只有取消状态");
                    if (op.state == CCOperationState_Cancel) [self callHook_anOperationComplete:op]; // call hook
                    break;
                }
                
                self.curConcurrent++;
                
                op.state = CCOperationState_Ready; // 就绪。
                
                dispatch_async(op.execSchedule, ^{
                    
                    void(^OP_ON_FINISH)(void) = ^{ // 创建结束回调
                        
                        op.state = CCOperationState_Finish;
                        
                        if (op.isBarrier) {
                            @synchronized (self) {
                                self.hasBarrier = NO;
                            }
                        }
                        
                        if (op.retryTimes > 0 && op.lifeCycle.retry == YES) { // 重试
                            
                            op.retryTimes--;
                            op.state = CCOperationState_Pending;
                            
                            @synchronized (self) {
                                self.queueImpl->push(op);
                            }
                            
                        }
                        
                        @synchronized (self){
                            self.curConcurrent--;
                        }
                        
                        if (op.state == CCOperationState_Finish) [self callHook_anOperationComplete:op]; // call hook
                        
                        [self loop]; // loop
                        
                    };
                    
                    // 即将执行
                    
                    op.lifeCycle.retry = NO;
                    
                    if ([op isKindOfClass:[CCAsyncOperation class]]) { // 若是异步任务
                        @try {
                            [op.lifeCycle setValue:OP_ON_FINISH forKey:@"finish"];
                        } @catch (NSException *exception) {
                            NSAssert(nil == exception, @"未知错误");
                        }
                    }
                    
                    // 执行任务
                    
                    op.state = CCOperationState_Executing;
                    [op execute];
                    
                    if (![op isKindOfClass:[CCAsyncOperation class]]) { // 若是同步任务
                        OP_ON_FINISH();
                    }
                    
                });
            }
            
        }
    });
}

-(priority_queue<CCOperation *,vector<CCOperation *>,cmp_less> *)queueImpl {
    if (!_queueImpl) {
        _queueImpl = ({
            auto q = new priority_queue<CCOperation *,vector<CCOperation *>,cmp_less>();

            q;
        });
    }
    return _queueImpl;
}

-(void)setMaxConcurrentCount:(NSUInteger)maxConcurrentCount {
    @synchronized (self) {
        _maxConcurrentCount = maxConcurrentCount;
    }
}

-(void)setAnOperationCompleteCallback:(void (^)(CCOperation * _Nonnull))callback {
    self.anOperationComplete = callback;
}

-(void)setAllOperationsCompleteCallback:(void (^)())callback {
    self.allOperationsComplete = callback;
}

@end
