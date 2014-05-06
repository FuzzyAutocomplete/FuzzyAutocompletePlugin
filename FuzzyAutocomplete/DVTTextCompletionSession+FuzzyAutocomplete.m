//  DVTTextCompletionSession+FuzzyAutocomplete.m
//  FuzzyAutocomplete
//
//  Created by Jack Chen on 19/10/2013.
//  Copyright (c) 2013 Sproutcube. All rights reserved.
//
//  Extended by Leszek Slazynski.
//  Copyright (c) 2014 United Lines of Code. All rights reserved.
//

#import "DVTTextCompletionSession+FuzzyAutocomplete.h"
#import "DVTTextCompletionInlinePreviewController.h"
#import "DVTTextCompletionInlinePreviewController+FuzzyAutocomplete.h"
#import "DVTTextCompletionListWindowController.h"
#import "IDEOpenQuicklyPattern.h"
#import "FATheme.h"
#import "DVTFontAndColorTheme.h"
#import "JRSwizzle.h"
#import "FASettings.h"
#import "FAItemScoringMethod.h"
#import <objc/runtime.h>

#define MIN_CHUNK_LENGTH 100
/// A simple helper class to avoid using a dictionary in resultsStack
@interface FAFilteringResults : NSObject

@property (nonatomic, retain) NSString * query;
@property (nonatomic, retain) NSArray * allItems;
@property (nonatomic, retain) NSArray * filteredItems;
@property (nonatomic, retain) NSDictionary * scores;
@property (nonatomic, retain) NSDictionary * ranges;
@property (nonatomic, assign) NSUInteger bestMatchIndex;

@end

@implementation FAFilteringResults

@end

@implementation DVTTextCompletionSession (FuzzyAutocomplete)

+ (void) fa_swizzleMethods {
    [self jr_swizzleMethod: @selector(_setFilteringPrefix:forceFilter:)
                withMethod: @selector(_fa_setFilteringPrefix:forceFilter:)
                     error: NULL];

    [self jr_swizzleMethod: @selector(setAllCompletions:)
                withMethod: @selector(_fa_setAllCompletions:)
                     error: NULL];

    [self jr_swizzleMethod: @selector(_usefulPartialCompletionPrefixForItems:selectedIndex:filteringPrefix:)
                withMethod: @selector(_fa_usefulPartialCompletionPrefixForItems:selectedIndex:filteringPrefix:)
                     error: NULL];

    [self jr_swizzleMethod: @selector(attributesForCompletionAtCharacterIndex:effectiveRange:)
                withMethod: @selector(_fa_attributesForCompletionAtCharacterIndex:effectiveRange:)
                     error: NULL];

    [self jr_swizzleMethod: @selector(rangeOfFirstWordInString:)
                withMethod: @selector(_fa_rangeOfFirstWordInString:)
                     error: NULL];

    [self jr_swizzleMethod: @selector(initWithTextView:atLocation:cursorLocation:)
                withMethod: @selector(_fa_initWithTextView:atLocation:cursorLocation:)
                     error: NULL];

    [self jr_swizzleMethod: @selector(insertCurrentCompletion)
                withMethod: @selector(_fa_insertCurrentCompletion)
                     error: nil];

    [self jr_swizzleMethod: @selector(_selectNextPreviousByPriority:)
                withMethod: @selector(_fa_selectNextPreviousByPriority:)
                     error: nil];

    [self jr_swizzleMethod: @selector(showCompletionsExplicitly:)
                withMethod: @selector(_fa_showCompletionsExplicitly:)
                     error: nil];
}

#pragma mark - public methods

