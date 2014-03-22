//
//  DVTTextCompletionSession+FuzzyAutocomplete.m
//  FuzzyAutocomplete
//
//  Created by Jack Chen on 19/10/2013.
//  Copyright (c) 2013 Sproutcube. All rights reserved.
//

#import "FuzzyAutocomplete.h"
#import "DVTTextCompletionSession+FuzzyAutocomplete.h"
#import "DVTTextCompletionInlinePreviewController.h"
#import "DVTTextCompletionListWindowController.h"
#import "IDEIndexCompletionItem.h"
#import "IDEOpenQuicklyPattern.h"
#import "SCTiming.h"
#import "JRSwizzle.h"
#import <objc/runtime.h>

@implementation DVTTextCompletionSession (FuzzyAutocomplete)

static BOOL prioritizeShortestMatch;

+ (void)load
{
    prioritizeShortestMatch = [FuzzyAutocomplete shouldPrioritizeShortestMatch];
    [self swizzleMethodWithErrorLogging:@selector(_setFilteringPrefix:forceFilter:) withMethod:@selector(_fa_setFilteringPrefix:forceFilter:)];
    [self swizzleMethodWithErrorLogging:@selector(setAllCompletions:) withMethod:@selector(_fa_setAllCompletions:)];
    [self swizzleMethodWithErrorLogging:@selector(insertCurrentCompletion) withMethod:@selector(_fa_insertCurrentCompletion)];
    [self swizzleMethodWithErrorLogging:@selector(insertUsefulPrefix) withMethod:@selector(_fa_insertUsefulPrefix)];
}

+ (void)swizzleMethodWithErrorLogging:(SEL)originalMethod withMethod:(SEL)secondMethod
{
    NSError *error;
    [self jr_swizzleMethod:originalMethod withMethod:secondMethod error:&error];
    if (error) {
        ALog(@"Error while swizzling %@: %@", NSStringFromSelector(originalMethod), error);
    }
}

static char lastResultSetKey;
static char lastPrefixKey;
static char insertingCompletionKey;

- (BOOL)_fa_insertUsefulPrefix
{
    return [self insertCurrentCompletion];
}

- (BOOL)_fa_insertCurrentCompletion
{
    [self setInsertingCurrentCompletion:YES];
    return [self _fa_insertCurrentCompletion];
}

- (void)setInsertingCurrentCompletion:(BOOL)value
{
    objc_setAssociatedObject(self, &insertingCompletionKey, @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSUInteger)maxWorkerCount
{
    static NSUInteger maxWorkerCount;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // TODO: Find better way of finding physical core count
        maxWorkerCount = MAX(1, [[NSProcessInfo processInfo] activeProcessorCount] / 2);
    });
    return maxWorkerCount;
}

