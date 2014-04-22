//
//  DVTTextCompletionListWindowController+FuzzyAutocomplete.h
//  FuzzyAutocomplete
//
//  Created by Leszek Slazynski on 01/02/2014.
//  Copyright (c) 2014 United Lines of Code. All rights reserved.
//

#import "DVTTextCompletionListWindowController.h"

@interface DVTTextCompletionListWindowController (FuzzyAutocomplete)

/// Swizzles methods to enable/disable the plugin
+ (void) fa_swizzleMethods;

@end
