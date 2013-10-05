//
//  RWLock.m
//  ThreadLockTest
//
//  Created by Patrick Daigle on 2013-09-30.
//  Copyright (c) 2013 Patrick Daigle. All rights reserved.
//

#import "RWLock.h"

#pragma mark ThreadLockData

@interface ThreadLockState : NSObject
{
@public
	BOOL hasReadLock;
	BOOL hasWriteLock;
	unsigned int lockCount;
}

- (id)init;

@end

@implementation ThreadLockState

- (id)init
{
	if (self = [super init])
	{
		hasReadLock = false;
		hasWriteLock = false;
		lockCount = 0;
	}
	return self;
}

@end

#pragma mark RWLock

//#define CHECK_LOCK_RELEASE // Throws an exception if the lock is not released when the thread exit
//#define CHECK_LOCK_STATE   // Assert consistency of the ThreadLockState object

@implementation RWLock

- (id)init
{
	if (self = [super init])
	{
		pthread_rwlock_init(&lock, NULL);
		threadLockStates = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[super dealloc];
	pthread_rwlock_destroy(&lock);
	[threadLockStates removeAllObjects];
	[threadLockStates release];
#ifdef CHECK_LOCK_RELEASE
	[[NSNotificationCenter defaultCenter] removeObserver:self];
#endif
}

- (void)lockRead
{
	ThreadLockState* thread = [self currentThreadState];
	
#ifdef CHECK_LOCK_STATE
	[self checkLockState:thread];
#endif
	
	if (!thread->hasReadLock)
	{
		pthread_rwlock_rdlock(&lock);
		thread->hasReadLock = true;
	}
	
	thread->lockCount++;
}

- (void)lockWrite
{
	ThreadLockState* thread = [self currentThreadState];
	
#ifdef CHECK_LOCK_STATE
	[self checkLockState:thread];
#endif
	
	if (thread->hasReadLock && !thread->hasWriteLock)
	{
		[NSException raise:@"AlreadyLockedException" format:@"current thread already owns a read lock"];
		return;
	}
	
	if (!thread->hasWriteLock)
	{
		pthread_rwlock_wrlock(&lock);
		thread->hasWriteLock = true;
	}
	
	thread->lockCount++;
}

- (void)unlock
{
	ThreadLockState* thread = [self currentThreadState];
	
#ifdef CHECK_LOCK_STATE
	[self checkLockState:thread];
#endif
	
	if (thread->lockCount <= 0)
	{
		[NSException raise:@"NotLockedException" format:@"current thread doesn't owns any lock"];
		return;
	}
	
	if (thread->hasReadLock && thread->hasWriteLock && thread->lockCount == 2) // Has 2 real lock
	{
		thread->hasReadLock = false; // Write lock must be acquired before read
		pthread_rwlock_unlock(&lock);
	}

	thread->lockCount--;
	
	if (thread->lockCount == 0)
	{
		[self freeLockState:[NSThread currentThread]];
		pthread_rwlock_unlock(&lock);
	}
}

- (ThreadLockState*)currentThreadState
{
	NSThread* currentThread = [NSThread currentThread];
	NSValue* key = [NSValue valueWithPointer:currentThread];
	
	ThreadLockState* state;
	@synchronized(threadLockStates) {
		state = [threadLockStates objectForKey:key];
	}
	
	if (state == nil) // Create and store thread state object
	{
		state = [[[ThreadLockState alloc] init] autorelease];
		@synchronized(threadLockStates) {
			[threadLockStates setObject:state forKey:key];
		}
		
#ifdef CHECK_LOCK_RELEASE
		[[NSNotificationCenter defaultCenter]
			 addObserver: self
			 selector: @selector(onThreadExit:)
			 name: NSThreadWillExitNotification
			 object: currentThread];
#endif
	}
	return state;
}

- (void)freeLockState:(NSThread*)thread
{
	@synchronized(threadLockStates)	{
		[threadLockStates removeObjectForKey:[NSValue valueWithPointer:thread]];
	}
}

#pragma mark Debugging

#ifdef CHECK_LOCK_RELEASE
- (void)onThreadExit:(NSNotification*)notification
{
	NSThread* thread = [notification object];
	ThreadLockState* state;
	@synchronized(threadLockStates) {
		 state = [threadLockStates objectForKey: [NSValue valueWithPointer:thread]];
	}
	
	if (state != nil && state->lockCount != 0)
	{
		[NSException raise:@"LockNotReleased" format:@"thread %@ has exited without releasing the lock", thread];
	}
}
#endif

#ifdef CHECK_LOCK_STATE
- (void)checkLockState:(ThreadLockState*)state
{
	NSAssert(state != nil, @"[RWLock self check] state is nil");
	if (state->hasReadLock && state->hasWriteLock)
		NSAssert(state->lockCount >= 2, @"[RWLock self check]: lockCount should be >= 2 because hasReadLock = true and hasWriteLock = true");
	else if (state->hasReadLock)
		NSAssert(state->lockCount >= 1, @"[RWLock self check]: lockCount should be >= 1 because hasReadLock = true");
	else if (state->hasWriteLock)
		NSAssert(state->lockCount >= 1, @"[RWLock self check]: lockCount should be >= 1 because hasWriteLock = true");
}
#endif

@end
