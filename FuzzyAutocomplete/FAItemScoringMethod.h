//
//  FAItemScoringMethod.h
//  FuzzyAutocomplete
//
//  Created by Leszek Slazynski on 13/04/2014.
//  Copyright (c) 2014 United Lines of Code. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol DVTTextCompletionItem;

@interface FAItemScoringMethod : NSObject

/// Exponent applied to the matchScore
@property (nonatomic, readwrite) double matchScorePower;
/// Exponent applied to priority (context dependent term).
@property (nonatomic, readwrite) double priorityPower;
/// Exponent applied to priorityFactor (learning dependent term).
@property (nonatomic, readwrite) double priorityFactorPower;
/// Maximum factor by which prefix match score can be increased.
@property (nonatomic, readwrite) double maxPrefixBonus;

/// Scores a single item based on various parameters.
- (double) scoreItem: (id<DVTTextCompletionItem>) item
        searchString: (NSString *) query
         matchedName: (NSString *) matchedName
          matchScore: (double) matchScore
       matchedRanges: (NSArray *) rangesArray
      priorityFactor: (double) priorityFactor;

/// Calculates a normalization factor for all matches for given query.
- (double) normalizationFactorForSearchString: (NSString *) query;

@end