#define MINIMUM_SCORE_THRESHOLD 3
#define XCODE_PRIORITY_FACTOR_WEIGHTING 0.2
#define MIN_CHUNK_LENGTH 100

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
        
        double totalTime = timeVoidBlock(^{
            NSArray *searchSet;
            NSString *lastPrefix = objc_getAssociatedObject(self, &lastPrefixKey);

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

            NSUInteger workerCount = MIN(MAX(searchSet.count / MIN_CHUNK_LENGTH, 1), [self maxWorkerCount]);
            NSMutableArray *filteredList;
            
            if (workerCount > 1) {
                dispatch_queue_t processingQueue = dispatch_queue_create("com.sproutcube.fuzzyautocomplete.processing-queue", DISPATCH_QUEUE_CONCURRENT);
                dispatch_queue_t reduceQueue = dispatch_queue_create("com.sproutcube.fuzzyautocomplete.reduce-queue", DISPATCH_QUEUE_SERIAL);
                dispatch_group_t group = dispatch_group_create();
                
                NSMutableArray *bestMatches = [NSMutableArray array];
                filteredList = [NSMutableArray array];
                
                for (NSInteger i=0; i<workerCount; i++) {
                    dispatch_group_async(group, processingQueue, ^{
                        NSArray *list;
                        IDEIndexCompletionItem *bestMatch = [self bestMatchForQuery:prefix inArray:searchSet offset:i total:workerCount filteredList:&list];
                        dispatch_async(reduceQueue, ^{
                            if (bestMatch) {
                                [bestMatches addObject:bestMatch];
                            }
                            [filteredList addObjectsFromArray:list];
                        });
                    });
                }
                
                dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
                dispatch_sync(reduceQueue, ^{});
                
                bestMatch = [self bestMatchForQuery:prefix inArray:bestMatches filteredList:nil];
            }
            else {
                bestMatch = [self bestMatchForQuery:prefix inArray:searchSet filteredList:&filteredList];
            }
            
            self.filteredCompletionsAlpha = filteredList;
            
            objc_setAssociatedObject(self, &lastPrefixKey, prefix, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(self, &lastResultSetKey, filteredList, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            
            if (filteredList.count > 0 && bestMatch) {
                self.selectedCompletionIndex = [filteredList indexOfObject:bestMatch];
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
        ALog(@"An exception occurred within FuzzyAutocomplete: %@", exception);
    }
}

- (IDEIndexCompletionItem *)bestMatchForQuery:(NSString *)query inArray:(NSArray *)array filteredList:(NSArray **)filtered
{
    IDEOpenQuicklyPattern *pattern = [[IDEOpenQuicklyPattern alloc] initWithPattern:query];
    NSMutableArray *filteredList = [NSMutableArray array];
    
    __block double highScore = 0.0f;
    __block IDEIndexCompletionItem *bestMatch;
    __block NSUInteger length = 100;
    
    [array enumerateObjectsUsingBlock:^(IDEIndexCompletionItem *item, NSUInteger idx, BOOL *stop) {
        double itemPriority = MAX(item.priority, 1);
        double invertedPriority = 1 + (1.0f / itemPriority);
        double priorityFactor = (MAX([self _priorityFactorForItem:item], 1) - 1) * XCODE_PRIORITY_FACTOR_WEIGHTING + 1;
        double score = [pattern scoreCandidate:item.name] * invertedPriority * priorityFactor;
        
        if (score > MINIMUM_SCORE_THRESHOLD) {
            [filteredList addObject:item];
        }
        
        if (prioritizeShortestMatch) {
            if (score > highScore && item.name.length <= length) {
                bestMatch = item;
                highScore = score;
                length = item.name.length;
            }
        }
        else {
            if (score > highScore) {
                bestMatch = item;
                highScore = score;
            }
        }
        
    }];
    
    if (filtered) {
        *filtered = filteredList;
    }
    return bestMatch;
}

- (IDEIndexCompletionItem *)bestMatchForQuery:(NSString *)query inArray:(NSArray *)array offset:(NSUInteger)offset total:(NSUInteger)total filteredList:(NSArray **)filtered
{
    IDEOpenQuicklyPattern *pattern = [[IDEOpenQuicklyPattern alloc] initWithPattern:query];
    NSMutableArray *filteredList = [NSMutableArray array];
    
    double highScore = 0.0f;
    IDEIndexCompletionItem *bestMatch;
    IDEIndexCompletionItem *item;

    double itemPriority;
    double invertedPriority;
    double priorityFactor;
    double score;
    
    // Sequential array access faster than striding. Who would've thought?
    NSUInteger bound = (offset + 1) * (array.count / total);
    for (NSUInteger i=offset * (array.count / total); i<bound; i++) {
        item = array[i];
        
        itemPriority = MAX(item.priority, 1);
        invertedPriority = 1 + (1.0f / itemPriority);
        priorityFactor = (MAX([self _priorityFactorForItem:item], 1) - 1) * XCODE_PRIORITY_FACTOR_WEIGHTING + 1;
        score = [pattern scoreCandidate:item.name] * invertedPriority * priorityFactor;
        
        if (score > MINIMUM_SCORE_THRESHOLD) {
            [filteredList addObject:item];
        }
        if (score > highScore) {
            bestMatch = item;
            highScore = score;
        }
    }
    
    if (filtered) {
        *filtered = filteredList;
    }
    return bestMatch;
}


static char filteredCompletionCacheKey;

- (void)_fa_setAllCompletions:(NSArray *)allCompletions
{
    [self _fa_setAllCompletions:allCompletions];
    NSMutableDictionary *filterCache = objc_getAssociatedObject(self, &filteredCompletionCacheKey);
    if (filterCache) {
        DLog(@"Cache clear");
        [filterCache removeAllObjects];
    }
}

// We need to cache the first letter sets because if a user types fast enough,
// they don't trigger the standard autocomplete first letter set that we need
// for good performance.
- (NSArray *)filteredCompletionsBeginningWithLetter:(NSString *)letter
{
    letter = [letter lowercaseString];
    NSMutableDictionary *filteredCompletionCache = objc_getAssociatedObject(self, &filteredCompletionCacheKey);
    if (!filteredCompletionCache) {
        filteredCompletionCache = [[NSMutableDictionary alloc] init];
        objc_setAssociatedObject(self, &filteredCompletionCacheKey, filteredCompletionCache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSArray *completionsForLetter = [filteredCompletionCache objectForKey:letter];
    if (!completionsForLetter) {
        completionsForLetter = timeBlockAndLog(@"FirstPass", ^id{
            return [self.allCompletions filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name contains[c] %@", letter]];
        });
        [filteredCompletionCache setObject:completionsForLetter forKey:letter];
    }
    return completionsForLetter;
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

