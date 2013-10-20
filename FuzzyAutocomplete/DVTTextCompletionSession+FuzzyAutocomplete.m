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
}

static char lastResultSetKey;
static char lastPrefixKey;

#define MAX_FUZZY_SEARCH_LENGTH 15

// Sets the current filtering prefix
- (void)_fa_setFilteringPrefix:(NSString *)prefix forceFilter:(BOOL)forceFilter
{
    // Let the original handler deal with the zero and one letter cases
    if (prefix.length < 2) {
        [self _fa_setFilteringPrefix:prefix forceFilter:forceFilter];
        return;
    }
//    
//    if (prefix.length > MAX_FUZZY_SEARCH_LENGTH) {
//        return;
//    }
//    
    NSString *lastPrefix = objc_getAssociatedObject(self, &lastPrefixKey);
    NSArray *searchSet;

    // Use the last result set to filter down if it exists
    if (lastPrefix && [prefix rangeOfString:lastPrefix].location == 0) {
        searchSet = objc_getAssociatedObject(self, &lastResultSetKey);
    }
    
    if (!searchSet) {
        searchSet = [self filteredCompletionsBeginningWithLetter:[prefix substringToIndex:1]];
    }
    
    IDEIndexCompletionItem *originalMatch;
    __block IDEIndexCompletionItem *bestMatch;
    if (self.selectedCompletionIndex < self.filteredCompletionsAlpha.count) {
        originalMatch = self.filteredCompletionsAlpha[self.selectedCompletionIndex];
    }
    
    double totalTime = timeVoidBlock(^{
        NSMutableString *predicateString = [NSMutableString string];
        [prefix enumerateSubstringsInRange:NSMakeRange(0, prefix.length) options:NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
            [predicateString appendFormat:@"%@*", substring];
        }];

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name like[c] %@", predicateString];

        NSArray *filtered = timeBlockAndLog(@"Filtering", ^id{
            return [searchSet filteredArrayUsingPredicate:predicate];
        });

        self.filteredCompletionsAlpha = filtered;
        DLog(@"Filter: %lu to %lu", searchSet.count, (unsigned long)filtered.count);

        bestMatch = timeBlockAndLog(@"Best match time", ^id{
            return [self bestMatchInArray:filtered forQuery:prefix];
        });

        objc_setAssociatedObject(self, &lastPrefixKey, prefix, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, &lastResultSetKey, filtered, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (filtered.count > 0) {
            self.selectedCompletionIndex = [filtered indexOfObject:bestMatch];
        }
        // This forces the completion list to resize the columns
        DVTTextCompletionListWindowController *listController = [self _listWindowController];
        [listController _updateCurrentDisplayState];
        
        // IDEIndexCompletionItem doesn't implement isEqual
        DVTTextCompletionInlinePreviewController *inlinePreview = [self _inlinePreviewController];
        if (![originalMatch.name isEqual:bestMatch.name]) {
            // Hide the inline preview if the fuzzy query is different to normal matching
            [inlinePreview hideInlinePreviewWithReason:0];
        }
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

#define MAX_PRIORITY 100.0f

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

