//
//  LinkedParser.h
//  taboo
//
//  Created by Paul Borokhov on 9/23/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import "PageParser.h"
@class UIController;

@interface LinkedParser : PageParser {
    @protected
    NSString *seed;
    NSMutableDictionary *visitedPages;
    NSMutableDictionary *unitVectorWordCounts;
    NSMutableSet *outlinks;
    NSMutableDictionary *pageCounters;
    @public
}

-(LinkedParser *)initWithTitle:(NSString *)cardTitle withLocalDataDir:(NSString *)filePath withUIController:(UIController *)controller;

-(void) performCalculation;
-(void) showAnalysis;

-(void) getXMLWeb:(id)options;
-(NSArray*) findLinksInXML:(NSXMLDocument*)doc;
-(NSArray*) findLinksInXML:(NSXMLDocument*)doc addToOutlinksSet:(BOOL)shouldAdd;
-(NSMutableArray*) tidyLinks:(NSMutableArray*) links;
-(void) linkParsingComplete;

@end