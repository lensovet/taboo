//
//  NonanalyticLinkParser.m
//  taboo
//
//  Created by Paul Borokhov on 8/2/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import "NonanalyticLinkParser.h"


@implementation NonanalyticLinkParser : LinkedParser

-(void) linkParsingComplete {
    NSLog(@"Parsing complete, passing data onto uicontroller!");
    [uiController setSeedPagesSet:[NSSet setWithSet:outlinks]];
}

@end
