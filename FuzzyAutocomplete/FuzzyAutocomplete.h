//
//  FuzzyAutocomplete.h
//  FuzzyAutocomplete
//
//  Created by Jack Chen on 18/10/2013.
//  Copyright (c) 2013 Sproutcube. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FuzzyAutocomplete : NSObject

+ (BOOL)shouldPrioritizeShortestMatch;
+ (BOOL)shouldInsertPartialPrefix;
+ (NSUInteger) prefixAnchor;

@end
