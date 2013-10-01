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

@implementation RWLock

- (id)init
{
	if (self = [super init])
	{
		pthread_rwlock_init(&lock, NULL);
	}
	return self;
}

- (void)lockRead
{
	ThreadLockState* thread = [self currentThreadState];
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
	if (thread->hasReadLock)
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
		thread->hasReadLock = false;
		thread->hasWriteLock = false;
		pthread_rwlock_unlock(&lock);
	}
}

- (ThreadLockState*)currentThreadState
{
	ThreadLockState* state = [[self threadDict] valueForKey:@"lockState"];
	if (state == nil)
	{
		state = [[[ThreadLockState alloc] init] autorelease];
		[[self threadDict] setValue:state forKey:@"lockState"];
	}
	return state;
}

- (NSMutableDictionary*)threadDict
{
	return [[NSThread currentThread] threadDictionary];
}

@end