- (NSArray *) fa_convertRanges: (NSArray *) originalRanges
                    fromString: (NSString *) fromString
                      toString: (NSString *) toString
                     addOffset: (NSUInteger) additionalOffset
{
    NSMutableArray * newRanges = [NSMutableArray array];
    NSRange base = [toString rangeOfString: fromString];
    if (base.location != NSNotFound) {
        for (NSValue * value in originalRanges) {
            NSRange range = [value rangeValue];
            range.location += base.location + additionalOffset;
            [newRanges addObject: [NSValue valueWithRange: range]];
        }
    } else {
        // TODO: consider changing to componentsSeparatedByString: for performance (?)
        NSRegularExpression * selectorSegmentRegex = [NSRegularExpression regularExpressionWithPattern: @"[a-zA-Z_][a-zA-Z0-9_]*:" options: 0 error: NULL];
        [selectorSegmentRegex enumerateMatchesInString: fromString options: 0 range: NSMakeRange(0, fromString.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
            NSRange nameRange = result.range;
            NSRange dispRange = [toString rangeOfString: [fromString substringWithRange: nameRange]];
            if (dispRange.location != NSNotFound) {
                for (NSValue * value in originalRanges) {
                    NSRange range = [value rangeValue];
                    NSRange intersection = NSIntersectionRange(range, nameRange);
                    if (intersection.length > 0) {
                        intersection.location += dispRange.location - nameRange.location + additionalOffset;
                        [newRanges addObject: [NSValue valueWithRange: intersection]];
                    }
                }
            }
        }];
    }
    return newRanges;
}

- (NSArray *) fa_matchedRangesForItem: (id<DVTTextCompletionItem>) item {
    return [[self fa_matchedRangesForFilteredCompletions] objectForKey: item.name];
}

- (NSNumber *) fa_scoreForItem: (id<DVTTextCompletionItem>) item {
    return [[self fa_scoresForFilteredCompletions] objectForKey: item.name];
}

- (NSUInteger) fa_nonZeroScores {
    return [self fa_scoresForFilteredCompletions].count;
}

#pragma mark - overrides

- (BOOL) _fa_insertCurrentCompletion {
    self.fa_insertingCompletion = YES;
    BOOL ret = [self _fa_insertCurrentCompletion];
    self.fa_insertingCompletion = NO;
    return ret;
}

// We override here to hide inline preview if disabled
- (void) _fa_showCompletionsExplicitly: (BOOL) explicitly {
    [self _fa_showCompletionsExplicitly: explicitly];
    if (![FASettings currentSettings].showInlinePreview) {
        [self._inlinePreviewController hideInlinePreviewWithReason: 0x0];
    }
}

// We additionally load the settings and refresh the theme upon session creation.
- (instancetype) _fa_initWithTextView: (NSTextView *) textView
                           atLocation: (NSInteger) location
                       cursorLocation: (NSInteger) cursorLocation
{
    [[FASettings currentSettings] loadFromDefaults];
    [[FATheme cuurrentTheme] loadFromTheme: [DVTFontAndColorTheme currentTheme]];
    DVTTextCompletionSession * session = [self _fa_initWithTextView:textView atLocation:location cursorLocation:cursorLocation];
    if (session) {
        FAItemScoringMethod * method = [[FAItemScoringMethod alloc] init];
        FASettings * settings = [FASettings currentSettings];

        method.matchScorePower = settings.matchScorePower;
        method.priorityFactorPower = settings.priorityFactorPower;
        method.priorityPower = settings.priorityPower;
        method.maxPrefixBonus = settings.maxPrefixBonus;

        session._fa_currentScoringMethod = method;

        session._fa_resultsStack = [NSMutableArray array];
    }
    return session;
}

// Based on the first word, either completionString or name is used for preview.
// We override in such a way that the name is always used.
// Otherwise the cursor can be possibly placed inside a token.
- (NSRange) _fa_rangeOfFirstWordInString: (NSString *) string {
    return NSMakeRange(0, string.length);
}

// We override to calculate _filteredCompletionsAlpha before calling the original
// This way the hotkeys for prev/next by score use our scoring, not Xcode's
- (void) _fa_selectNextPreviousByPriority: (BOOL) next {
    if (![self valueForKey: @"_filteredCompletionsPriority"]) {
        NSArray * sorted = nil;
        NSDictionary * filteredScores = self.fa_scoresForFilteredCompletions;
        if ([FASettings currentSettings].sortByScore) {
            sorted = self.filteredCompletionsAlpha.reverseObjectEnumerator.allObjects;
        } else if (filteredScores) {
            sorted = [self.filteredCompletionsAlpha sortedArrayWithOptions: NSSortConcurrent
                                                           usingComparator: [self _fa_itemComparatorByScores: filteredScores reverse: NO]];
        }
        [self setValue: sorted forKey: @"_filteredCompletionsPriority"];
    }

    [self _fa_selectNextPreviousByPriority: next];
}

