//
//  RACKVOProxy.m
//  ReactiveCocoa
//
//  Created by Richard Speyer on 4/10/14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import "RACKVOProxy.h"
#import <libkern/OSAtomic.h>

@interface RACKVOProxy() {
    OSSpinLock _spinLock;
}

@property(strong, nonatomic, readonly) NSMapTable *trampolines;
@end

@implementation RACKVOProxy

+ (RACKVOProxy *)instance {
    static RACKVOProxy *proxy;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        proxy = [[RACKVOProxy alloc] init];
    });

    return proxy;
}

- (instancetype)init {
    self = [super init];
    if (self == nil) return nil;
    _trampolines = [NSMapTable strongToWeakObjectsMapTable];
    return self;
}

- (void)addObserver:(NSObject *)observer forContext:(void *)context {
    NSValue *valueContext = [NSValue valueWithPointer:context];
    OSSpinLockLock(&_spinLock);
    [self.trampolines setObject:observer forKey:valueContext];
    OSSpinLockUnlock(&_spinLock);
}

- (void)removeObserver:(NSObject *)observer forContext:(void *)context {
    NSValue *valueContext = [NSValue valueWithPointer:context];
    OSSpinLockLock(&_spinLock);
    [self.trampolines removeObjectForKey:valueContext];
    OSSpinLockUnlock(&_spinLock);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSValue *valueContext = [NSValue valueWithPointer:context];
    NSObject *trueObserver;
    OSSpinLockLock(&_spinLock);
    trueObserver = [self.trampolines objectForKey:valueContext];
    OSSpinLockUnlock(&_spinLock);
    if (trueObserver) {
        [trueObserver observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
    else {
        NSLog(@"observer of \"%@\" on %@ is gone", keyPath, object);
    }
}

@end
