# CCOperationQueue
一个并发调度类。支持了任务优先级、重试、独占等。API上类似于NSOperation，并且是线程安全的。

## 适用于
对多个并发任务，有以下有要求：

1.控制最大并发

2.分优先级执行

3.需要重试机制

4.独占任务（并发读，写串行）

5.任务状态回调

6.挂起/取消任务

7.统一结束回调

## 用法例子

优先级：
```objective-c
CCOperation *op = [CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
    return ^{
        NSLog(@"执行任务");
    };
}];
op.priority = 100;
```

重试：
```objective-c
CCOperation *op = [CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
    return ^{
        if (success) {
          NSLog(@"执行成功");
        } else {
          lifeCycle.retry = YES; // 失败则重试
        }
    };
}];
op.retryTimes = 3; // 最多重试3次
```

状态回调：
```objective-c
CCOperation *op = [CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
    lifeCycle.onStateChanged = ^(CCOperationState state) { // 状态回调
      if (state == CCOperationState_Finish) {
        // 释放资源等
      } 
    };
    return ^{
        NSLog(@"执行任务");
    };
}];
```

统一结束回调：
```objective-c
CCOperation *op1 = [CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
    return ^{
        NSLog(@"任务1");
    };
}];

CCOperation *op2 = [CCOperation operationWithBlock:^CCOperationExecBlcok(CCOperationLifeCycle *lifeCycle) {
    return ^{
        NSLog(@"任务2");
    };
}];

CCOperationQueue *queue = [CCOperationQueue new];
[queue addOperation:op1];
[queue addOperation:op2];

[queue setAllOperationsCompleteCallback:^{
    NSLog(@"所有任务执行完毕啦。");
}];
```

## 最后
更多用法例子请见 CCOperationTestCase.m 和 CCOperationQueueTestCase.m 

主要API均以通过单元测试，可放心食用。
