//
//  DVTTextCompletionInlinePreviewController+FuzzyAutocomplete.m
//  FuzzyAutocomplete
//
//  Created by Leszek Slazynski on 03/02/2014.
//  Copyright (c) 2014 United Lines of Code. All rights reserved.
//

#import "DVTTextCompletionInlinePreviewController+FuzzyAutocomplete.h"
#import "DVTTextCompletionSession.h"
#import "DVTTextCompletionSession+FuzzyAutocomplete.h"
#import "DVTFontAndColorTheme.h"
#import "FASettings.h"
#import "JRSwizzle.h"
#import <objc/runtime.h>

@implementation DVTTextCompletionInlinePreviewController (FuzzyAutocomplete)

+ (void) fa_swizzleMethods {
    [self jr_swizzleMethod: @selector(ghostComplementRange)
                withMethod: @selector(_fa_ghostComplementRange)
                     error: NULL];

    [self jr_swizzleMethod: @selector(_showPreviewForItem:)
                withMethod: @selector(_fa_showPreviewForItem:)
                     error: NULL];

    [self jr_swizzleMethod: @selector(hideInlinePreviewWithReason:)
                withMethod: @selector(_fa_hideInlinePreviewWithReason:)
                     error: nil];
}

#pragma mark - overrides

- (void)_fa_hideInlinePreviewWithReason: (int) reason {
    DVTTextCompletionSession * session = [self valueForKey: @"_session"];
    NSTextView * textView = (NSTextView *) session.textView;
    textView.insertionPointColor = [textView.insertionPointColor colorWithAlphaComponent: 1];
    [self _fa_hideInlinePreviewWithReason: reason];
}

// We added calculation of matchedRanges and ghostRange here.
- (void) _fa_showPreviewForItem: (id<DVTTextCompletionItem>) item {
    [self _fa_showPreviewForItem: item];

    DVTTextCompletionSession * session = [self valueForKey: @"_session"];

    NSArray * ranges = [session fa_matchedRangesForItem: item];

    if (!ranges.count) {
        self.fa_matchedRanges = nil;
        self.fa_overridedGhostRange = nil;
        return;
    }

    NSUInteger previewLength = self.previewRange.length;
    NSString *previewText;
    NSTextView * textView = (NSTextView *) session.textView;

    if (previewLength == item.completionText.length) {
        previewText = item.completionText;
    } else if (previewLength == item.name.length) {
        previewText = item.name;
    } else if (previewLength == item.displayText.length) {
        previewText = item.displayText;
    } else {
        previewText = [[textView.textStorage attributedSubstringFromRange: self.previewRange] string];
    }
    ranges = [session fa_convertRanges: ranges
                            fromString: item.name
                              toString: previewText
                             addOffset: self.previewRange.location];

    if (!ranges.count) {
        self.fa_overridedGhostRange = nil;
        textView.insertionPointColor = [textView.insertionPointColor colorWithAlphaComponent: 1];
    } else {
        NSRange lastRange = [[ranges lastObject] rangeValue];
        NSUInteger start = NSMaxRange(lastRange);
        NSUInteger end = NSMaxRange(self.previewRange);
        NSRange override = NSMakeRange(start, end - start);
        self.fa_overridedGhostRange = [NSValue valueWithRange: override];
        if (![FASettings currentSettings].hideCursorInNonPrefixPreview || session.cursorLocation == start) {
            textView.insertionPointColor = [textView.insertionPointColor colorWithAlphaComponent: 1];
        } else {
            textView.insertionPointColor = [textView.insertionPointColor colorWithAlphaComponent: 0];
        }
    }

    self.fa_matchedRanges = ranges;
}

- (NSRange) _fa_ghostComplementRange {
    NSValue * override = self.fa_overridedGhostRange;
    if (override) {
        return [override rangeValue];
    }
    return [self _fa_ghostComplementRange];
}

#pragma mark - additional properties

static char overrideGhostKey;
static char matchedRangesKey;

- (NSArray *)fa_matchedRanges {
    return objc_getAssociatedObject(self, &matchedRangesKey);
}

- (void)setFa_matchedRanges:(NSArray *)array {
    objc_setAssociatedObject(self, &matchedRangesKey, array, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// We override the gost range to span only after last matched letter.
// This way we do not need to apply arguments to matched ranges.
- (NSValue *)fa_overridedGhostRange {
    return objc_getAssociatedObject(self, &overrideGhostKey);
}

- (void)setFa_overridedGhostRange:(NSValue *)value {
    objc_setAssociatedObject(self, &overrideGhostKey, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
