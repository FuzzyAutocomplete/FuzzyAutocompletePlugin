//
//  FATextCompletionListHeaderView.h
//  FuzzyAutocomplete
//
//  Created by Leszek Slazynski on 08/04/2014.
//  Copyright (c) 2014 United Lines of Code. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class DVTTextCompletionSession;

@interface FATextCompletionListHeaderView : NSTableHeaderView

- (void) updateWithDataFromSession: (DVTTextCompletionSession *) session;

@end

@interface FATextCompletionListCornerView : NSView

@end
