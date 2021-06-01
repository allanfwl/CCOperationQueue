//
//  CCOperationQueueTestCase.m
//  CCOperationQueueTests
//
//  Created by 冯文林  on 2021/5/30.
//  Copyright © 2021 com.allan. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CCOperationQueue.h"

@interface CCOperationQueueTestCase : XCTestCase

@end

@implementation CCOperationQueueTestCase

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testSuspended {
    
    XCTestExpectation *ex = [[XCTestExpectation alloc] initWithDescription:@""];
    
    __block NSInteger count = 0;
    
    /* test suspended = YES */
    
    CCOperationQueue *queue = [CCOperationQueue new];
    queue.maxConcurrentCount = 2;
    [queue addOperation:[CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
        return ^{
            @synchronized (self) {
                count++;
            }
        };
    }]];
    [queue addOperation:[CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
        return ^{
            @synchronized (self) {
                count++;
            }
        };
    }]];
    
    queue.suspended = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
        [ex fulfill];
    });
    [self waitForExpectations:@[ex] timeout:1.2];
    XCTAssert(count == 0);
    
    /* test suspended = NO */
    
    XCTestExpectation *ex2 = [[XCTestExpectation alloc] initWithDescription:@""];
    
    [queue addOperation:[CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
        return ^{
            [ex2 fulfill];
        };
    }]];
    
    queue.suspended = NO;
    [self waitForExpectations:@[ex2] timeout:1];
    XCTAssert(count == 2);
    
}

- (void)testCancelAll {
    
    XCTestExpectation *ex = [[XCTestExpectation alloc] initWithDescription:@""];
    
    __block NSInteger count = 0;
    
    CCOperationQueue *queue = [CCOperationQueue new];
    queue.maxConcurrentCount = 1;
    [queue addOperation:[CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
        return ^{
            sleep(2);
        };
    }]];
    [queue addOperation:[CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
        return ^{
            @synchronized (self) {
                count++;
            }
        };
    }]];
    [queue addOperation:[CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
        return ^{
            @synchronized (self) {
                count++;
            }
        };
    }]];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
        [queue cancelAll];
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
        [ex fulfill];
    });
    
    [self waitForExpectations:@[ex] timeout:5];
    XCTAssert(count == 0);
    
}

-(void)testAnOperationCompleteCallback {
    
    XCTestExpectation *ex = [[XCTestExpectation alloc] initWithDescription:@""];
    ex.expectedFulfillmentCount = 2;
    
    NSMutableSet *ret = [NSMutableSet new];
    
    CCOperation *op1 = [CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
        return ^{};
    }];
    op1.name = @"op1";
    
    CCOperation *op2 = [CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
        return ^{};
    }];
    op2.name = @"op2";
    
    CCOperationQueue *queue = [CCOperationQueue new];
    [queue addOperation:op1];
    [queue addOperation:op2];
    [queue setAnOperationCompleteCallback:^(CCOperation * _Nonnull op) {
        [ret addObject:op.name];
        [ex fulfill];
    }];
    
    [self waitForExpectations:@[ex] timeout:1];
    XCTAssert([ret isEqualToSet:({
        NSMutableSet *set = [NSMutableSet new];
        [set addObject:@"op1"];
        [set addObject:@"op2"];
        set;
    })]);
    
}


-(void)testAllOperationsCompleteCallback {
    
    XCTestExpectation *ex = [[XCTestExpectation alloc] initWithDescription:@""];
    
    __block NSInteger count = 0;
    
    CCAsyncOperation *op1 = [CCAsyncOperation operationWithBlock:^CCOperationExecBlcok(CCAsyncOperationLifeCycle *lifeCycle) {
        return ^{
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                sleep(0.5);
                @synchronized (self) {
                    count++;
                }
                lifeCycle.retry = YES;
                lifeCycle.finish();
            });
        };
    }];
    op1.retryTimes = 3;
    
    CCOperation *op2 = [CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
        return ^{
            @synchronized (self) {
                count++;
            }
        };
    }];

    CCOperationQueue *queue = [CCOperationQueue new];
    [queue addOperation:op1];
    [queue addOperation:op2];
    [queue setAllOperationsCompleteCallback:^{
        [ex fulfill];
        XCTAssert(count == (3+1+1));
    }];
    
    [self waitForExpectations:@[ex] timeout:3];
    
}

@end
