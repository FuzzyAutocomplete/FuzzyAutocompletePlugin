//
//  FAMatchPattern.h
//  FuzzyAutocomplete
//
//  Created by Leszek Slazynski on 26/04/2014.
//
//

#import "IDEOpenQuicklyPattern.h"

@interface FAMatchPattern : IDEOpenQuicklyPattern

- (double) scoreCandidate: (NSString *) candidate matchedRanges: (NSArray **) ranges secondPassRanges: (NSArray **) secondPassRanges;
- (double) scoreCandidate: (NSString *) candidate matchedRanges: (NSArray **) ranges;
- (BOOL) matchesCandidate: (NSString *) item;

@end
