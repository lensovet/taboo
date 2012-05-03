//
//  LinkedParser.m
//  taboo
//
//  Created by Paul Borokhov on 9/23/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import "LinkedParser.h"


@implementation LinkedParser

-(LinkedParser *)initWithTitle:(NSString *)cardTitle withLocalDataDir:(NSString *)filePath withUIController:(UIController *)controller {
    if ((self = [super init])) {
        outlinks = [[NSMutableSet alloc] init];
        pageCounters = [[NSMutableDictionary dictionaryWithCapacity:100] retain];
        documentFreqs = [[Counter blankCounterWithStrings] retain];
        visitedPages = [[NSMutableDictionary dictionaryWithCapacity:100] retain];
        seed = [cardTitle retain];
        folderPath = [filePath retain];
        uiController = [controller retain];
    }
    return self;
}

-(NSArray*) findLinksInXML:(NSXMLDocument*)doc {
    [self findLinksInXML:doc addToOutlinksSet:YES];
    return nil;
}

-(NSArray*) findLinksInXML:(NSXMLDocument*)doc addToOutlinksSet:(BOOL)shouldAdd {
    NSError *err = nil;
    NSArray *results = [doc objectsForXQuery:@".//target" error:&err];
    NSMutableArray *titles = [NSMutableArray arrayWithCapacity:[results count]];
    NSLog([err localizedDescription]);
    for (NSXMLNode *resultNode in results) {
        [titles addObject:[resultNode stringValue]];
    }
    
    titles = [self tidyLinks:titles];
    if (shouldAdd) [outlinks addObjectsFromArray:titles];
    
    return [NSArray arrayWithArray:titles];
}

-(NSMutableArray*) tidyLinks:(NSMutableArray*) links {
    for (NSString *link in [NSArray arrayWithArray:links]) {
        //unichar colon = [@":" characterAtIndex:0];
        if (/*[link characterAtIndex:0] == colon || [link characterAtIndex:2] == colon ||*/ [link rangeOfString:@":"].location != NSNotFound) {
            [links removeObject:link];
        } else {
            NSRange range = [link rangeOfString:@"#"];
            if (range.location != NSNotFound) {
                [links removeObject:link];
                [links addObject:[link substringToIndex:range.location]];
            }
            // move along
        }
    }
    
    [uiController linksTidied:self]; //[[canvas textStorage] setAttributedString:[[[NSAttributedString alloc] initWithString:[outlinks description]] autorelease]];
    //[linksLabel setStringValue:[NSString stringWithFormat:@"%@ / %d", [linksLabel stringValue], [outlinks count]]];
    return links;
}

-(void) linkParsingComplete {
    [uiController presentCachedAnalysisAlert:self];
}

-(void) getXMLWeb:(id)options {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSArray *opts = [options componentsSeparatedByString:@":"];
    NSString *articleName = [opts objectAtIndex:0];
    int recursion = [[opts objectAtIndex:1] intValue];
    if ([[visitedPages objectForKey:articleName] boolValue]) {
        [pool release];
        return;
    }
    [uiController beginArticleXMLGet:self]; //[statusLabel setStringValue:[NSString stringWithFormat:@"Getting %@", articleName]];
    
    NSXMLDocument *doc = [self loadArticleWithTitle:articleName withFormat:@"xml" localInitSuccess:[uiController initPathsFromTextfield]];
    if (!doc) {
        [pool release];
        return;
    }
    
    [self findLinksInXML:doc];
    [visitedPages setObject:[NSNumber numberWithBool:YES] forKey:articleName];
    if (recursion != 2) {
    } else {
        [outlinks addObject:articleName];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"shouldTraverseSeed"]) {
            if DEBUG NSLog(@"Getting one-hop links...from %@", [outlinks description]);
            [uiController beginGettingOnehopLinks:self]; // [stageLabel setStringValue:@"Getting one-hop links..."];
            /*for (NSString *link in [NSSet setWithSet:outlinks]) {
             [self getXMLWeb:[NSString stringWithFormat:@"%@:%d", link, recursion-1]];
             }*/
            /*[stageLabel setStringValue:@"Getting two-hop links..."];
             for (NSString *link in [NSSet setWithSet:outlinks]) {
             [self getXMLWeb:[NSString stringWithFormat:@"%@:%d", link, recursion-2]];
             }*/
        }
        [uiController aboutToGetPages:self]; //[stageLabel setStringValue:@"About to get pages..."];
        [self linkParsingComplete];
    }
    [pool release];
    return;
}

-(void) performCalculation {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    pageCounters = [NSMutableDictionary dictionaryWithCapacity:[outlinks count]];
    [uiController beginGettingPageContents:self]; // [stageLabel setStringValue:@"Getting page contents..."];
    [uiController setTotalSubpageCount:self number:[outlinks count]];

    for (NSString *page in outlinks) {
        //[loadbar incrementBy:0.99];
        NSAutoreleasePool *looper = [[NSAutoreleasePool alloc] init];
        [uiController beginGettingSubpageContents:self forTitle:page];
        
        // get our counts
        Counter *counter = [[[Counter alloc] initFromFile:[uiController idffilepathForTitle:page] withSingleCountsOnly:YES] autorelease];
        if (counter) [pageCounters setObject:counter forKey:page];
        
        [looper release];
    }
    
    [uiController beginAnalyzingCounts:self];
    [uiController setTotalAnalysisSubpageCount:self count:[pageCounters count]];
    [uiController analysisDidFinish:self];
    [self showAnalysis];
    [pool release];
}

-(void) showAnalysis {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    //[loadbar startAnimation:nil];
    [uiController beginVectorDotProducts:self]; //[stageLabel setStringValue:@"Calculating article word vector dot products..."];
    
    Counter *seedDoc = [[pageCounters objectForKey:seed] retain];
    //NSLog(@"%@", [seedDoc description]);
    NSDictionary *seedVals = [seedDoc immutableBackingstoreCopy];
    [pageCounters removeObjectForKey:seed];
    NSMutableDictionary *dotProducts = [NSMutableDictionary dictionaryWithCapacity:[pageCounters count]];
    for (NSString *doc in pageCounters) {
        [dotProducts setObject:[NSNumber numberWithDouble:[[pageCounters objectForKey:doc] vectorDotProductWith:seedVals]] forKey:doc];
    }
    if ([[dotProducts allKeys] count] > 20) {
        //NSLog(@"%@", [dotProducts description]);
        NSArray *topkeys = [[dotProducts keysSortedByValueUsingSelector:@selector(compareInReverse:)] objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,5)]];
        [uiController saveDotProduct:topkeys forCard:self];
    }
    //[[canvas textStorage] setAttributedString:[[[NSAttributedString alloc] initWithString:[topkeys description]] autorelease]];
    //[loadbar stopAnimation:nil];
    //[loadbar setHidden:YES];
    [seedDoc release];
    [uiController didFinishEverything:self]; //[stageLabel setStringValue:@"Done!"];
    [pool release];
}

-(NSString*)cardTitle {
    return [seed retain];
}

-(void) dealloc {
    [visitedPages removeAllObjects];
    [outlinks removeAllObjects];
    [pageCounters removeAllObjects];
    [documentFreqs reset];
    [visitedPages release];
    [outlinks release];
    [pageCounters release];
    [documentFreqs release];
    [super dealloc];
}    

@end
