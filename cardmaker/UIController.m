//
//  UIController.m
//  cardmaker
//
//  Created by Paul Borokhov on 10/9/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import "UIController.h"
#import "NSNumberAdditions.h"
#define DEBUG (NO)

@implementation UIController

-(void) linkParsingComplete {
    [self performCalculation];
}

- (IBAction)showBrowsePanel:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:NO];
    [panel beginSheetForDirectory:nil file:nil modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode  contextInfo:(void  *)contextInfo {
	if (returnCode == NSOKButton) {
		[dataFolder setStringValue:[[[panel filenames] objectAtIndex:0] stringByAbbreviatingWithTildeInPath]];
        [self initPathsFromTextfield];
	}
}

-(BOOL) initPathsFromTextfield {
    if (![[dataFolder stringValue] isEqualToString:@""]) {
        folderPath = [[dataFolder stringValue] retain];
        return folderPath != nil;
    }
    return NO;
}

-(NSArray*) linksForArticle:(NSString*) title {
    NSString *url = [[NSString stringWithFormat:@"http://en.wikipedia.org/w/api.php?action=query&prop=links&titles=%@&pllimit=500&plnamespace=0&format=xml&redirects", title]stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL *theURL = [NSURL URLWithString:url];
    NSData *raw = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:theURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:5.0] returningResponse:nil error:nil];
    if (!raw) return nil;
    NSXMLDocument *doc = [[[NSXMLDocument alloc] initWithData:raw options:0 error:nil] autorelease];
    if (!doc) return nil;
    NSArray *links = [doc objectsForXQuery:@".//pl/@title" error:nil];
    return links;
}

-(IBAction) generateCard:(id)sender {
    [progressBar setUsesThreadedAnimation:YES];
    [NSThread detachNewThreadSelector:@selector(doWork) toTarget:self withObject:nil];
}

-(void) doWork {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    //documentFreqs = [[Counter blankCounterWithStrings] retain];
    //visitedPages = [[NSMutableDictionary dictionaryWithCapacity:100] retain];
    seed = [articleName stringValue];
    NSArray *links = [self linksForArticle:seed];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"batchMode"]) {
        NSMutableDictionary *allresults = [NSMutableDictionary dictionaryWithCapacity:[links count]*50];
        // 1. for each article grab its links
        [progressBar setMaxValue:[links count]];
        [progressBar setDoubleValue:0];
        for (NSXMLNode *article in links) {
            NSAutoreleasePool *minipool = [[NSAutoreleasePool alloc] init];
            [progressBar incrementBy:0.99];
            outlinks = [[NSMutableSet alloc] init];
            NSArray *deeplinks = [self linksForArticle:[article stringValue]];
            for (NSXMLNode *link in deeplinks) {
                [outlinks addObject:[link stringValue]];
            }
            [outlinks addObject:[article stringValue]];
            seed = [article stringValue];
            // 2. generate the results and add them to our dictionary
            NSArray *topkeys = (NSArray*) [self performCalculation];
            [allresults setObject:topkeys forKey:[article stringValue]];
            [topkeys release];
            [minipool release];
        }
        // 3. write dictionary to disk
        [allresults writeToFile:[self cardresultfilepath:[articleName stringValue]] atomically:NO];
        [progressBar setMaxValue:1.0];
        [progressBar setDoubleValue:1.0];
    } else {
        outlinks = [[NSMutableSet alloc] init];
        for (NSXMLNode *article in links) {
            [outlinks addObject:[article stringValue]];
        }
        [outlinks addObject:seed];
        NSLog(@"%@", [outlinks description]);
        [self performCalculation];
        [pool release];
    }
}

-(id) performCalculation {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSLog(@"Begin tf-idf load...");
    pageCounters = [[NSMutableDictionary dictionaryWithCapacity:[outlinks count]] retain];
    //[uiController beginGettingPageContents:self]; // [stageLabel setStringValue:@"Getting page contents..."];
    [progressBar setMaxValue:[outlinks count]];
    
    for (NSString *page in outlinks) {
        //[progressBar incrementBy:0.99];
        NSAutoreleasePool *looper = [[NSAutoreleasePool alloc] init];
        //[uiController beginGettingSubpageContents:self forTitle:page];
        
        // get our counts
        Counter *counter = [[[Counter alloc] initFromFile:[self idffilepathForTitle:page] withSingleCountsOnly:YES] autorelease];
        if (counter) [pageCounters setObject:counter forKey:page];
        
        [looper release];
    }
    
    //[progressBar setIndeterminate:YES];
    //[progressBar startAnimation:self];
    //[uiController analysisDidFinish:self];
    NSLog(@"...load complete");
    [pool release];
    return [self showAnalysis];
}

