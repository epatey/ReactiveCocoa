//
//  RACKVOTrampoline.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 1/15/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACKVOTrampoline.h"
#import "NSObject+RACDeallocating.h"
#import "RACCompoundDisposable.h"
#import "RACKVOProxy.h"

@interface RACKVOTrampoline ()

// The keypath which the trampoline is observing.
@property (nonatomic, readonly, copy) NSString *keyPath;

// These properties should only be manipulated while synchronized on the
// receiver.
@property (nonatomic, readonly, copy) RACKVOBlock block;
@property (nonatomic, readonly, unsafe_unretained) NSObject *target;

@end

@implementation RACKVOTrampoline

#pragma mark Lifecycle

- (instancetype)initWithTarget:(NSObject *)target keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(RACKVOBlock)block {
	NSCParameterAssert(target != nil);
	NSCParameterAssert(keyPath != nil);
	NSCParameterAssert(block != nil);

	self = [super init];
	if (self == nil) return nil;

	_keyPath = [keyPath copy];

	_block = [block copy];
	_target = target;

	RACKVOProxy *proxy = RACKVOProxy.instance;
	[proxy addObserver:self forContext:(__bridge void *)self];
    
    @synchronized(target) {
		[self.target addObserver:proxy forKeyPath:self.keyPath options:options context:(__bridge void *)self];
	}
	[self.target.rac_deallocDisposable addDisposable:self];

	return self;
}

- (void)dealloc {
	[self dispose];
}

#pragma mark Observation

- (void)dispose {
	NSObject *target;

	@synchronized (self) {
		_block = nil;

		target = self.target;
		_target = nil;
	}

	[target.rac_deallocDisposable removeDisposable:self];

	RACKVOProxy *proxy = RACKVOProxy.instance;
	[proxy removeObserver:self forContext:(__bridge void *)self];
    
    @synchronized(target) {
		[target removeObserver:proxy forKeyPath:self.keyPath context:(__bridge void *)self];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if (context != (__bridge void *)self) {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
		return;
	}

	RACKVOBlock block;
	id target;

	@synchronized (self) {
		block = self.block;
		target = self.target;
	}

	if (block == nil) return;

	block(target, change);
}

@end
