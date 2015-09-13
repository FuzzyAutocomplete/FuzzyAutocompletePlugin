//
//  FATheme.m
//  FuzzyAutocomplete
//
//  Created by Leszek Slazynski on 02/04/2014.
//  Copyright (c) 2014 United Lines of Code. All rights reserved.
//

#import "FATheme.h"
#import "DVTFontAndColorTheme.h"

@interface FATheme ()

- (void) loadPreviewAttributesFromTheme: (DVTFontAndColorTheme *) theme;
- (void) loadListAttributesFromTheme: (DVTFontAndColorTheme *) theme;

@property (nonatomic, retain, readwrite) NSColor * listTextColorForScore;
@property (nonatomic, retain, readwrite) NSColor * listTextColorForSelectedScore;
@property (nonatomic, retain, readwrite) NSDictionary * listTextAttributesForMatchedRanges;
@property (nonatomic, retain, readwrite) NSDictionary * listTextAttributesForSecondPassMatchedRanges;
@property (nonatomic, retain, readwrite) NSDictionary * previewTextAttributesForNotMatchedRanges;

@end

@implementation FATheme

+ (instancetype) cuurrentTheme {
    static FATheme * theme = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        theme = [FATheme new];
        [theme loadFromTheme: [DVTFontAndColorTheme currentTheme]];
    });
    return theme;
}

- (instancetype) init {
    if ((self = [super init])) {
        DVTFontAndColorTheme * theme = [DVTFontAndColorTheme currentTheme];
        [self loadFromTheme: theme];
    }
    return self;
}

- (void)loadFromTheme:(DVTFontAndColorTheme *)theme {
    [self loadPreviewAttributesFromTheme: theme];
    [self loadListAttributesFromTheme: theme];
}

- (void) loadPreviewAttributesFromTheme: (DVTFontAndColorTheme *) theme {
    self.previewTextAttributesForNotMatchedRanges = @{
        NSForegroundColorAttributeName  : theme.sourceTextCompletionPreviewColor ?: [NSColor disabledControlTextColor],
    };
}

- (void) loadListAttributesFromTheme:(DVTFontAndColorTheme *)theme {
    NSColor * color = [NSColor colorWithCalibratedRed:0.886 green:0.777 blue:0.045 alpha:1.000];
    NSColor * altColor = [NSColor colorWithCalibratedRed:0.886 green:0.412 blue:0.045 alpha:1.000];
    self.listTextAttributesForMatchedRanges = @{
        NSUnderlineStyleAttributeName   : @1,
        NSBackgroundColorAttributeName  : [color colorWithAlphaComponent: 0.25],
        NSUnderlineColorAttributeName   : color,
    };

    self.listTextAttributesForSecondPassMatchedRanges = @{
        NSUnderlineStyleAttributeName   : @1,
        NSBackgroundColorAttributeName  : [altColor colorWithAlphaComponent: 0.25],
        NSUnderlineColorAttributeName   : altColor,
    };


    self.listTextColorForScore = [NSColor colorWithCalibratedRed:0.497 green:0.533 blue:0.993 alpha:1.000];
    self.listTextColorForSelectedScore = [NSColor colorWithCalibratedRed:0.838 green:0.850 blue:1.000 alpha:1.000];
}

@end
