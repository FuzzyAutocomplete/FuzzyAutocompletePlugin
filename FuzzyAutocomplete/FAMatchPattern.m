//
//  FAMatchPattern.m
//  FuzzyAutocomplete
//
//  Created by Leszek Slazynski on 26/04/2014.
//
//

#import "FAMatchPattern.h"
#import "FASettings.h"

@implementation FAMatchPattern {
    BOOL _useTwoPasses;
    NSInteger _minLengthForTwoPasses;
}

- (instancetype) initWithPattern: (NSString *) patternString {
    if ((self = [super initWithPattern: patternString])) {
        _useTwoPasses = [FASettings currentSettings].correctWordOrder;
        _minLengthForTwoPasses = [FASettings currentSettings].correctWordOrderAfter + 1;
    }
    return self;
}

- (double)scoreCandidate:(NSString *)candidate matchedRanges:(NSArray *__autoreleasing *)ranges {
    return [self scoreCandidate: candidate matchedRanges: ranges secondPassRanges: nil];
}

- (BOOL) matchesRepeatedCandidate: (NSString *) candidate {
    NSString * repeated = [candidate stringByAppendingFormat: @":%@", candidate];
    return [super matchesCandidate: repeated];
}

- (NSString *) twoPassesCandidateForCandidate: (NSString *) candidate {
    NSArray * matchedRanges = nil;
    NSString * repeated = [candidate stringByAppendingFormat: @":%@", candidate];
    [super scoreCandidate: repeated matchedRanges: &matchedRanges];
    NSMutableString * secondComponent = [candidate mutableCopy];
    for (NSValue * val in matchedRanges) {
        NSRange r = [val rangeValue];
        if (r.location < candidate.length) {
            NSString * colons = [@"" stringByPaddingToLength: r.length withString: @":" startingAtIndex: 0];
            [secondComponent replaceCharactersInRange: r withString: colons];
        }
    }
    return [candidate stringByAppendingFormat:@":%@", secondComponent];
}

- (double) scoreTwoPassesCandidate: (NSString *) finalCandidate matchedRanges: (NSArray **) ranges secondPassRanges:(NSArray **)secondPass {
    NSUInteger originalLength = finalCandidate.length / 2;

    NSArray * localRanges = nil;
    double final = [super scoreCandidate: finalCandidate matchedRanges: &localRanges];

    NSMutableArray * secondPassRanges = secondPass ? [NSMutableArray array] : nil;
    NSMutableArray * newRanges = ranges ? [NSMutableArray array] : nil;
    for (NSValue * v in localRanges) {
        NSRange r = [v rangeValue];
        if (r.location > originalLength) {
            r.location -= originalLength + 1;
            [secondPassRanges addObject: [NSValue valueWithRange: r]];
        } else {
            [newRanges addObject: [NSValue valueWithRange: r]];
        }
    }
    if (ranges) {
        *ranges = newRanges;
    }
    if (secondPass) {
        *secondPass = secondPassRanges;
    }

    return final;
}

- (double) scoreCandidate: (NSString *) candidate matchedRanges: (NSArray **) ranges secondPassRanges:(NSArray **)secondPass {
    if (!_useTwoPasses || self.pattern.length < _minLengthForTwoPasses || [super matchesCandidate: candidate]) {
        return [super scoreCandidate: candidate matchedRanges: ranges];
    } else {
        if ([self matchesRepeatedCandidate: candidate]) {
            NSString * finalCandidate = [self twoPassesCandidateForCandidate: candidate];
            if ([super matchesCandidate: finalCandidate]) {
                return [self scoreTwoPassesCandidate: finalCandidate matchedRanges: ranges secondPassRanges: secondPass];
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    }
}

- (BOOL) matchesCandidate: (NSString *) candidate {
    if ([super matchesCandidate: candidate]) {
        return YES;
    } else {
        if (_useTwoPasses && self.pattern.length >= _minLengthForTwoPasses && [self matchesRepeatedCandidate: candidate]) {
            return [super matchesCandidate: [self twoPassesCandidateForCandidate: candidate]];
        } else {
            return NO;
        }
    }
}

@end
