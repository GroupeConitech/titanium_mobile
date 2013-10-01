//
//  RWLock.h
//  ThreadLockTest
//
//  Created by Patrick Daigle on 2013-09-30.
//  Copyright (c) 2013 Patrick Daigle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <pthread.h>

@interface RWLock : NSObject
{
@private
	pthread_rwlock_t lock;
}

- (void)lockRead;
- (void)lockWrite;
- (void)unlock;

@end
