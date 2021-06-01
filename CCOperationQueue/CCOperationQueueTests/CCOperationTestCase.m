//
//  CCOperationTestCase.m
//  CCOperationQueueTests
//
//  Created by 冯文林  on 2021/5/30.
//  Copyright © 2021 com.allan. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CCOperationQueue.h"

@interface CCOperationTestCase : XCTestCase

@end

@implementation CCOperationTestCase

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

-(void)testPriority {
    
    XCTestExpectation *ex = [[XCTestExpectation alloc] initWithDescription:@""];
    ex.expectedFulfillmentCount = 3;
    
    __block NSInteger order = -1;
    
    CCOperation *op1 = [CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
        return ^{
            @synchronized (self) {
                order++;
                XCTAssert(order == 2);
            }
            NSLog(@"任务1 - 完成");
            [ex fulfill];
        };
    }];
    op1.priority = 100;
    
    CCOperation *op2 = [CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
        return ^{
            @synchronized (self) {
                order++;
                XCTAssert(order == 0);
            }
            NSLog(@"任务2 - 完成");
            [ex fulfill];
        };
    }];
    op2.priority = 600;
    
    CCOperation *op3 = [CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
        return ^{
            @synchronized (self) {
                order++;
                XCTAssert(order == 1);
            }
            NSLog(@"任务3 - 完成");
            [ex fulfill];
        };
    }];
    op3.priority = 300;
    
    CCOperationQueue *queue = [CCOperationQueue new];
    queue.maxConcurrentCount = 1;
    [queue addOperation:op1];
    [queue addOperation:op2];
    [queue addOperation:op3];
    
    [self waitForExpectations:@[ex] timeout:1];
    
}

-(void)testRetryTimes {
    
    XCTestExpectation *ex = [[XCTestExpectation alloc] initWithDescription:@""];
    ex.expectedFulfillmentCount = 3;
    
    __block NSInteger count = 0;
    
    {
        
        CCOperation *op = [CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
            return ^{
                sleep(1);
                count++;
                lifeCycle.retry = YES;
                [ex fulfill];
            };
        }];
        op.retryTimes = 3;
        
        CCOperationQueue *queue = [CCOperationQueue new];
        [queue addOperation:op];
        
    }
    
    [self waitForExpectations:@[ex] timeout:5];
    XCTAssert(count == 3);
    
}

-(void)testIsBarrier {
    
    XCTestExpectation *ex = [[XCTestExpectation alloc] initWithDescription:@""];
    ex.expectedFulfillmentCount = 3;
    
    NSMutableArray *orders = @[].mutableCopy;
    
    {
        
        CCOperation *op1 = [CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
            return ^{
                NSLog(@"任务1 - 开始");
                sleep(2);
                @synchronized (self) {
                    [orders addObject:@(1)];
                }
                NSLog(@"任务1 - 完成");
                [ex fulfill];
            };
        }];
        
        CCOperation *op2 = [CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
            return ^{
                NSLog(@"任务2 - 开始");
                sleep(1);
                @synchronized (self) {
                    [orders addObject:@(2)];
                }
                NSLog(@"任务2 - 完成");
                [ex fulfill];
            };
        }];
        op2.isBarrier = YES;
        
        CCOperation *op3 = [CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
            return ^{
                NSLog(@"任务3 - 完成");
                @synchronized (self) {
                    [orders addObject:@(3)];
                }
                [ex fulfill];
            };
        }];
        
        CCOperationQueue *queue = [CCOperationQueue new];
        [queue addOperation:op1];
        [queue addOperation:op2];
        [queue addOperation:op3];
        
    }
        
    [self waitForExpectations:@[ex] timeout:5];
    XCTAssert(([orders isEqualToArray:@[ @(1), @(2), @(3) ]]));

}

-(void)testState {
    
    XCTestExpectation *ex = [[XCTestExpectation alloc] initWithDescription:@""];
    
    NSMutableArray *states = @[].mutableCopy;
    
    CCOperation *op = [CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
        lifeCycle.onStateChanged = ^(CCOperationState state) {
            [states addObject:@(state)];
        };
        return ^{
            NSLog(@"任务 - 完成");
            [ex fulfill];
        };
    }];
    
    CCOperationQueue *queue = [CCOperationQueue new];
    [queue addOperation:op];
        
    [self waitForExpectations:@[ex] timeout:1];
    XCTAssert(([states isEqualToArray:@[
        @(CCOperationState_Pending),
        @(CCOperationState_Ready),
        @(CCOperationState_Executing),
        @(CCOperationState_Finish),
    ]]));
    
}

-(void)testExecSchedule {
    
    XCTestExpectation *ex = [[XCTestExpectation alloc] initWithDescription:@""];
    ex.expectedFulfillmentCount = 3;
    
    CCOperation *op1 = [CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
        return ^{
            XCTAssert(([NSThread isMainThread]));
            NSLog(@"任务1 - 完成");
            [ex fulfill];
        };
    }];
    op1.execSchedule = dispatch_get_main_queue();
    
    CCOperation *op2 = [CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
        return ^{
            XCTAssert(([NSThread isMultiThreaded]));
            NSLog(@"任务2 - 完成");
            [ex fulfill];
        };
    }];
    // op2.execSchedule = dispatch_get_global_queue(0, 0); /* defalut */
    
    CCOperation *op3 = [CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
        return ^{
            XCTAssert(([NSThread isMultiThreaded]));
            NSLog(@"任务3 - 完成");
            [ex fulfill];
        };
    }];
    op3.execSchedule = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    
    CCOperationQueue *queue = [CCOperationQueue new];
    [queue addOperation:op1];
    [queue addOperation:op2];
    [queue addOperation:op3];
    
    [self waitForExpectations:@[ex] timeout:1];
    
}

-(void)testAsyncOperation {
    
    XCTestExpectation *ex = [[XCTestExpectation alloc] initWithDescription:@""];
    ex.expectedFulfillmentCount = 2;
    
    NSMutableArray *ret = @[].mutableCopy;
    
    {
        
        CCAsyncOperation *asyncOp = [CCAsyncOperation operationWithBlock:^CCOperationExecBlcok(CCAsyncOperationLifeCycle *lifeCycle) {
            return ^{
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    sleep(3);
                    [ret addObject:@"asyncOp"];
                    NSLog(@"异步任务 - 完成");
                    lifeCycle.finish();
                    [ex fulfill];
                });
            };
        }];
        
        CCOperation *op = [CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
            return ^{
                [ret addObject:@"op"];
                NSLog(@"任务 - 完成");
                [ex fulfill];
            };
        }];
        
        CCOperationQueue *queue = [CCOperationQueue new];
        queue.maxConcurrentCount = 1;
        [queue addOperation:asyncOp];
        [queue addOperation:op];
        
    }
    
    [self waitForExpectations:@[ex] timeout:5];
    XCTAssert(([ret isEqualToArray:@[ @"asyncOp", @"op" ]]));
    
}

@end