// We override to add formatting to the inline preview.
// The ghostCompletionRange is also overriden to be after the last matched letter.
- (NSDictionary *) _fa_attributesForCompletionAtCharacterIndex: (NSUInteger) index
                                                effectiveRange: (NSRange *) effectiveRange
{
    NSDictionary * ret = [self _fa_attributesForCompletionAtCharacterIndex:index effectiveRange:effectiveRange];

    if ([self._inlinePreviewController isShowingInlinePreview]) {
        if (NSLocationInRange(index, [self._inlinePreviewController previewRange])) {
            *effectiveRange = ret ? NSIntersectionRange(*effectiveRange, [self._inlinePreviewController previewRange]) : [self._inlinePreviewController previewRange];
            BOOL matched = NO;
            for (NSValue * val in [self._inlinePreviewController fa_matchedRanges]) {
                NSRange range = [val rangeValue];
                if (NSLocationInRange(index, range)) {
                    matched = YES;
                    *effectiveRange = NSIntersectionRange(range, *effectiveRange);
                    break;
                } else if (range.location > index) {
                    *effectiveRange = NSIntersectionRange(NSMakeRange(index, range.location - index), *effectiveRange);
                    break;
                }
            }
            if (!matched) {
                NSMutableDictionary * dict = [NSMutableDictionary dictionaryWithDictionary: ret];
                [dict addEntriesFromDictionary: [FATheme cuurrentTheme].previewTextAttributesForNotMatchedRanges];
                ret = dict;
            }
        }
    }
    return ret;
}

// We replace the search string by a prefix to the last matched letter.
- (NSString *) _fa_usefulPartialCompletionPrefixForItems: (NSArray *) items
                                           selectedIndex: (NSInteger) index
                                         filteringPrefix: (NSString *) prefix
{
    if (!items.count || index == NSNotFound || index > items.count) {
        return nil;
    }
    NSRange range = NSMakeRange(0, prefix.length);
    id<DVTTextCompletionItem> item = items[index];
    NSArray * ranges = [[[IDEOpenQuicklyPattern alloc] initWithPattern: prefix] matchedRanges: item.name];
    for (NSValue * val in ranges) {
        range = NSUnionRange(range, [val rangeValue]);
    }
    return [self _fa_usefulPartialCompletionPrefixForItems:items selectedIndex:index filteringPrefix:[item.name substringWithRange: range]];
}

