//
//  SCTiming.m
//  Shortcat
//
//  Created by Jack Chen on 25/09/13.
//  Copyright (c) 2013 Sproutcube. All rights reserved.
//

#import "SCTiming.h"

#import <mach/mach.h>
#import <mach/mach_time.h>

double machTimeToMilliseconds(uint64_t machTime)
{
    static mach_timebase_info_data_t machData;
    if (machData.denom == 0) {
        (void)mach_timebase_info(&machData);
    }
    return machTime * machData.numer / machData.denom / (double)1000 / (double)1000;
}

id timeBlock(id (^block)(void), double *time_ms)
{
    uint64_t start = mach_absolute_time();
    id retValue = block();
    
    double t = machTimeToMilliseconds(mach_absolute_time() - start);
    *time_ms = t;
    
    return retValue;
}

double timeVoidBlock(void (^block)(void))
{
    uint64_t start = mach_absolute_time();
    block();
    
    return machTimeToMilliseconds(mach_absolute_time() - start);
}

void timeVoidBlockAndLog(NSString *label, void (^block)(void))
{
    DLog(@"Time taken for %@: %f ms", label, timeVoidBlock(block));
}

id timeBlockAndLog(NSString *label, id (^block)(void))
{
    double time_ms = 0;
    id retValue = timeBlock(block, &time_ms);
    DLog(@"Time taken for %@: %f ms", label, time_ms);
    return retValue;
}