-(id) showAnalysis {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    //[uiController beginVectorDotProducts:self]; //[stageLabel setStringValue:@"Calculating article word vector dot products..."];
    Counter *seedDoc = [[pageCounters objectForKey:seed] retain];
    [pageCounters removeObjectForKey:seed];
    NSLog(@"Begin dot products...");
    NSArray *seedComps = [[[seed lowercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@" "] componentsSeparatedByString:@" "];
    NSMutableArray *topkeys = [NSMutableArray arrayWithCapacity:5];
    for (char i = 0; i<5; i++) {
        NSAutoreleasePool *pooler = [[NSAutoreleasePool alloc] init];
        // 1. find highest scoring vector
        tuple newtop = [self getTopScoringArticle:[seedDoc immutableBackingstoreCopy] ignoredWords:seedComps];
        //NSLog(@"%@ w/val %f", newtop.name, newtop.dotprod);
        // 1a. add it to our list of related cards
        [topkeys addObject:[newtop.name autorelease]];
        // 2. get the projection of link vector against the card vector
        // proj = (newtop.dotprod/(newtop.name DP newtop.name))*seedDoc
        double denominator = [[pageCounters objectForKey:newtop.name] vectorDotProductWith:[[pageCounters objectForKey:newtop.name] immutableBackingstoreCopy]];
        //NSLog(@"Got denominator of %f and numerator %f for scalar multiplier of %f", denominator, newtop.dotprod, newtop.dotprod/denominator);
        NSDictionary *projection = [[pageCounters objectForKey:newtop.name] multpliedByScalar:newtop.dotprod/denominator];
        // 3. subtract this projection from the current card vector and set it as its word vector for future calcs
        [seedDoc differenceVectorWith:projection];
        // 1b. remove the chosen link from list of potential ones
        //[pageCounters removeObjectForKey:newtop.name];
        [pooler release];
    }
    NSLog(@"...dot prod complete");
    /*if ([[dotProducts allKeys] count] > 6) {
        ///////
        // TODO: remove titles that have the same words in them, i.e. divergent selection and sexual selection, and just pick the top one.
        //////
        topkeys = [[[dotProducts keysSortedByValueUsingSelector:@selector(compareInReverse:)] objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,5)]] retain];
        /*for (NSString *key in topkeys) {
            NSLog(@"Key %@, val %@", key, [[dotProducts objectForKey:key] stringValue]);
        }*//*
        [self saveDotProduct:topkeys];
    }*/
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"batchMode"]) [[canvas textStorage] setAttributedString:[[[NSAttributedString alloc] initWithString:[topkeys description]] autorelease]];
    [progressBar stopAnimation:self];
    NSLog(@"Card gen complete");
    [self freeStorage];
    //[uiController didFinishEverything:self]; //[stageLabel setStringValue:@"Done!"];
    [seedDoc release];
    [pool release];
    return topkeys;
}

-(tuple)getTopScoringArticle:(NSDictionary*)mainCard ignoredWords:(NSArray*)ignoredArray {
    NSString *top = [@"" retain];
    double value = 0;
    //NSLog(@"%@", [mainCard description]);
    for (NSString *doc in pageCounters) {
        //NSLog(@"Considering article %@...", doc);
        if ([[doc lowercaseString] rangeOfString:[seed lowercaseString]].location == NSNotFound) {
            BOOL shouldMultiply = YES;
            for (NSString *comp in ignoredArray) {
                if ([[doc lowercaseString] rangeOfString:comp].location != NSNotFound) {
                    shouldMultiply = NO;
                    break;
                }
            }
            if (shouldMultiply) {
                double newval = [[pageCounters objectForKey:doc] vectorDotProductWith:mainCard];
                //NSLog(@"got val %f", newval);
                if (newval > value) {
                    [top release];
                    top = [doc retain];
                    value = newval;
                }
            } //else NSLog(@"...skipping");
        }
    }
    tuple retval;
    retval.name = top;
    retval.dotprod = value;
    return retval;
}

-(NSString*)cardTitle {
    return [seed retain];
}

-(void) freeStorage {
    [outlinks removeAllObjects];
    [pageCounters removeAllObjects];
    [outlinks release];
    [pageCounters release];
}

-(void) dealloc {
    [self freeStorage];
    [super dealloc];
}    

-(NSString *) idffilepathForTitle:(NSString *)cardTitle {
    return [[folderPath stringByStandardizingPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"plist/%@-documentFreqs-%@-%@-%@.plist", cardTitle, [self stemstatus], [self stopwordStatus], [self abstracts]]];
}

-(NSString *) stemstatus {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"shouldStem"] ? @"stemmed" : @"notstemmed";
}

-(NSString *) stopwordStatus {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"excludeStopwords"] ? @"noSW" : @"withSW";
}

-(NSString *) abstracts {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"abstractsOnly"] ? @"abstracts" : @"fulltext";
}

-(NSString *) cardresultfilepath:(NSString*) cardTitle {
    return [[folderPath stringByStandardizingPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"cards/%@-%@-%@-%@.plist", cardTitle, [self stemstatus], [self stopwordStatus], [self abstracts]]];
}

-(void) saveDotProduct:(NSArray*)articles {
    [articles writeToFile:[self cardresultfilepath:seed] atomically:NO];
}

@end