// Sets the current filtering prefix and calculates completion list.
// We override here to use fuzzy matching.
- (void)_fa_setFilteringPrefix: (NSString *) prefix forceFilter: (BOOL) forceFilter {
    DLog(@"filteringPrefix = @\"%@\"", prefix);

    // remove all cached results which are not case-insensitive prefixes of the new prefix
    // only if case-sensitive exact match happens the whole cached result is used
    // when case-insensitive prefix match happens we can still use allItems as a start point
    NSMutableArray * resultsStack = self._fa_resultsStack;
    while (resultsStack.count && ![prefix.lowercaseString hasPrefix: [[resultsStack lastObject] query].lowercaseString]) {
        [resultsStack removeLastObject];
    }

    self.fa_filteringTime = 0;

    // Let the original handler deal with the zero letter case
    if (prefix.length == 0) {
        NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];

        [self._fa_resultsStack removeAllObjects];

        [self _fa_setFilteringPrefix:prefix forceFilter:forceFilter];
        if (![FASettings currentSettings].showInlinePreview) {
            [self._inlinePreviewController hideInlinePreviewWithReason: 0x0];
        }

        self.fa_filteringTime = [NSDate timeIntervalSinceReferenceDate] - start;

        if ([FASettings currentSettings].showTiming) {
            [self._listWindowController _updateCurrentDisplayState];
        }

        return;
    }

    // do not filter if we are inserting a completion
    // checking for _insertingFullCompletion is not sufficient
    if (self.fa_insertingCompletion) {
        return;
    }

    @try {

        NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];

        [self setValue: prefix forKey: @"_filteringPrefix"];

        id<DVTTextCompletionItem> prevSelection = nil;
        NSArray * prevSelectionPrevRanges = nil;

        FAFilteringResults * results;

        if (resultsStack.count && [prefix isEqualToString: [[resultsStack lastObject] query]]) {
            results = [resultsStack lastObject];
        } else {
            if (self.selectedCompletionIndex != NSNotFound) {
                prevSelection = self.filteredCompletionsAlpha[self.selectedCompletionIndex];
                prevSelectionPrevRanges = [self fa_matchedRangesForItem: prevSelection];
            }
            results = [self _fa_calculateResultsForQuery: prefix];
            [resultsStack addObject: results];
        }

        NSUInteger selection = results.bestMatchIndex;
        NSArray * prevSelectionRanges = [self fa_matchedRangesForItem: prevSelection];
        if (prevSelectionRanges.count && prevSelectionRanges.count == prevSelectionPrevRanges.count) {
            NSRange lastRangePrev = [prevSelectionPrevRanges.lastObject rangeValue];
            NSRange lastRange = [prevSelectionRanges.lastObject rangeValue];
            if (lastRange.location == lastRangePrev.location && lastRange.length >= lastRangePrev.length) {
                NSComparator comparator = nil;
                if ([FASettings currentSettings].sortByScore) {
                    comparator = [self _fa_itemComparatorByScores: results.scores reverse: YES];
                } else {
                    comparator = [self _fa_itemComparatorByName];
                }
                NSUInteger prevSelectionIndex = [self _fa_indexOfElement: prevSelection
                                                           inSortedArray: results.filteredItems
                                                         usingComparator: comparator];
                if (prevSelectionIndex != NSNotFound) {
                    selection = prevSelectionIndex;
                }
            }
        }

        NSString * partial = [self _usefulPartialCompletionPrefixForItems: results.filteredItems
                                                            selectedIndex: selection
                                                          filteringPrefix: prefix];

        self.fa_filteringTime = [NSDate timeIntervalSinceReferenceDate] - start;

        NAMED_TIMER_START(SendNotifications);

        // send the notifications in the same way the original does
        [self willChangeValueForKey:@"filteredCompletionsAlpha"];
        [self willChangeValueForKey:@"usefulPrefix"];
        [self willChangeValueForKey:@"selectedCompletionIndex"];
        
        [self setValue: results.filteredItems forKey: @"_filteredCompletionsAlpha"];
        [self setValue: partial forKey: @"_usefulPrefix"];
        [self setValue: @(selection) forKey: @"_selectedCompletionIndex"];
        [self setValue: nil forKey: @"_filteredCompletionsPriority"];

        [self didChangeValueForKey:@"filteredCompletionsAlpha"];
        [self didChangeValueForKey:@"usefulPrefix"];
        [self didChangeValueForKey:@"selectedCompletionIndex"];

        NAMED_TIMER_STOP(SendNotifications);

        if (![FASettings currentSettings].showInlinePreview) {
            [self._inlinePreviewController hideInlinePreviewWithReason: 0x0];
        }

    }
    @catch (NSException *exception) {
        RLog(@"Caught an Exception %@", exception);
    }
    @finally {
        
    }
    
}

// We nullify the caches when completions change.
- (void) _fa_setAllCompletions: (NSArray *) allCompletions {
    [self _fa_setAllCompletions:allCompletions];
    [self._fa_resultsStack removeAllObjects];
}

#pragma mark - helpers

