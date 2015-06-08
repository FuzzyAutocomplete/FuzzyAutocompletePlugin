//
//  FAOpenQuicklyPattern.h
//  FuzzyAutocomplete
//
//  Created by Leszek Ślażyński on 08/06/15.
//
//

/// Dummy class to be switched to real open quickly pattern on runtime
@interface FAOpenQuicklyPattern : NSObject {
    NSString *_pattern;
    BOOL _patternHasSeparators;
    char *_charactersInPattern;
    unsigned short *_patternCharacters;
    unsigned short *_lowerCasePatternCharacters;
    NSUInteger _patternLength;
}

@property(readonly) NSString * pattern;

- (instancetype) initWithPattern: (NSString *) patternString;
+ (instancetype) patternWithInput: (NSString *) input;
- (CGFloat) scoreCandidate: (NSString *) candidate matchedRanges: (NSArray **) rangesPtr;
- (NSArray *) matchedRanges: (NSString *) candidate;
- (CGFloat) scoreCandidate: (NSString *) candidate;
- (BOOL) matchesCandidate: (NSString *) candidate;

@end

