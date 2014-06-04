//
//  DVTTextCompletionSession+FuzzyAutocomplete.h
//  FuzzyAutocomplete
//
//  Created by Jack Chen on 19/10/2013.
//  Copyright (c) 2013 Sproutcube. All rights reserved.
//
//  Extended by Leszek Slazynski.
//  Copyright (c) 2014 United Lines of Code. All rights reserved.
//

#import "DVTTextCompletionSession.h"

@protocol DVTTextCompletionItem;

@interface DVTTextCompletionSession (FuzzyAutocomplete)

/// Swizzles methods to enable/disable the plugin
+ (void) fa_swizzleMethods;

/// Current filtering query.
- (NSString *) fa_filteringQuery;

/// Time (in seconds) spent on last filtering operation.
- (NSTimeInterval) fa_lastFilteringTime;

/// Number of items with non-zero scores.
- (NSUInteger) fa_nonZeroScores;

/// Gets array of ranges matched by current search string in given items name.
- (NSArray *) fa_matchedRangesForItem: (id<DVTTextCompletionItem>) item;

/// Gets array of ranges matched in second pass by current search string in given items name.
- (NSArray *) fa_secondPassMatchedRangesForItem: (id<DVTTextCompletionItem>) item;

/// Retrieves a previously calculated autocompletion score for given item.
- (NSNumber *) fa_scoreForItem: (id<DVTTextCompletionItem>) item;

/// Try to convert ranges ocurring in fromString into toString.
/// Optionally offsets the resulting ranges.
///
/// Handled cases:
///
/// a) fromString is a substring of toString - offset ranges
///
/// b) both fromString and toString contain word segments
///    try to find ranges within segments (may divide ranges)
///
- (NSArray *) fa_convertRanges: (NSArray *) originalRanges
                    fromString: (NSString *) fromString
                      toString: (NSString *) toString
                     addOffset: (NSUInteger) additionalOffset;



@end
