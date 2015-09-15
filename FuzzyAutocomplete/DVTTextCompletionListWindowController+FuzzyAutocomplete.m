//
//  DVTTextCompletionListWindowController+FuzzyAutocomplete.m
//  FuzzyAutocomplete
//
//  Created by Leszek Slazynski on 01/02/2014.
//  Copyright (c) 2014 United Lines of Code. All rights reserved.
//

#import "DVTTextCompletionListWindowController+FuzzyAutocomplete.h"
#import "DVTTextCompletionItem-Protocol.h"
#import "DVTTextCompletionSession.h"
#import "DVTTextCompletionSession+FuzzyAutocomplete.h"
#import "FATheme.h"
#import "JRSwizzle.h"
#import "FASettings.h"
#import "FATextCompletionListHeaderView.h"
#import "DVTFontAndColorTheme.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

@implementation DVTTextCompletionListWindowController (FuzzyAutocomplete)

+ (void) fa_swizzleMethods {
    [self jr_swizzleMethod: @selector(tableView:willDisplayCell:forTableColumn:row:)
                withMethod: @selector(_fa_tableView:willDisplayCell:forTableColumn:row:)
                     error: NULL];

    [self jr_swizzleMethod: @selector(tableView:objectValueForTableColumn:row:)
                withMethod: @selector(_fa_tableView:valueForColumn:row:)
                     error: NULL];

    [self jr_swizzleMethod: @selector(_getTitleColumnWidth:typeColumnWidth:)
                withMethod: @selector(_fa_getTitleColumnWidth:typeColumnWidth:)
                     error: NULL];

    [self jr_swizzleMethod: @selector(windowDidLoad)
                withMethod: @selector(_fa_windowDidLoad)
                     error: NULL];

    [self jr_swizzleMethod: @selector(_updateCurrentDisplayState)
                withMethod: @selector(_fa_updateCurrentDisplayState)
                     error: NULL];

    [self jr_swizzleMethod: @selector(_updateCurrentDisplayStateForQuickHelp)
                withMethod: @selector(_fa_updateCurrentDisplayStateForQuickHelp)
                     error: NULL];

    [self jr_swizzleMethod: @selector(_preferredWindowFrameForTextFrame:columnsWidth:titleColumnX:)
                withMethod: @selector(_fa_preferredWindowFrameForTextFrame:columnsWidth:titleColumnX:)
                     error: nil];
}

#pragma mark - overrides

const char kRowHeightKey;

// We (optionally) add a score column and a header.
- (void) _fa_windowDidLoad {
    [self _fa_windowDidLoad];

    NSTableView * tableView = [self valueForKey: @"_completionsTableView"];

    if ([FASettings currentSettings].showListHeader) {
        tableView.headerView = [[FATextCompletionListHeaderView alloc] initWithFrame: NSMakeRect(0, 0, 100, 22)];
        tableView.cornerView = [[FATextCompletionListCornerView alloc] initWithFrame: NSMakeRect(0, 0, 22, 22)];
    }

    NSTableColumn * scoreColumn = [tableView tableColumnWithIdentifier: @"score"];
    if ([FASettings currentSettings].showScores) {
        if (!scoreColumn) {
            scoreColumn = [[NSTableColumn alloc] initWithIdentifier: @"score"];
            [tableView addTableColumn: scoreColumn];
            [tableView moveColumn: [tableView columnWithIdentifier: @"score"] toColumn: [tableView columnWithIdentifier: @"type"]];
            NSTextFieldCell * cell = [[tableView tableColumnWithIdentifier: @"title"].dataCell copy];
            NSNumberFormatter * formatter = [[NSNumberFormatter alloc] init];
            formatter.format = [FASettings currentSettings].scoreFormat;
            cell.formatter = formatter;
            cell.title = @"";
            DVTFontAndColorTheme * theme = [DVTFontAndColorTheme currentTheme];
            cell.font = theme.sourcePlainTextFont;
            [scoreColumn setDataCell: cell];
        }
    } else if (scoreColumn) {
        [tableView removeTableColumn: scoreColumn];
    }
}

