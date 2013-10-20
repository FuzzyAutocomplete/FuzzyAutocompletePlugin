//
//  DVTTextCompletionSession+FuzzyAutocomplete.m
//  FuzzyAutocomplete
//
//  Created by Jack Chen on 19/10/2013.
//  Copyright (c) 2013 Sproutcube. All rights reserved.
//

#import "DVTTextCompletionSession+FuzzyAutocomplete.h"
#import "DVTTextCompletionInlinePreviewController.h"
#import "DVTTextCompletionListWindowController.h"
#import "IDEIndexCompletionItem.h"
#import "IDEOpenQuicklyPattern.h"
#import "SCTiming.h"
#import <objc/runtime.h>
#import <JRSwizzle.h>

@implementation DVTTextCompletionSession (FuzzyAutocomplete)

+ (void)load
{
    [self jr_swizzleMethod:@selector(_setFilteringPrefix:forceFilter:) withMethod:@selector(_fa_setFilteringPrefix:forceFilter:) error:nil];
    [self jr_swizzleMethod:@selector(setAllCompletions:) withMethod:@selector(_fa_setAllCompletions:) error:nil];
    [self jr_swizzleMethod:@selector(insertCurrentCompletion) withMethod:@selector(_fa_insertCurrentCompletion) error:nil];
}

static char lastResultSetKey;
static char lastPrefixKey;
static char insertingCompletionKey;

- (BOOL)_fa_insertCurrentCompletion
{
    [self setInsertingCurrentCompletion:YES];
    return [self _fa_insertCurrentCompletion];
}

