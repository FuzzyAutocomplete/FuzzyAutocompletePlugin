//
//  FuzzyAutocomplete.m
//  FuzzyAutocomplete
//
//  Created by Jack Chen on 18/10/2013.
//  Copyright (c) 2013 Sproutcube. All rights reserved.
//

#import "FuzzyAutocomplete.h"

@implementation FuzzyAutocomplete

+ (BOOL)shouldPrioritizeShortestMatch
{
    static BOOL prioritizeShortestMatch;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        prioritizeShortestMatch = [[NSUserDefaults standardUserDefaults] boolForKey:@"FuzzyAutocompletePrioritizeShortestMatch"];
    });
    return prioritizeShortestMatch;
}

+ (BOOL)shouldInsertPartialPrefix
{
    static BOOL insertPartialPrefix;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        insertPartialPrefix = [[NSUserDefaults standardUserDefaults] boolForKey:@"FuzzyAutocompleteInsertPartialPrefix"];
    });
    return insertPartialPrefix;
}
+ (NSUInteger) prefixAnchor
{
    static NSUInteger prefixAnchor;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        prefixAnchor = [[NSUserDefaults standardUserDefaults] integerForKey:@"FuzzyAutocompletePrefixAnchor"];
    });
    return prefixAnchor;
}
@end