// We add a value for the new score column.
- (id) _fa_tableView: (NSTableView *) aTableView
      valueForColumn: (NSTableColumn *) aTableColumn
                 row: (NSInteger) rowIndex
{
    if ([aTableColumn.identifier isEqualToString:@"score"]) {
        id<DVTTextCompletionItem> item = self.session.filteredCompletionsAlpha[rowIndex];
        return [self.session fa_scoreForItem: item];
    } else {
        return [self _fa_tableView:aTableView valueForColumn:aTableColumn row:rowIndex];
    }
}

// We override this so we can mock tableView.rowHeight without affecting the display.
- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    NSNumber * obj = objc_getAssociatedObject(self, &kRowHeightKey);
    if (!obj) {
        obj = @(tableView.rowHeight);
        objc_setAssociatedObject(self, &kRowHeightKey, obj, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        tableView.headerView.frame = NSMakeRect(0, 0, 100, tableView.rowHeight + tableView.intercellSpacing.height);

    }
    return [obj doubleValue];
}

// We modify the height to fit the header.
- (void) _fa_updateCurrentDisplayStateForQuickHelp {
    [self _fa_hackModifyRowHeight];
    [self _fa_updateCurrentDisplayStateForQuickHelp];
    [self _fa_hackRestoreRowHeight];
}

// We modify the width of the score column and height to accomodate the header.
- (void) _fa_updateCurrentDisplayState {
    NSTableView * tableView = [self valueForKey: @"_completionsTableView"];

    // show or hide score column depending on wether we have scores (width has to be negative to hide it completely)
    NSTableColumn * scoreColumn = [tableView tableColumnWithIdentifier: @"score"];
    if (scoreColumn) {
        scoreColumn.minWidth = self.session.fa_nonZeroScores ? [self _fa_widthForScoreColumn] : -tableView.intercellSpacing.width;
        scoreColumn.maxWidth = scoreColumn.width = scoreColumn.minWidth;
    }

    // update the header text
    FATextCompletionListHeaderView * header = (FATextCompletionListHeaderView *) tableView.headerView;
    [header updateWithDataFromSession: self.session];

    [self _fa_hackModifyRowHeight];
    [self _fa_updateCurrentDisplayState];
    [self _fa_hackRestoreRowHeight];

    // fix the tableView width when showing the window for the second time
    if ([FASettings currentSettings].showScores) {
        [tableView sizeLastColumnToFit];
    }
}

// We modify titleColumnX with score column's width, so that title column is aligned with typed text
- (CGRect) _fa_preferredWindowFrameForTextFrame: (CGRect) textFrame columnsWidth: (double *) widths titleColumnX: (double) titleX {
    NSTableView * tableView = [self valueForKey: @"_completionsTableView"];
    NSTableColumn * scoreColumn = [tableView tableColumnWithIdentifier: @"score"];
    CGFloat additionalWidth = scoreColumn ? [self _fa_widthForScoreColumn] + tableView.intercellSpacing.width : 0;
    return [self _fa_preferredWindowFrameForTextFrame: textFrame columnsWidth: widths titleColumnX: titleX + additionalWidth];
}

