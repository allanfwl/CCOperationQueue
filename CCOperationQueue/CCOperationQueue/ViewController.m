//
//  ViewController.m
//  CCOperationQueue
//
//  Created by 冯文林  on 2021/5/30.
//  Copyright © 2021 com.allan. All rights reserved.
//

#import "ViewController.h"
#import "CCOperationQueue.h"

@interface ViewController ()

@end

@implementation ViewController

-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    CCOperation *op1 = [CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
        return ^{
            NSLog(@"任务1");
        };
    }];
    op1.priority = 100;
    
    CCOperation *op2 = [CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
        return ^{
            NSLog(@"任务2");
        };
    }];
    op2.priority = 600;
    
    CCOperation *op3 = [CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
        return ^{
            NSLog(@"任务3");
        };
    }];
    op3.priority = 300;
    
    CCOperationQueue *queue = [CCOperationQueue new];
    queue.maxConcurrentCount = 1;
    [queue addOperation:op1];
    [queue addOperation:op2];
    [queue addOperation:op3];
    [queue setAllOperationsCompleteCallback:^{
        NSLog(@"所有任务执行完毕啦。");
    }];
    
}

@end
