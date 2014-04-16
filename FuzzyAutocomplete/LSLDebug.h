/*
 *  LSLDebug.h
 *
 *  Created by Leszek Slazynski on 10-11-03.
 *  Copyright 2010 LSL. All rights reserved.
 *
 */

#ifndef LSLDebug_h
#define LSLDebug_h

#import <string.h>

#define __ONLY_FILE__ (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__)

//#define LSL_DEBUG 1

#define RLog(args...) DOLog(args)
#define RDLog(args...) DODLog(__ONLY_FILE__, __LINE__, __PRETTY_FUNCTION__, args)
#define RTIMER_START NSTimeInterval _lsl_start = [NSDate timeIntervalSinceReferenceDate]
#define RTIMER_STOP RLog(@"%s Time = %f", __PRETTY_FUNCTION__, [NSDate timeIntervalSinceReferenceDate]-_lsl_start)
#define RNAMED_TIMER_START(name) NSTimeInterval _##name##_lsl_start = [NSDate timeIntervalSinceReferenceDate]
#define RNAMED_TIMER_STOP(name) RLog(@"%s Time = %f", #name, [NSDate timeIntervalSinceReferenceDate]-_##name##_lsl_start)

#define RMARK RDLog(@"MARK");
#define RIMARK RDLog(@"0x%016X", self);

#define RMULTI_TIMER_INIT(name) NSTimeInterval _##name##_lsl_start, _##name##_sum = 0
#define RMULTI_TIMER_START(name) _##name##_lsl_start = [NSDate timeIntervalSinceReferenceDate]
#define RMULTI_TIMER_STOP(name) _##name##_sum += [NSDate timeIntervalSinceReferenceDate] - _##name##_lsl_start
#define RMULTI_TIMER_GET(name) _##name##_sum
#define RMULTI_TIMER_PRINT(name) RLog(@"%s Time = %f", #name, _##name##_sum)

#define IGNOREVAL(x) (void) (x)

#if LSL_DEBUG==1

#define DLog(args...) RLog(args)
#define DDLog(args...) RDLog(args)

#define MARK RMARK
#define IMARK RIMARK

#define TIMER_START RTIMER_START
#define TIMER_STOP RTIMER_STOP
#define NAMED_TIMER_START(name) RNAMED_TIMER_START(name)
#define NAMED_TIMER_STOP(name) RNAMED_TIMER_STOP(name)

#define MULTI_TIMER_INIT(name) RMULTI_TIMER_INIT(name)
#define MULTI_TIMER_START(name) RMULTI_TIMER_START(name)
#define MULTI_TIMER_STOP(name) RMULTI_TIMER_STOP(name)
#define MULTI_TIMER_GET(name) RMULTI_TIMER_GET(name)
#define MULTI_TIMER_PRINT(name) RMULTI_TIMER_PRINT(name)

#else

#define DLog(x...) (void) 1
#define DDLog(x...) (void) 1
#define MARK
#define IMARK
#define TIMER_START
#define TIMER_STOP
#define NAMED_TIMER_START(x) (void) 1
#define NAMED_TIMER_STOP(x) (void) 1
#define MULTI_TIMER_INIT(x) (void) 1
#define MULTI_TIMER_START(x) (void) 1
#define MULTI_TIMER_STOP(x) (void) 1
#define MULTI_TIMER_GET(x) (void) 1
#define MULTI_TIMER_PRINT(x) (void) 1

#endif

#endif