// We add visual feedback for the matched ranges. Also format the score column.
- (void) _fa_tableView: (NSTableView *) aTableView
       willDisplayCell: (NSCell *) aCell
        forTableColumn: (NSTableColumn *) aTableColumn
                   row: (NSInteger) rowIndex
{
    [self _fa_tableView:aTableView willDisplayCell:aCell forTableColumn:aTableColumn row:rowIndex];

    if ([aTableColumn.identifier isEqualToString:@"score"]) {
        NSTextFieldCell * textFieldCell = (NSTextFieldCell *) aCell;
        textFieldCell.textColor = textFieldCell.isHighlighted ? [FATheme cuurrentTheme].listTextColorForSelectedScore : [FATheme cuurrentTheme].listTextColorForScore;
    } else if ([aTableColumn.identifier isEqualToString:@"title"]) {
        if (rowIndex >= self.session.filteredCompletionsAlpha.count) {
            RLog(@"Warning: Row out of bounds, skipping.");
            return;
        }
    
        id<DVTTextCompletionItem> item = self.session.filteredCompletionsAlpha[rowIndex];
        if (![item.displayText isEqualToString: aCell.stringValue]) {
            RLog(@"Warning: Item displayText different from cell stringValue, skipping.");
            return;
        }

        NSArray * ranges = [self.session fa_matchedRangesForItem: item];
        if (!ranges.count) {
            RLog("Warning: No ranges matched for item, skipping");
            return;
        }

        NSArray * second = [self.session fa_secondPassMatchedRangesForItem: item];

        NSMutableAttributedString * attributed = [aCell.attributedStringValue mutableCopy];

        ranges = [self.session fa_convertRanges: ranges
                                     fromString: item.name
                                       toString: item.displayText
                                      addOffset: 0];

        second = [self.session fa_convertRanges: second
                                     fromString: item.name
                                       toString: item.displayText
                                      addOffset: 0];

        NSDictionary * attributes = [FATheme cuurrentTheme].listTextAttributesForMatchedRanges;
        NSDictionary * altAttributes = [FATheme cuurrentTheme].listTextAttributesForSecondPassMatchedRanges;

        for (NSValue * val in ranges) {
            [attributed addAttributes: attributes range: [val rangeValue]];
        }
        for (NSValue * val in second) {
            [attributed addAttributes: altAttributes range: [val rangeValue]];
        }


        NSString * prefix = self.session.usefulPrefix;
        if (prefix && [item.name hasPrefix: prefix] && ![item.displayText hasPrefix: prefix]) {
            NSRange prefixRange = NSMakeRange(0, prefix.length);
            NSArray * prefixRanges = [self.session fa_convertRanges: @[ [NSValue valueWithRange: prefixRange] ]
                                                         fromString: item.name
                                                           toString: item.displayText
                                                          addOffset: 0];
            prefixRange = NSMakeRange(0, 0);
            for (NSValue * val in prefixRanges) {
                prefixRange = NSUnionRange(prefixRange, [val rangeValue]);
            }
            [attributed addAttributes: self._usefulPrefixAttributes range: prefixRange];
        }

        [aCell setAttributedStringValue: attributed];
    }

}

// we add to titleWidth to acomodate for additional column (last column is sized to fit).
- (void) _fa_getTitleColumnWidth:(double *)titleWidth typeColumnWidth:(double *)typeWidth {
    [self _fa_getTitleColumnWidth:titleWidth typeColumnWidth:typeWidth];
    if ([FASettings currentSettings].showScores) {
        NSTableView * tableView = [self valueForKey: @"_completionsTableView"];
        *titleWidth += [self _fa_widthForScoreColumn] + tableView.intercellSpacing.width;
    }
}

#pragma mark - helpers

// get width required for score column with current format and font
- (CGFloat) _fa_widthForScoreColumn {
    NSTableView * tableView = [self valueForKey: @"_completionsTableView"];
    NSTableColumn * scoreColumn = [tableView tableColumnWithIdentifier: @"score"];
    DVTFontAndColorTheme * theme = [DVTFontAndColorTheme currentTheme];
    if (scoreColumn && self.session.fa_nonZeroScores && theme.sourcePlainTextFont) {
        NSNumberFormatter * formatter = ((NSCell *)scoreColumn.dataCell).formatter;
        NSString * sampleValue = [formatter stringFromNumber: @0];
        NSDictionary * attributes = @{ NSFontAttributeName : theme.sourcePlainTextFont };
        return [[NSAttributedString alloc] initWithString: sampleValue attributes: attributes].size.width + 6;
    } else {
        return 0;
    }
}

// The _updateCurrentDisplayState and _updateCurrentDisplayStateForQuickHelp change tableView and window frame.
// If we just correct the dimensions after calling the originals, there sometimes is a visible jump in the UI.
// We therefore mock the row height to be larger, so the original methods size the tableView to be bigger.
// TODO: Do this in some cleaner way, maybe even without using a table view header.
- (void) _fa_hackModifyRowHeight {
    NSTableView * tableView = [self valueForKey: @"_completionsTableView"];
    FATextCompletionListHeaderView * header = (FATextCompletionListHeaderView *) tableView.headerView;
    NSInteger rows = MIN(8, [self.session.filteredCompletionsAlpha count]);

    if (header && rows) {
        tableView.rowHeight += (header.frame.size.height + 1) / rows;
    }
}

// Restore the original row height.
- (void) _fa_hackRestoreRowHeight {
    NSTableView * tableView = [self valueForKey: @"_completionsTableView"];
    double rowHeight = [objc_getAssociatedObject(self, &kRowHeightKey) doubleValue];
    if (rowHeight > 0) {
        tableView.rowHeight = rowHeight;
    }
}

@end
