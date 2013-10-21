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
    
    @try {
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
            __block IDEIndexCompletionItem *bestMatch;
            
            if (self.selectedCompletionIndex < self.filteredCompletionsAlpha.count) {
                originalMatch = self.filteredCompletionsAlpha[self.selectedCompletionIndex];
            }
            
            NSMutableArray *filteredSet = [NSMutableArray array];
            
            IDEOpenQuicklyPattern *pattern = [IDEOpenQuicklyPattern patternWithInput:prefix];
            
            __block double highScore = 0.0f;
            
            [searchSet enumerateObjectsUsingBlock:^(IDEIndexCompletionItem *item, NSUInteger idx, BOOL *stop) {
                double score = [pattern scoreCandidate:item.name] * (MAX_PRIORITY - item.priority);
                if (score > 0) {
                    [filteredSet addObject:item];
                }
                if (score > highScore) {
                    bestMatch = item;
                    highScore = score;
                }
            }];
            
            self.filteredCompletionsAlpha = filteredSet;
            
            objc_setAssociatedObject(self, &lastPrefixKey, prefix, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(self, &lastResultSetKey, filteredSet, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            
            if (filteredSet.count > 0 && bestMatch) {
                self.selectedCompletionIndex = [filteredSet indexOfObject:bestMatch];
                [self setPartialCompletionPrefixForCompletionItem:bestMatch query:prefix];
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
    @catch (NSException *exception) {
        NSLog(@"An exception occurred within FuzzyAutocomplete: %@", exception);
    }
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

- (void)setPartialCompletionPrefixForCompletionItem:(IDEIndexCompletionItem *)item query:(NSString *)query
{
    NSString *completionString = item.name;
    NSRange rangeOfPrefix = [completionString rangeOfString:query];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^[A-Z]*[a-z0-9_]+(?=[^\\p{Ll}0-9])" options:0 error:nil];
    NSTextCheckingResult *result = [regex firstMatchInString:completionString options:NSMatchingAnchored range:NSMakeRange(rangeOfPrefix.length, completionString.length - rangeOfPrefix.length)];
    self.usefulPrefix = [completionString substringToIndex:result.range.location + result.range.length];
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

