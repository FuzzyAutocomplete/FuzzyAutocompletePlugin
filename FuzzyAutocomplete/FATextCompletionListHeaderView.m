//
//  FATextCompletionListHeaderView.m
//  FuzzyAutocomplete
//
//  Created by Leszek Slazynski on 08/04/2014.
//  Copyright (c) 2014 United Lines of Code. All rights reserved.
//

#import "FATextCompletionListHeaderView.h"
#import "DVTTextCompletionSession+FuzzyAutocomplete.h"
#import "DVTFontAndColorTheme.h"
#import "FASettings.h"

@implementation FATextCompletionListHeaderView {
    NSBox * _divider;
    NSTextField * _label;
    NSFont * _boldFont;
    BOOL _showCount;
    BOOL _showFilteredCount;
    BOOL _showTiming;
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _label = [[NSTextField alloc] initWithFrame: NSInsetRect(self.bounds, 5, 0)];
        _label.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        _label.selectable = NO;
        _label.editable = NO;
        _label.drawsBackground = NO;
        _label.bordered = NO;
        _label.bezeled = NO;
        _label.textColor = [NSColor disabledControlTextColor];
        DVTFontAndColorTheme * theme = [DVTFontAndColorTheme currentTheme];
        _label.font = theme.sourcePlainTextFont;
        _boldFont = [[NSFontManager sharedFontManager] convertFont: _label.font toHaveTrait: NSFontBoldTrait];
        [self addSubview: _label];
        _divider = [[NSBox alloc] initWithFrame: NSMakeRect(0, frame.size.height-0.5, frame.size.width, 1)];
        _divider.boxType = NSBoxCustom;
        _divider.borderType = NSLineBorder;
        _divider.borderColor = [[NSColor controlShadowColor] colorWithAlphaComponent: 0.1];
        _divider.borderWidth = 0.5;
        _divider.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
        [self addSubview: _divider];
        _showCount = [FASettings currentSettings].showNumMatches;
        _showFilteredCount = _showCount && [FASettings currentSettings].filterByScore;
        _showTiming = [FASettings currentSettings].showTiming;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent {
    return NO;
}

- (void)mouseDown:(NSEvent *)theEvent {

}

- (void)mouseUp:(NSEvent *)theEvent {

}

- (void)onColumnsResized:(NSNotification *) notification {
    NSInteger titleColumn = [self.tableView columnWithIdentifier: @"title"];
    if (titleColumn != -1) {
        NSRect labelFrame = [self.tableView rectOfColumn: titleColumn];
        labelFrame.origin.x += 1;
        labelFrame.origin.y = 0;
        labelFrame.size.height = self.bounds.size.height;
        labelFrame.size.width = self.bounds.size.width - labelFrame.origin.x;
        [_label setFrame: labelFrame];
    } else {
        RLog(@"Could not find title column.");
    }
}

-(void)setTableView:(NSTableView *)tableView {
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: NSTableViewColumnDidResizeNotification
                                                  object: self.tableView];
    [super setTableView: tableView];
    if (!tableView) {
        return;
    }
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(onColumnsResized:)
                                                 name: NSTableViewColumnDidResizeNotification
                                               object: tableView];
}

- (void)updateWithDataFromSession:(DVTTextCompletionSession *)session {
    NSString * status;

    NSString * prefix = session.fa_filteringQuery;
    unsigned long shownMatches = session.filteredCompletionsAlpha.count;
    unsigned long allMatches = MAX(session.fa_nonZeroScores, shownMatches);

    if (_showFilteredCount && shownMatches != allMatches) {
        status = [NSString stringWithFormat: @"%@ - %ld match%s (%ld shown)", prefix, allMatches, allMatches == 1 ? "" : "es", shownMatches];
    } else if (_showCount) {
        status = [NSString stringWithFormat: @"%@ - %ld match%s", prefix, shownMatches, shownMatches == 1 ? "" : "es"];
    } else {
        status = prefix;
    }
    if (_showTiming) {
        status = [status stringByAppendingFormat: @" - %.2f ms", 1000 * session.fa_lastFilteringTime];
    }

    NSMutableAttributedString * attributed = [[NSMutableAttributedString alloc] initWithString: status];
    [attributed addAttribute: NSFontAttributeName value: _boldFont range: NSMakeRange(0, session.fa_filteringQuery.length)];
    [attributed addAttribute: NSForegroundColorAttributeName value: [NSColor controlTextColor] range: NSMakeRange(0, session.fa_filteringQuery.length)];

    [_label setAttributedStringValue: attributed];
}

static inline void drawRectHelper(NSView * view, NSRect dirtyRect) {
    CGFloat radius;
    @try {
        radius = [[view.window valueForKey: @"cornerRadius"] doubleValue];
    } @catch (NSException * e) {
        radius = 8.0;
    }
    NSRect rect = [view.window.contentView convertRect: [view.window.contentView bounds] toView: view];

    [[NSColor controlBackgroundColor] setFill];
    NSRectFill(dirtyRect);
    
    NSBezierPath * path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius];

    NSBezierPath *clipPath = [NSBezierPath bezierPathWithRect:CGRectInfinite];
    [clipPath appendBezierPath: path];
    clipPath.windingRule = NSEvenOddWindingRule;
    [clipPath addClip];

    [[NSColor clearColor] set];
    NSRectFill(dirtyRect);
}

- (void)drawRect:(NSRect)dirtyRect {
    drawRectHelper(self, dirtyRect);
}

@end

@implementation FATextCompletionListCornerView

- (void)drawRect:(NSRect)dirtyRect {
    drawRectHelper(self, dirtyRect);
}


@end