- (void)setInsertingCurrentCompletion:(BOOL)value
{
    objc_setAssociatedObject(self, &insertingCompletionKey, @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#define MAX_PREDICATE_LENGTH 10
#define MAX_PRIORITY 100.0f

// Sets the current filtering prefix
- (void)_fa_setFilteringPrefix:(NSString *)prefix forceFilter:(BOOL)forceFilter
{
    // Let the original handler deal with the zero and one letter cases
    if (prefix.length < 2) {
        [self _fa_setFilteringPrefix:prefix forceFilter:forceFilter];
        return;
    }
    
    NSNumber *insertingCompletion = objc_getAssociatedObject(self, &insertingCompletionKey);
    // Due to how the KVO is set up, inserting a completion actually triggers another filter event
    // so we nullify it here
    if (insertingCompletion && insertingCompletion.boolValue) {
        [self setInsertingCurrentCompletion:NO];
        return;
    }
        
    NSString *lastPrefix = objc_getAssociatedObject(self, &lastPrefixKey);
    NSArray *searchSet;

    // Use the last result set to filter down if it exists
    if (lastPrefix && [prefix rangeOfString:lastPrefix].location == 0) {
        searchSet = objc_getAssociatedObject(self, &lastResultSetKey);
    }
    
    if (!searchSet) {
        searchSet = [self filteredCompletionsBeginningWithLetter:[prefix substringToIndex:1]];
    }
    
    double totalTime = timeVoidBlock(^{
        IDEIndexCompletionItem *originalMatch;
        IDEIndexCompletionItem *bestMatch;
        if (self.selectedCompletionIndex < self.filteredCompletionsAlpha.count) {
            originalMatch = self.filteredCompletionsAlpha[self.selectedCompletionIndex];
        }
        
        NSMutableString *predicateString = [NSMutableString string];
        [prefix enumerateSubstringsInRange:NSMakeRange(0, MIN(prefix.length, MAX_PREDICATE_LENGTH)) options:NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
            [predicateString appendFormat:@"%@*", substring];
        }];

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name like[c] %@", predicateString];

        NSArray *firstPass = timeBlockAndLog(@"Filtering", ^id{
            return [searchSet filteredArrayUsingPredicate:predicate];
        });
        
        DLog(@"First pass: %lu to %lu", searchSet.count, (unsigned long)firstPass.count);

        NSMutableArray *secondPass = [NSMutableArray array];

        bestMatch = timeBlockAndLog(@"Best match time", ^id{
            IDEOpenQuicklyPattern *pattern = [IDEOpenQuicklyPattern patternWithInput:prefix];
            __block IDEIndexCompletionItem *bestMatch;
            __block double highScore = 0.0f;
            
            [firstPass enumerateObjectsUsingBlock:^(IDEIndexCompletionItem *item, NSUInteger idx, BOOL *stop) {
                double score = [pattern scoreCandidate:item.name] * (MAX_PRIORITY - item.priority);
                if (score > 0) {
                    [secondPass addObject:item];
                }
                if (score > highScore) {
                    bestMatch = item;
                    highScore = score;
                }
            }];
            
            return bestMatch;
        });
        
        self.filteredCompletionsAlpha = secondPass;

        objc_setAssociatedObject(self, &lastPrefixKey, prefix, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, &lastResultSetKey, secondPass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (secondPass.count > 0 && bestMatch) {
            self.selectedCompletionIndex = [secondPass indexOfObject:bestMatch];
        }
        else {
            self.selectedCompletionIndex = NSNotFound;
        }
        
        // IDEIndexCompletionItem doesn't implement isEqual
        DVTTextCompletionInlinePreviewController *inlinePreview = [self _inlinePreviewController];
        if (![originalMatch.name isEqual:bestMatch.name]) {
            // Hide the inline preview if the fuzzy query is different to normal matching
            [inlinePreview hideInlinePreviewWithReason:0];
        }
        
        // This forces the completion list to resize the columns
        DVTTextCompletionListWindowController *listController = [self _listWindowController];
        [listController _updateCurrentDisplayState];
    });
    
    DLog(@"Fuzzy match total time: %f", totalTime);
}


static char filteredCompletionCacheKey;

- (void)_fa_setAllCompletions:(NSArray *)allCompletions
{
    [self _fa_setAllCompletions:allCompletions];
    NSCache *filterCache = objc_getAssociatedObject(self, &filteredCompletionCacheKey);
    if (filterCache) {
        [filterCache removeAllObjects];
    }
}

// We need to cache the first letter sets because if a user types fast enough,
// they don't trigger the standard autocomplete first letter set that we need
// for good performance.
- (NSArray *)filteredCompletionsBeginningWithLetter:(NSString *)letter
{
    NSCache *filteredCompletionCache = objc_getAssociatedObject(self, &filteredCompletionCacheKey);
    if (!filteredCompletionCache) {
        filteredCompletionCache = [[NSCache alloc] init];
        objc_setAssociatedObject(self, &filteredCompletionCacheKey, filteredCompletionCache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSArray *completionsForLetter = [filteredCompletionCache objectForKey:letter];
    if (!completionsForLetter) {
        completionsForLetter = [self.allCompletions filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name beginswith[c] %@", letter]];
        [filteredCompletionCache setObject:completionsForLetter forKey:letter];
    }
    return completionsForLetter;
}

- (IDEIndexCompletionItem *)bestMatchInArray:(NSArray *)array forQuery:(NSString *)query
{
    IDEOpenQuicklyPattern *pattern = [IDEOpenQuicklyPattern patternWithInput:query];
    __block IDEIndexCompletionItem *bestMatch;
    __block double highScore = 0.0f;
    
    [array enumerateObjectsUsingBlock:^(IDEIndexCompletionItem *item, NSUInteger idx, BOOL *stop) {
        double score = [pattern scoreCandidate:item.name] * (MAX_PRIORITY - item.priority);
        if (score > highScore) {
            bestMatch = item;
            highScore = score;
        }
    }];
    
    return bestMatch;
}



// Used for debugging
- (NSArray *)orderCompletionsByScore:(NSArray *)completions withQuery:(NSString *)query
{
    IDEOpenQuicklyPattern *pattern = [IDEOpenQuicklyPattern patternWithInput:query];
    NSMutableArray *completionsWithScore = [NSMutableArray arrayWithCapacity:completions.count];
    
    timeVoidBlockAndLog(@"Scoring", ^{
        [completions enumerateObjectsUsingBlock:^(IDEIndexCompletionItem *item, NSUInteger idx, BOOL *stop) {
            [completionsWithScore addObject:@{
                                              @"item": item,
                                              @"score": @([pattern scoreCandidate:item.name])}];
        }];
    });
    
    NSSortDescriptor *sortByScore = [NSSortDescriptor sortDescriptorWithKey:@"score" ascending:NO];
    
    timeVoidBlockAndLog(@"Sorting", ^{
        [completionsWithScore sortUsingDescriptors:@[sortByScore]];
    });
    
    return [completionsWithScore valueForKeyPath:@"@unionOfObjects.item"];
}

@end