// Calculate all the results needed by setFilteringPrefix
- (FAFilteringResults *)_fa_calculateResultsForQuery: (NSString *) query {

    FAFilteringResults * results = [[FAFilteringResults alloc] init];
    results.query = query;

    NSArray *searchSet = nil;
    NSMutableArray * filteredList = nil;
    __block NSMutableDictionary * filteredRanges = nil;
    __block NSMutableDictionary * filteredScores = nil;

    const NSInteger anchor = [FASettings currentSettings].prefixAnchor;

    FAFilteringResults * lastResults = [self _fa_lastFilteringResults];

    NAMED_TIMER_START(ObtainSearchSet);

    if (lastResults.query.length && [[query lowercaseString] hasPrefix: [lastResults.query lowercaseString]]) {
        if (lastResults.query.length >= anchor) {
            searchSet = lastResults.allItems;
        } else {
            searchSet = [self _fa_filteredCompletionsForPrefix: [query substringToIndex: MIN(query.length, anchor)]];
        }
    } else {
        if (anchor > 0) {
            searchSet = [self _fa_filteredCompletionsForPrefix: [query substringToIndex: MIN(query.length, anchor)]];
        } else {
            searchSet = [self _fa_filteredCompletionsForLetter: [query substringToIndex:1]];
        }
    }

    NAMED_TIMER_STOP(ObtainSearchSet);

    __block id<DVTTextCompletionItem> bestMatch = nil;

    NSUInteger workerCount = [FASettings currentSettings].parallelScoring ? [FASettings currentSettings].maximumWorkers : 1;
    workerCount = MIN(MAX(searchSet.count / MIN_CHUNK_LENGTH, 1), workerCount);

    NAMED_TIMER_START(CalculateScores);

    if (workerCount < 2) {
        bestMatch = [self _fa_bestMatchForQuery: query
                                        inArray: searchSet
                                   filteredList: &filteredList
                                      rangesMap: &filteredRanges
                                         scores: &filteredScores];
    } else {
        dispatch_queue_t processingQueue = dispatch_queue_create("io.github.FuzzyAutocomplete.processing-queue", DISPATCH_QUEUE_CONCURRENT);
        dispatch_queue_t reduceQueue = dispatch_queue_create("io.github.FuzzyAutocomplete.reduce-queue", DISPATCH_QUEUE_SERIAL);
        dispatch_group_t group = dispatch_group_create();

        NSMutableArray * sortedItemArrays = [NSMutableArray array];
        for (NSInteger i = 0; i < workerCount; ++i) {
            [sortedItemArrays addObject: @[]];
        }
    
        for (NSInteger i = 0; i < workerCount; ++i) {
            dispatch_group_async(group, processingQueue, ^{
                NSMutableArray *list;
                NSMutableDictionary *rangesMap;
                NSMutableDictionary *scoresMap;
                NAMED_TIMER_START(Processing);
                id<DVTTextCompletionItem> goodMatch = [self _fa_bestMatchForQuery: query
                                                                          inArray: searchSet
                                                                           offset: i
                                                                            total: workerCount
                                                                     filteredList: &list
                                                                        rangesMap: &rangesMap
                                                                           scores: &scoresMap];
                NAMED_TIMER_STOP(Processing);
                dispatch_async(reduceQueue, ^{
                    NAMED_TIMER_START(Reduce);
                    sortedItemArrays[i] = list;
                    if (!filteredRanges) {
                        filteredRanges = rangesMap;
                        filteredScores = scoresMap;
                        bestMatch = goodMatch;
                    } else {
                        [filteredRanges addEntriesFromDictionary: rangesMap];
                        [filteredScores addEntriesFromDictionary: scoresMap];
                        if ([filteredScores[goodMatch.name] doubleValue] > [filteredScores[bestMatch.name] doubleValue]) {
                            bestMatch = goodMatch;
                        }
                    }
                    NAMED_TIMER_STOP(Reduce);
                });
            });
        }

        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        dispatch_sync(reduceQueue, ^{});

        filteredList = sortedItemArrays[0];
        for (NSInteger i = 1; i < workerCount; ++i) {
            [filteredList addObjectsFromArray: sortedItemArrays[i]];
        }
    }

    NAMED_TIMER_STOP(CalculateScores);

    results.allItems = [NSArray arrayWithArray: filteredList];

    NAMED_TIMER_START(FilterByScore);

    double threshold = [FASettings currentSettings].minimumScoreThreshold;
    if ([FASettings currentSettings].filterByScore && threshold != 0) {
        if ([FASettings currentSettings].normalizeScores) {
            threshold *= [filteredScores[bestMatch.name] doubleValue];
        }
        NSMutableArray * newArray = [NSMutableArray array];
        for (id<DVTTextCompletionItem> item in filteredList) {
            if ([filteredScores[item.name] doubleValue] >= threshold) {
                [newArray addObject: item];
            }
        }
        filteredList = newArray;
    }

    NAMED_TIMER_STOP(FilterByScore);

    NAMED_TIMER_START(SortByScore);

    if ([FASettings currentSettings].sortByScore) {
        [filteredList sortWithOptions: NSSortConcurrent usingComparator: [self _fa_itemComparatorByScores: filteredScores reverse: YES]];
    }

    NAMED_TIMER_STOP(SortByScore);

    NAMED_TIMER_START(FindSelection);
    
    if (!filteredList.count || !bestMatch) {
        results.bestMatchIndex = NSNotFound;
    } else {
        if ([FASettings currentSettings].sortByScore) {
            results.bestMatchIndex = 0;
        } else {
            results.bestMatchIndex = [self _fa_indexOfElement: bestMatch
                                                inSortedArray: filteredList
                                              usingComparator: [self _fa_itemComparatorByName]];
        }
    }

    NAMED_TIMER_STOP(FindSelection);

    results.filteredItems = filteredList;
    results.ranges = filteredRanges;
    results.scores = filteredScores;

    return results;
}

