//
//  UIController.m
//  taboo
//
//  Created by Paul Borokhov on 8/2/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import "UIController.h"
#import "PageParser.h"
#import "NonanalyticLinkParser.h"
#define UIDEBUG (YES)

@implementation UIController
-(void) awakeFromNib {
    NSArray *stopWords = [@"i,me,my,myself,we,our,ours,ourselves,you,your,yours,yourself,yourselves,he,him,his,himself,she,her,hers,herself,it,its,itself,they,them,their,theirs,themselves,what,which,who,whom,this,that,these,those,am,is,are,was,were,be,been,being,have,has,had,having,do,does,did,doing,would,should,could,ought,i'm,you're,he's,she's,it's,we're,they're,i've,you've,we've,they've,i'd,you'd,he'd,she'd,we'd,they'd,i'll,you'll,he'll,she'll,we'll,they'll,isn't,aren't,wasn't,weren't,hasn't,haven't,hadn't,doesn't,don't,didn't,won't,wouldn't,shan't,shouldn't,can't,cannot,couldn't,mustn't,let's,that's,who's,what's,here's,there's,when's,where's,why's,how's,a,an,the,and,but,if,or,because,as,until,while,of,at,by,for,with,about,against,between,into,through,during,before,after,above,below,to,from,up,down,in,out,on,off,over,under,again,further,then,once,here,there,when,where,why,how,all,any,both,each,few,more,most,other,some,such,no,nor,not,only,own,same,so,than,too,very" componentsSeparatedByString:@","];
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:@"NO", @"shouldSaveLocalResults",@"YES", @"shouldTraverseSeed", @"toolserverURL", @"http://192.168.1.65/~sysadmin/w2x/w2x.php", @"wcMechanism", @"0", @"stopWords", stopWords, @"excludeSimilarTitles", @"YES", @"excludeStopwords", @"YES", @"shouldStem", @"YES", @"useCachedTfidf", @"NO", nil]];
    if (![[NSUserDefaults standardUserDefaults] arrayForKey:@"stopWords"])
        [[NSUserDefaults standardUserDefaults] setObject:stopWords forKey:@"stopWords"];
    linkParsers = [[NSMutableDictionary dictionaryWithCapacity:10] retain];
    cardResults = [[NSMutableDictionary dictionaryWithCapacity:10] retain];
    useCacheForAll = NO;
    didAskForAlert = NO;
}

-(IBAction) fetchInfoFromWeb:(id)sender {
    if (![[webSeed stringValue] isEqualToString:@""]) {
        [self initPathsFromTextfield];
        [loadbar setUsesThreadedAnimation:YES];
        [loadbar setIndeterminate:NO];
        [loadbar setHidden:NO];
        //[loadbar startAnimation:nil];
        [linkParsers removeAllObjects];
        PageParser *calculator = [[[PageParser alloc] initWithLocalDataDir:folderPath withUIController:self] autorelease];
        [NSThread detachNewThreadSelector:@selector(runWordcountAnalysis) toTarget:calculator withObject:nil];
    }
}

-(void) doDotProducts {
    if ([self isSingleArticle]) {
        //NSAutoreleasePool *calc = [[NSAutoreleasePool alloc] init];
        //[calculator runWordcountAnalysis];
        //calculator = nil;
        //[calc release];
        // don't reference calculator again!
        LinkedParser *parser = [[[LinkedParser alloc] initWithTitle:[webSeed stringValue] withLocalDataDir:folderPath withUIController:self] autorelease];
        [linkParsers setObject:parser forKey:[webSeed stringValue]];
        [loadbar setMaxValue:1.0];
        [NSThread detachNewThreadSelector:@selector(getXMLWeb:) toTarget:parser withObject:[NSString stringWithFormat:@"%@:%d", [webSeed stringValue], 2]];
    } else {
        NSLog(@"Not single article, using nonanalyticlinkparser");
        NonanalyticLinkParser *seed = [[[NonanalyticLinkParser alloc] initWithTitle:[webSeed stringValue] withLocalDataDir:folderPath withUIController:self] autorelease];
        /// MMMM love copied code
        [NSThread detachNewThreadSelector:@selector(getXMLWeb:) toTarget:seed withObject:[NSString stringWithFormat:@"%@:%d", [webSeed stringValue], 2]];
        // when that completes, it will call -setSeedPagesSet:
    }    
}

-(BOOL) isSingleArticle {
    if ([[[seedArticleOrCategory titleOfSelectedItem] lowercaseString] isEqualToString:@"seed article"])
        return YES;
    else
        return NO;
}

