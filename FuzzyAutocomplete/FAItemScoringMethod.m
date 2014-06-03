//
//  FAItemScoringMethod.m
//  FuzzyAutocomplete
//
//  Created by Leszek Slazynski on 13/04/2014.
//  Copyright (c) 2014 United Lines of Code. All rights reserved.
//

#import "FAItemScoringMethod.h"
#import "DVTTextCompletionItem-Protocol.h"

@implementation FAItemScoringMethod

- (double) scoreItem: (id<DVTTextCompletionItem>) item
        searchString: (NSString *) query
         matchedName: (NSString *) matchedName
          matchScore: (double) matchScore
       matchedRanges: (NSArray *) rangesArray
      priorityFactor: (double) priorityFactor
{
    double invertedPriority = (10.0 / MAX(item.priority, 1.0));
    priorityFactor = MAX(priorityFactor, 1.0);
    NSRange range = [[rangesArray firstObject] rangeValue];
    double prefixBonus = range.location ? 1.0 : 1.0 + (_maxPrefixBonus * range.length) / query.length;
    return pow(matchScore, _matchScorePower) * pow(priorityFactor, _priorityFactorPower) * pow(invertedPriority, _priorityPower) * prefixBonus;
}

- (double) normalizationFactorForSearchString: (NSString *) query {
    return 1.0 / pow(query.length * query.length + query.length + 1, _matchScorePower);
}

@end
