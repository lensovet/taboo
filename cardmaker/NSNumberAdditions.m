//
//  NSNumberAdditions.m
//  taboo
//
//  Created by Paul Borokhov on 7/30/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import "NSNumberAdditions.h"


@implementation NSNumber (NSNumberAdditions)

- (NSComparisonResult)compareInReverse:(NSNumber *)aNumber {
    NSComparisonResult result = [self compare:aNumber];
    
    if (result == NSOrderedAscending)
        return NSOrderedDescending;
    else if (result == NSOrderedDescending)
        return NSOrderedAscending;
    else
        return NSOrderedSame;
}

@end