-(IBAction) showFilePicker:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:NO];
    [panel beginSheetForDirectory:nil file:nil modalForWindow:docWindow modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode  contextInfo:(void  *)contextInfo {
	if (returnCode == NSOKButton) {
		[filePath setStringValue:[[[panel filenames] objectAtIndex:0] stringByAbbreviatingWithTildeInPath]];
        [self initPathsFromTextfield];
	}
}


-(BOOL) initPathsFromTextfield {
    if (![[filePath stringValue] isEqualToString:@""]) {
        folderPath = [[filePath stringValue] retain];
        NSString *seed = [webSeed stringValue]; //[[[[filePath stringValue] lastPathComponent] stringByDeletingPathExtension] retain];
        return folderPath && seed;
    }
    return NO;
}

- (void) alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    [statusLabel setStringValue:@""];
    [[alert window] orderOut:self];
    PageParser *main = [(NSDictionary*)contextInfo objectForKey:@"parser"];
    //NSLog([main cardTitle]);
    if (returnCode == NSAlertDefaultReturn /*&& [self isSingleArticle]*/) {
        // use cached copy
        useCacheForAll = YES;
        [main setWordCounts:[NSMutableDictionary dictionaryWithContentsOfFile:[self wcfilepathForTitle:[main cardTitle]]]];
        [main setDocumentFreqs:[[[Counter alloc] initFromFile:[self idffilepathForTitle:[main cardTitle]] withSingleCountsOnly:YES] autorelease]];
        [NSThread detachNewThreadSelector:@selector(showAnalysis) toTarget:main withObject:nil];
    } else {
        // actually run the analysis
        [NSThread detachNewThreadSelector:@selector(getPageContents) toTarget:main withObject:nil];
    }
    [main release];
}

-(BOOL) cachedCopyExistsForTitle:(NSString*)cardTitle {
    NSString *wcfilepath = [self wcfilepathForTitle:cardTitle];
    NSString *idffilepath = [self idffilepathForTitle:cardTitle];
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"shouldSaveLocalResults"] &&
    [self initPathsFromTextfield] &&
    [[NSFileManager defaultManager] fileExistsAtPath:wcfilepath] &&
    [[NSFileManager defaultManager] fileExistsAtPath:idffilepath];
}

-(void) presentCachedAnalysisAlert:(LinkedParser*)parser {
    BOOL exists = [self cachedCopyExistsForTitle:[parser cardTitle]];
    NSDictionary *contextInfo = [[NSDictionary dictionaryWithObject:parser forKey:@"parser"] retain];
    if (exists) {
        if (!didAskForAlert) {
            didAskForAlert = YES;
            NSAlert *cachedAnalysis = [NSAlert alertWithMessageText:@"A cached analysis has been found" defaultButton:@"Yes" alternateButton:@"No" otherButton:nil informativeTextWithFormat:@"It appears that there already exist word frequency analysis files for your selected seed in the directory you specified. Would you like to use them? If you choose \"No\", a fresh analysis of the page content will be performed."];
            [cachedAnalysis beginSheetModalForWindow:docWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:contextInfo];
            [[cachedAnalysis window] makeKeyAndOrderFront:nil];
            sleep(10);
        } else {
            // have asked for alert already
            if (useCacheForAll) {
                // pretend that we presented the alert
                [self alertDidEnd:nil returnCode:NSAlertDefaultReturn contextInfo:contextInfo];
            } else {
                // UGH how can this branching be redone to eliminate duplicate code?
                // just proceed normally
                if UIDEBUG NSLog(@"Would like to proceed normally");
                [parser performCalculation];            
            }
        }
    }  else {
        // just proceed normally
        if UIDEBUG NSLog(@"Would like to proceed normally");
        [parser performCalculation];            
    }
}

-(NSString *) wcfilepathForTitle:(NSString *)cardTitle {
    return [[folderPath stringByStandardizingPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"plist/%@-wordCounts-%@-%@-%@-%@.plist", cardTitle, [self tfidfstatus], [self stemstatus], [self stopwordStatus], [self abstracts]]];
}

-(NSString *) idffilepathForTitle:(NSString *)cardTitle {
    return [[folderPath stringByStandardizingPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"plist/%@-documentFreqs-%@-%@-%@.plist", cardTitle, [self stemstatus], [self stopwordStatus], [self abstracts]]];
}

-(NSString *) cardDicPath {
    return [[folderPath stringByStandardizingPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"plist/%@-results-%@-%@-%@-%@.plist", [webSeed stringValue], [self tfidfstatus], [self stemstatus], [self stopwordStatus], [self abstracts]]];
}

