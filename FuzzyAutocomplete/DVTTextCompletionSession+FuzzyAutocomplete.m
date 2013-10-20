//
//  DVTTextCompletionSession+FuzzyAutocomplete.m
//  FuzzyAutocomplete
//
//  Created by Jack Chen on 19/10/2013.
//  Copyright (c) 2013 chendo interactive. All rights reserved.
//

#import "DVTTextCompletionSession+FuzzyAutocomplete.h"
#import "IDEIndexCompletionItem.h"
#import "IDEOpenQuicklyPattern.h"
#import "SCTiming.h"
#import <JRSwizzle.h>

@interface FACompletionItem : NSObject

- (instancetype)initWithItemAndScore:(id)item score:(float)score;
@property (readonly, nonatomic) id item;
@property (readonly, assign) float score;

@end

@implementation FACompletionItem

- (instancetype)initWithItemAndScore:(id)item score:(float)score
{
    if (self = [super init]) {
        _item = item;
        _score = score;
    }
    return self;
}

@end

@implementation DVTTextCompletionSession (FuzzyAutocomplete)

+ (void)load
{
    [self jr_swizzleMethod:@selector(_setFilteringPrefix:forceFilter:) withMethod:@selector(_fa_setFilteringPrefix:forceFilter:) error:nil];
//    [self jr_swizzleMethod:@selector(_bestMatchInSortedArray:usingPrefix:) withMethod:@selector(_fa_bestMatchInSortedArray:usingPrefix:) error:nil];
//    [self jr_swizzleMethod:@selector(_usefulPartialCompletionPrefixForItems:selectedIndex:filteringPrefix:) withMethod:@selector(_fa_usefulPartialCompletionPrefixForItems:selectedIndex:filteringPrefix:) error:nil];
}

// Sets the current filtering prefix
- (void)_fa_setFilteringPrefix:(NSString *)prefix forceFilter:(BOOL)forceFilter
{
    // We need to call the original method otherwise the autocomplete won't show up
    // TODO: Figure out what we need to call to make the window show

    timeBlockAndLog(@"Original filter", ^id{
        [self _fa_setFilteringPrefix:prefix forceFilter:forceFilter];
        return nil;
    });
    
    if ([prefix rangeOfString:@"d"].location != 0) {
        return;
    }

    double totalTime = timeVoidBlock(^{
        NSMutableString *predicateString = [NSMutableString string];
        [prefix enumerateSubstringsInRange:NSMakeRange(0, prefix.length) options:NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
            [predicateString appendFormat:@"%@*", substring];
        }];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name like[c] %@", predicateString];
        
        NSArray *filtered = timeBlockAndLog(@"Filtering", ^id{
            return [self.allCompletions filteredArrayUsingPredicate:predicate];
        });
        
        ALog(@"Filter: %lu to %lu", self.allCompletions.count, (unsigned long)filtered.count);
        
        IDEOpenQuicklyPattern *pattern = [IDEOpenQuicklyPattern patternWithInput:prefix];
        
        NSArray *sorted = timeBlockAndLog(@"Best match time", ^id{
            return [filtered sortedArrayUsingComparator:^NSComparisonResult(IDEIndexCompletionItem *obj1, IDEIndexCompletionItem *obj2) {
                double score1 = [pattern scoreCandidate:obj1.name] * obj1.priority;
                double score2 = [pattern scoreCandidate:obj2.name] * obj2.priority;
                
                return score1 < score2 ? NSOrderedDescending : NSOrderedAscending;
            }];
        });
        
        self.filteredCompletionsAlpha = filtered;
        if (filtered.count > 0) {
            timeBlockAndLog(@"IndexOf", ^id{
                self.selectedCompletionIndex = [filtered indexOfObject:sorted[0]];
                return nil;
            });
        }
    });
    ALog(@"Total time: %f", totalTime);
    
}


// This returns the best match's index out of the first param
- (unsigned long long)_fa_bestMatchInSortedArray:(NSArray *)array usingPrefix:(NSString *)prefix
{
    unsigned long long ret = [self _fa_bestMatchInSortedArray:array usingPrefix:prefix];
//    ALog(@"best match: %llu %@ -- prefix: %@ array size: %lu", ret, array[ret], prefix, (unsigned long)array.count);
    
    return ret;
}

// Returns what the Tab key should add in
- (id)_fa_usefulPartialCompletionPrefixForItems:(id)arg1 selectedIndex:(unsigned long long)arg2 filteringPrefix:(id)arg3
{
    id ret = [self _fa_usefulPartialCompletionPrefixForItems:arg1 selectedIndex:arg2 filteringPrefix:arg3];
    
    ALog(@"Useful partial completions - ret class: %@ index: %llu prefix: %@", ret, arg2, arg3);
    return ret;
}


- (void)logArrayDetails:(NSArray *)array name:(NSString *)name
{
    NSArray *subarray = [array subarrayWithRange:NSMakeRange(0, MIN(array.count, 10))];
    [subarray enumerateObjectsUsingBlock:^(IDEIndexCompletionItem *item, NSUInteger idx, BOOL *stop) {
        ALog(@"item: %@ disp text: %@ parent: %@", item, item.displayText, item.parentText);
    }];
    ALog(@"Total: %lu", (unsigned long)array.count);
}


@end

