//
//  FAMatchPattern.h
//  FuzzyAutocomplete
//
//  Created by Leszek Slazynski on 26/04/2014.
//
//

#import "IDEOpenQuicklyPattern.h"

/// Fuzzy Autocomplete Match Pattern
@interface FAMatchPattern : IDEOpenQuicklyPattern

- (instancetype) initWithPattern: (NSString *) patternString;

- (double) scoreCandidate: (NSString *) candidate matchedRanges: (NSArray **) ranges secondPassRanges: (NSArray **) secondPassRanges;
- (double) scoreCandidate: (NSString *) candidate matchedRanges: (NSArray **) ranges;
- (BOOL) matchesCandidate: (NSString *) item;

@end