-(NSString *) tfidfstatus {
    return [[wcMechanism titleOfSelectedItem] isEqualToString:@"tf-idf"] ? @"tf-idf" : @"wc-normal";
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


// faux delegate methods
-(void) linksTidied:(PageParser*)parser {
    if UIDEBUG NSLog(@"%@ Links tidied!", [parser cardTitle]);
}

-(void) beginArticleXMLGet:(PageParser*)parser {
    if UIDEBUG NSLog(@"%@ begin xml get!", [parser cardTitle]);
}

-(void) beginGettingOnehopLinks:(PageParser*)parser {
    
}

-(void) aboutToGetPages:(PageParser*)parser {
    if UIDEBUG NSLog(@"%@ about to get pages!", [parser cardTitle]);
}

-(void) beginGettingPageContents:(PageParser*)parser {
    if UIDEBUG NSLog(@"%@ getting page contents", [parser cardTitle]);
}

-(void) setTotalSubpageCount:(PageParser*)parser number:(int)num {
    if UIDEBUG NSLog(@"%@ total of %d subpages", [parser cardTitle], num);
}

-(void) beginGettingSubpageContents:(PageParser*)parser forTitle:(NSString*)title {
    if UIDEBUG NSLog(@"%@ getting subpage %@!", [parser cardTitle], title);
}

-(void) beginAnalyzingCounts:(PageParser*)parser {
    if UIDEBUG NSLog(@"%@ analyzing counts!", [parser cardTitle]);
}

-(void) setTotalAnalysisSubpageCount:(PageParser*)parser count:(int)count {
    if ([self isSingleArticle]) {
        [loadbar setDoubleValue:0];
        [loadbar setMaxValue:count];
    }
    
    if UIDEBUG NSLog(@"%@ total %d pages to analyze!", [parser cardTitle], count);
}

-(void) beginAnalyzingSubpage:(PageParser*)parser withTitle:(NSString*)title {
    if ([self isSingleArticle]) [loadbar incrementBy:0.99];
    if UIDEBUG NSLog(@"%@ analyzing %@", [parser cardTitle], title);
}

-(void) beginRollingupCounters:(PageParser*)parser {
    if UIDEBUG NSLog(@"%@ rolling up counters", [parser cardTitle]);
}

-(void) beginCalculatingNormalizedCounts:(PageParser*)parser {
    NSLog(@"%@ normalizing counts", [parser cardTitle]);
}

-(void) analysisDidFinish:(PageParser*)parser {
    NSLog(@"Analysis finished!");
    if ([[parser cardTitle] isEqualToString:@"Full analysis"]) [self doDotProducts];
}

-(void) beginVectorDotProducts:(PageParser*)parser {
    if UIDEBUG NSLog(@"%@ doing vector dot prod!", [parser cardTitle]);
}

-(void) didFinishEverything:(PageParser*)parser {
    if UIDEBUG NSLog(@"%@ Dot vector complete!", [parser cardTitle]);
    [loadbar incrementBy:0.99];
    [linkParsers removeObjectForKey:[parser cardTitle]];
    
    if ([linkParsers count] == 0) [cardResults writeToFile:[self cardDicPath] atomically:NO];
}

-(void) setSeedPagesSet:(NSSet*)pages {
    int numOfPagesToAnalyze = 0;
    [loadbar setDoubleValue:0];
    [loadbar setMaxValue:[pages count]];
    for (NSString *page in pages) {
        numOfPagesToAnalyze++;
        PageParser *parser = [[[PageParser alloc] initWithTitle:page withLocalDataDir:folderPath withUIController:self] autorelease];
        [linkParsers setObject:parser forKey:page];
        sleep(1);
        [NSThread detachNewThreadSelector:@selector(getXMLWeb:) toTarget:parser withObject:[NSString stringWithFormat:@"%@:%d", page, 2]];
        //[parser getXMLWeb:[NSString stringWithFormat:@"%@:%d", page, 2]];
    }
    if UIDEBUG NSLog(@"Parsed %d links...", numOfPagesToAnalyze);
}

-(void) saveDotProduct:(NSArray*)articles forCard:(PageParser*)parser {
    @synchronized(self) {
        [cardResults setObject:articles forKey:[parser cardTitle]];
    }
    if ([self isSingleArticle]) {
        [[canvas textStorage] setAttributedString:[[[NSAttributedString alloc] initWithString:[cardResults description]] autorelease]];
    }
}

@end
