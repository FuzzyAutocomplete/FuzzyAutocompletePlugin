//
//  SCTiming.h
//  Shortcat
//
//  Created by Jack Chen on 25/09/13.
//  Copyright (c) 2013 Sproutcube. All rights reserved.
//

double machTimeToMilliseconds(uint64_t machTime);
id timeBlock(id (^block)(void), double *time_ms);
double timeVoidBlock(void(^block)(void));
id timeBlockAndLog(NSString *label, id (^block)(void));
