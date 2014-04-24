//
//  DVTTextCompletionInlinePreviewController+FuzzyAutocomplete.h
//  FuzzyAutocomplete
//
//  Created by Leszek Slazynski on 03/02/2014.
//  Copyright (c) 2014 United Lines of Code. All rights reserved.
//

#import "DVTTextCompletionInlinePreviewController.h"

@interface DVTTextCompletionInlinePreviewController (FuzzyAutocomplete)

/// Swizzles methods to enable/disable the plugin
+ (void) fa_swizzleMethods;

/// Matched ranges mapped to preview space.
@property (nonatomic, retain) NSArray * fa_matchedRanges;

@end