// Score the items, store filtered list, matched ranges, scores and the best match.
- (id<DVTTextCompletionItem>) _fa_bestMatchForQuery: (NSString *) query
                                            inArray: (NSArray *) array
                                       filteredList: (NSMutableArray **) filtered
                                          rangesMap: (NSMutableDictionary **) ranges
                                             scores: (NSMutableDictionary **) scores
{
    return [self _fa_bestMatchForQuery:query inArray:array offset:0 total:1 filteredList:filtered rangesMap:ranges scores:scores];
}

// Score some of the items, store filtered list, matched ranges, scores and the best match.
- (id<DVTTextCompletionItem>) _fa_bestMatchForQuery: (NSString *) query
                                            inArray: (NSArray *) array
                                             offset: (NSUInteger) offset
                                              total: (NSUInteger) total
                                       filteredList: (NSMutableArray **) filtered
                                          rangesMap: (NSMutableDictionary **) ranges
                                             scores: (NSMutableDictionary **) scores
{
    IDEOpenQuicklyPattern *pattern = [[IDEOpenQuicklyPattern alloc] initWithPattern:query];
    NSMutableArray *filteredList = filtered ? [NSMutableArray arrayWithCapacity: array.count / total] : nil;
    NSMutableDictionary *filteredRanges = ranges ? [NSMutableDictionary dictionaryWithCapacity: array.count / total] : nil;
    NSMutableDictionary *filteredScores = scores ? [NSMutableDictionary dictionaryWithCapacity: array.count / total] : nil;

    double highScore = 0.0f;
    id<DVTTextCompletionItem> bestMatch;

    FAItemScoringMethod * method = self._fa_currentScoringMethod;

    double normalization = [method normalizationFactorForSearchString: query];

    id<DVTTextCompletionItem> item;
    NSUInteger lower_bound = offset * (array.count / total);
    NSUInteger upper_bound = offset == total - 1 ? array.count : (offset + 1) * (array.count / total);

    DLog(@"Process elements %lu %lu (%lu)", lower_bound, upper_bound, array.count);

    MULTI_TIMER_INIT(Matching); MULTI_TIMER_INIT(Scoring); MULTI_TIMER_INIT(Writing);

    for (NSUInteger i = lower_bound; i < upper_bound; ++i) {
        item = array[i];
        NSArray * rangesArray;
        double matchScore;

        MULTI_TIMER_START(Matching);
        if (query.length == 1) {
            NSRange range = [item.name rangeOfString: query options: NSCaseInsensitiveSearch];
            if (range.location != NSNotFound) {
                rangesArray = @[ [NSValue valueWithRange:range] ];
                matchScore = MAX(0.001, [pattern scoreCandidate:item.name matchedRanges:&rangesArray]);
            } else {
                matchScore = 0;
            }
        } else {
            matchScore = [pattern scoreCandidate:item.name matchedRanges:&rangesArray];
        }
        MULTI_TIMER_STOP(Matching);

        if (matchScore > 0) {
            MULTI_TIMER_START(Scoring);
            double factor = [self _priorityFactorForItem:item];
            double score = normalization * [method scoreItem: item
                                                searchString: query
                                                  matchScore: matchScore
                                               matchedRanges: rangesArray
                                              priorityFactor: factor];
            MULTI_TIMER_STOP(Scoring);
            MULTI_TIMER_START(Writing);
            if (score > 0) {
                [filteredList addObject:item];
                filteredRanges[item.name] = rangesArray ?: @[];
                filteredScores[item.name] = @(score);
            }
            if (score > highScore) {
                bestMatch = item;
                highScore = score;
            }
            MULTI_TIMER_STOP(Writing);
        }
    }

    DLog(@"Matching %f | Scoring %f | Writing %f", MULTI_TIMER_GET(Matching), MULTI_TIMER_GET(Scoring), MULTI_TIMER_GET(Writing));

    if (filtered) {
        *filtered = filteredList;
    }
    if (ranges) {
        *ranges = filteredRanges;
    }
    if (scores) {
        *scores = filteredScores;
    }
    return bestMatch;
}

