//
//  NSBundle+LSLProperties.m
//  FuzzyAutocomplete
//
//  Created by Leszek Slazynski on 11/04/2014.
//
//

#import "NSBundle+LSLProperties.h"

@implementation NSBundle (LSLProperties)

- (NSString *) lsl_bundleName {
    return [self objectForInfoDictionaryKey: (NSString *) kCFBundleNameKey];
}

- (NSString *) lsl_bundleVersion {
    return [self objectForInfoDictionaryKey: (NSString *) kCFBundleVersionKey];
}

- (NSString *) lsl_bundleNameWithVersion {
    return [NSString stringWithFormat: @"%@ %@", self.lsl_bundleName, self.lsl_bundleVersion];
}

@end
