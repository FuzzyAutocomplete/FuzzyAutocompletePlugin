//
//  NSBundle+LSLProperties.h
//  FuzzyAutocomplete
//
//  Created by Leszek Slazynski on 11/04/2014.
//
//

#import <Foundation/Foundation.h>

@interface NSBundle (LSLProperties)
@property (nonatomic, readonly) NSString *lsl_bundleName, *lsl_bundleVersion, *lsl_bundleNameWithVersion;
@end