// Returns index of first element passing test, or NSNotFound, assumes sorted range wrt test
- (NSUInteger) _fa_indexOfFirstElementInSortedRange: (NSRange) range
                                            inArray: (NSArray *) array
                                        passingTest: (BOOL(^)(id)) test
{
    if (range.length == 0) return NSNotFound;
    NSUInteger a = range.location, b = range.location + range.length - 1;
    if (test(array[a])) {
        return a;
    } else if (!test(array[b])) {
        return NSNotFound;
    } else {
        while (b > a + 1) {
            NSUInteger c = (a + b) / 2;
            if (test(array[c])) {
                b = c;
            } else {
                a = c;
            }
        }
        return b;
    }
}

// Returns index of the first element equal to given, or NSNotFound if none
- (NSUInteger) _fa_indexOfElement: (id) element
                    inSortedArray: (NSArray *) array
                  usingComparator: (NSComparator) comparator
{
    NSUInteger lowerBound = [self _fa_indexOfFirstElementInSortedRange: NSMakeRange(0, array.count) inArray: array passingTest: ^BOOL(id x) {
        return comparator(x, element) != NSOrderedAscending;
    }];
    if (lowerBound != NSNotFound && comparator(array[lowerBound], element) == NSOrderedSame) {
        return lowerBound;
    } else {
        return NSNotFound;
    }
}


// Performs binary searches to find items with given prefix.
- (NSRange) _fa_rangeOfItemsWithPrefix: (NSString *) prefix
                         inSortedRange: (NSRange) range
                               inArray: (NSArray *) array
{
    NSUInteger lowerBound = [self _fa_indexOfFirstElementInSortedRange: range inArray: array passingTest: ^BOOL(id<DVTTextCompletionItem> item) {
        return [item.name caseInsensitiveCompare: prefix] != NSOrderedAscending;
    }];

    if (lowerBound == NSNotFound) {
        return NSMakeRange(0, 0);
    }

    range.location += lowerBound; range.length -= lowerBound;

    NSUInteger upperBound = [self _fa_indexOfFirstElementInSortedRange: range inArray: array passingTest: ^BOOL(id<DVTTextCompletionItem> item) {
        return ![item.name.lowercaseString hasPrefix: prefix];
    }];

    if (upperBound != NSNotFound) {
        range.length = upperBound - lowerBound;
    }

    return range;
}

// gets a subset of allCompletions for given prefix
- (NSArray *) _fa_filteredCompletionsForPrefix: (NSString *) prefix {
    prefix = [prefix lowercaseString];
    FAFilteringResults * lastResults = [self _fa_lastFilteringResults];
    NSArray * array;
    if ([lastResults.query.lowercaseString hasPrefix: prefix]) {
        array = lastResults.allItems;
    } else {
        NSArray * searchSet = lastResults.allItems ?: self.allCompletions;
        // searchSet is sorted so we can do a binary search
        NSRange range = [self _fa_rangeOfItemsWithPrefix: prefix inSortedRange: NSMakeRange(0, searchSet.count) inArray: searchSet];
        array = [searchSet subarrayWithRange: range];
    }
    return array;
}

// gets a subset of allCompletions for given letter
- (NSArray *) _fa_filteredCompletionsForLetter: (NSString *) letter {
    letter = [letter lowercaseString];

    NSString * lowerAndUpper = [letter stringByAppendingString: letter.uppercaseString];
    NSCharacterSet * set = [NSCharacterSet characterSetWithCharactersInString: lowerAndUpper];
    NSMutableArray * array = [NSMutableArray array];
    for (id<DVTTextCompletionItem> item in self.allCompletions) {
        NSRange range = [item.name rangeOfCharacterFromSet: set];
        if (range.location != NSNotFound) {
            [array addObject: item];
        }
    }
    return array;
}

