//
//  NSNumberAdditions.h
//  taboo
//
//  Created by Paul Borokhov on 7/30/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSNumber (NSNumberAdditions)

- (NSComparisonResult)compareInReverse:(NSNumber *)aNumber;

@end
