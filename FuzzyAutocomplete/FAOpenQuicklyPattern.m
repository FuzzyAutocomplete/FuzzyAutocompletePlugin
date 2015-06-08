//
//  FAOpenQuicklyPattern.m
//  FuzzyAutocomplete
//
//  Created by Leszek Ślażyński on 08/06/15.
//
//

#import "FAOpenQuicklyPattern.h"

@implementation FAOpenQuicklyPattern

- (NSString *) pattern {
    return nil;
}

- (instancetype) initWithPattern: (NSString *) patternString {
    return nil;
}

+ (instancetype) patternWithInput: (NSString *) input {
    return nil;
}

- (CGFloat) scoreCandidate: (NSString *) candidate matchedRanges: (NSArray **) rangesPtr {
    return 0;
}

- (NSArray *) matchedRanges: (NSString *) candidate {
    return nil;
}

- (CGFloat) scoreCandidate: (NSString *) candidate {
    return 0;
}


- (BOOL) matchesCandidate: (NSString *) candidate {
    return NO;
}

@end