// gets alphabetical comparator
- (NSComparator) _fa_itemComparatorByName {
    return ^(id<DVTTextCompletionItem> obj1, id<DVTTextCompletionItem> obj2) {
        return [obj1.name caseInsensitiveCompare: obj2.name];
    };
}

// gets a comparator for given scores dictionary
- (NSComparator) _fa_itemComparatorByScores: (NSDictionary *) filteredScores reverse: (BOOL) reverse {
    if (!reverse) {
        return ^(id<DVTTextCompletionItem> obj1, id<DVTTextCompletionItem> obj2) {
            NSComparisonResult result = [filteredScores[obj1.name] compare: filteredScores[obj2.name]];
            return result == NSOrderedSame ? [obj2.name caseInsensitiveCompare: obj1.name] : result;
        };
    } else {
        return ^(id<DVTTextCompletionItem> obj1, id<DVTTextCompletionItem> obj2) {
            NSComparisonResult result = [filteredScores[obj2.name] compare: filteredScores[obj1.name]];
            return result == NSOrderedSame ? [obj1.name caseInsensitiveCompare: obj2.name] : result;
        };
    }
}

- (void)_fa_debugCompletionsByScore:(NSArray *)completions withQuery:(NSString *)query {
    IDEOpenQuicklyPattern *pattern = [IDEOpenQuicklyPattern patternWithInput:query];
    NSMutableArray *completionsWithScore = [NSMutableArray arrayWithCapacity:completions.count];

    [completions enumerateObjectsUsingBlock:^(id<DVTTextCompletionItem> item, NSUInteger idx, BOOL *stop) {
        NSArray * ranges = nil;
        double matchScore = [pattern scoreCandidate: item.name matchedRanges: &ranges];
        double factor = [self _priorityFactorForItem: item];
        [completionsWithScore addObject:@{
            @"item"       : item.name,
            @"ranges"     : ranges ? ranges : @[],
            @"factor"     : @(factor),
            @"priority"   : @(item.priority),
            @"matchScore" : @(matchScore),
            @"score"      : @([self._fa_currentScoringMethod scoreItem: item searchString: query matchScore: matchScore matchedRanges: ranges priorityFactor: factor])
        }];
    }];

    NSSortDescriptor *sortByScore = [NSSortDescriptor sortDescriptorWithKey:@"score" ascending:NO];

    [completionsWithScore sortUsingDescriptors:@[sortByScore]];
    
    [completionsWithScore enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        RLog(@"%lu - %@", idx + 1, obj);
        if (idx == 24) *stop = YES;
    }];

}

#pragma mark - properties

- (NSString *)fa_filteringQuery {
    return [self valueForKey: @"_filteringPrefix"];
}

static char kTimeKey;
- (NSTimeInterval)fa_lastFilteringTime {
    return [objc_getAssociatedObject(self, &kTimeKey) doubleValue];
}

- (void)setFa_filteringTime:(NSTimeInterval)value {
    objc_setAssociatedObject(self, &kTimeKey, @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static char currentScoringMethodKey;

- (FAItemScoringMethod *) _fa_currentScoringMethod {
    return objc_getAssociatedObject(self, &currentScoringMethodKey);
}

- (void) set_fa_currentScoringMethod: (FAItemScoringMethod *) value {
    objc_setAssociatedObject(self, &currentScoringMethodKey, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static char insertingCompletionKey;

- (BOOL) fa_insertingCompletion {
    return [objc_getAssociatedObject(self, &insertingCompletionKey) boolValue];
}

- (void) setFa_insertingCompletion: (BOOL) value {
    objc_setAssociatedObject(self, &insertingCompletionKey, @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDictionary *) fa_matchedRangesForFilteredCompletions {
    return [self._fa_resultsStack.lastObject ranges];
}

- (NSDictionary *) fa_scoresForFilteredCompletions {
    return [self._fa_resultsStack.lastObject scores];
}

static char kResultsStackKey;
- (NSMutableArray *) _fa_resultsStack {
    return objc_getAssociatedObject(self, &kResultsStackKey);
}

- (void) set_fa_resultsStack: (NSMutableArray *) stack {
    objc_setAssociatedObject(self, &kResultsStackKey, stack, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (FAFilteringResults *) _fa_lastFilteringResults {
    return self._fa_resultsStack.lastObject;
}

@end