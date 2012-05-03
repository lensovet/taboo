//
//  PageParser.m
//  taboo
//
//  Created by Paul Borokhov on 7/11/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import "PageParser.h"
#define TF_IDF 0
#define NORMALIZED 1

@implementation PageParser

-(PageParser *)initWithLocalDataDir:(NSString *)filePath withUIController:(UIController *)controller {
    if ((self = [super init])) {
        wordCounts = [[NSMutableDictionary dictionaryWithCapacity:100] retain];
        documentFreqs = [[Counter blankCounterWithStrings] retain];
        folderPath = [filePath retain];
        uiController = [controller retain];
    }
    return self;
}

-(void)setWordCounts:(NSMutableDictionary*)dic {
    for (NSString *page in dic) {
        [wordCounts setObject:[[[Counter alloc] _initFromDictionary:[dic objectForKey:page] isStringBased:NO] autorelease] forKey:page];
    }
}

-(void)setDocumentFreqs:(Counter*)counter {
    [documentFreqs release];
    documentFreqs = [counter retain];
}

//**** Returns AUTORELEASED objects, need to retain if you want to keep them ******//
-(id) loadArticleWithTitle:(NSString*) title withFormat:(NSString*) format localInitSuccess:(BOOL)localInitSuccess {
    /* ATM, getting these pages in one chunk results in a segfault. Forget about it for now.
     NSMutableSet *outlinkscopy = [[outlinks mutableCopy] autorelease];
     for (NSString *unescapedtitle in [NSSet setWithSet:outlinks]) {
     [outlinkscopy addObject:[unescapedtitle stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
     [outlinkscopy removeObject:unescapedtitle];
     }
     NSString *thepages = [[outlinks allObjects] componentsJoinedByString:[NSString stringWithFormat:@"%C%C", (unichar) 0x0a, (unichar) 0x0d]];
     urlString = [[NSString stringWithFormat:[[[NSUserDefaults standardUserDefaults] stringForKey:@"toolserverURL"] stringByAppendingString:@"?doit=1&whatsthis=articlelist&site=en.wikipedia.org/w&output_format=text&text=%@&use_templates=none&strip_templates=all&add_gfdl=0&keep_categories=0&keep_interlanguage=0&useapi=1"], thepages] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]; //*/
    NSString *contents;
    NSXMLDocument *doc;
    NSString *urlString;
    NSURL *theURL;
    NSString *myfilepath;
    if ([format isEqualToString:@"text"]) {
        urlString = [[NSString stringWithFormat:[[[NSUserDefaults standardUserDefaults] stringForKey:@"toolserverURL"] stringByAppendingString:@"?doit=1&whatsthis=articlelist&site=en.wikipedia.org/w&output_format=text&text=%@&use_templates=none&strip_templates=all&add_gfdl=0&keep_categories=0&keep_interlanguage=0&useapi=1"], title] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        myfilepath = [[folderPath stringByStandardizingPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"txt/%@.txt", title]];
    } else {
        urlString = [[NSString stringWithFormat:[[[NSUserDefaults standardUserDefaults] stringForKey:@"toolserverURL"] stringByAppendingString:@"?doit=1&whatsthis=articlelist&site=en.wikipedia.org/w&output_format=xml&text=%@&use_templates=none&strip_templates=all&add_gfdl=0&keep_categories=0&keep_interlanguage=0&useapi=1"], title] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        myfilepath = [[folderPath stringByStandardizingPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"xml/%@.xml", title]];
    }
    if DEBUG NSLog(@"%@", urlString);
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"shouldSaveLocalResults"] && localInitSuccess
        && [[NSFileManager defaultManager] fileExistsAtPath:myfilepath]) {
        theURL = [NSURL fileURLWithPath:myfilepath];
    } else if (![[NSUserDefaults standardUserDefaults] boolForKey:@"ignoreMissing"]) {
        theURL = [NSURL URLWithString:urlString];
    } else {
        return nil;
    }
    // don't want to wait forever for a response
    NSData *raw = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:theURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:5.0] returningResponse:nil error:nil];
    if (!raw) return nil;
    if ([format isEqualToString:@"text"]) {
        contents = [[[NSString alloc] initWithData:raw encoding:NSUTF8StringEncoding] autorelease];
        if (contents && ![contents isEqualToString:@""]) {
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"shouldSaveLocalResults"] && ![theURL isFileURL])
                [contents writeToFile:myfilepath atomically:NO encoding:NSUTF8StringEncoding error:nil];
        } else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"shouldSaveLocalResults"]) {
            NSLog(@"You want to save local results but have not set a save directory. Try again!");
        }
        return contents;
    } else {
        doc = [[[NSXMLDocument alloc] initWithData:raw options:NSXMLDocumentTidyXML error:nil] autorelease];
        if (doc && ![[doc stringValue] isEqualToString:@""]) {
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"shouldSaveLocalResults"] && ![theURL isFileURL])
                [[doc XMLData] writeToFile:myfilepath atomically:NO];
        } else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"shouldSaveLocalResults"]) {
            NSLog(@"You want to save local results but have not set a save directory. Try again!");
        }
        return doc;
    }
}

-(void) runWordcountAnalysis {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"useCachedTfidf"]) return;
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    //NSMutableDictionary *pageContents = [NSMutableDictionary dictionaryWithCapacity:[outlinks count]];
    [uiController beginGettingPageContents:self]; // [stageLabel setStringValue:@"Getting page contents..."];
    BOOL localInitSuccess = [uiController initPathsFromTextfield];
    // [loadbar setIndeterminate:NO];
    // [loadbar setDoubleValue:0];
    [uiController setTotalSubpageCount:self number:1]; //[outlinks count]];
    // for later - regex to clean out external links in articles
    // double-slashes to make gcc happy
    NSString *externalRegex = @"\\[http[^\\]]+\\]";
    // clean out templates
    NSString *templateRegex = @"\\{[^\\}]+\\}";
    // in a very brittle way, attempt to clean out interwiki links
    // this has the potential of wiping out huge sections of articles. dunno.
    NSString *interwikiRegex = @"\\n\\n[a-z]{2,}:.+$";
    NSString *replacementString = @"";
    
    // regex to pull out abstract
    //NSString *abstractRegex = @"=====^[^=]+^={2,}";
    
    //// pull all files from dir
    
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[folderPath stringByStandardizingPath] stringByAppendingPathComponent:@"txt"] error:NULL];
    
    /*NSString *cardTitle = seed;
    
    for (NSString *page in outlinks) {
        //[loadbar incrementBy:0.99];
        NSAutoreleasePool *looper = [[NSAutoreleasePool alloc] init];
        [uiController beginGettingSubpageContents:self forTitle:page]; //[statusLabel setStringValue:[NSString stringWithFormat:@"Getting %@", page]];
        
        // get text-only page contents
        NSString *contents = [self loadArticleWithTitle:page withFormat:@"text" localInitSuccess:localInitSuccess];
        if (contents) {
            contents = [[[contents stringByReplacingOccurrencesOfRegex:externalRegex withString:replacementString] stringByReplacingOccurrencesOfRegex:templateRegex withString:replacementString] stringByReplacingOccurrencesOfRegex:interwikiRegex withString:replacementString];            
            [pageContents setObject:contents forKey:page];
        }
        
        [looper release];
    }*/

    /**
     For when we figure out how to do batch gets...
     NSArray *pages = [contents componentsSeparatedByString:@"\\n\\n=====\\n\\n"];
    for (NSString *page in pages) {
        if ([page isEqualToString:@""]) {
            NSString *pagename = [page stringByMatching:@"^[A-Z ]+$"];
            [pageContents setObject:page forKey:pagename];
        }
    }
     */
    
    [uiController beginAnalyzingCounts:self]; //[stageLabel setStringValue:@"Analyzing word counts & freqs"];
    // [loadbar setDoubleValue:0];
    [uiController setTotalAnalysisSubpageCount:self count:[files count]]; //[pageContents count]];
    int docsCounted = 0;
    for (NSString *file in files) {
        NSString *page = [[file lastPathComponent] stringByDeletingPathExtension];
        if (!page) continue;
        [uiController beginAnalyzingSubpage:self withTitle:page];
        
        //[loadbar incrementBy:0.99];
        /*if (![[page lowercaseString] isEqualToString:[cardTitle lowercaseString]] && [[NSUserDefaults standardUserDefaults] boolForKey:@"excludeSimilarTitles"] && [[page lowercaseString] rangeOfString:[cardTitle lowercaseString]].location != NSNotFound) {
            continue;
        }*/
        Counter *docWordCount = [Counter blankCounter];
        NSAutoreleasePool *looper = [[NSAutoreleasePool alloc] init];
        NSString *text = [NSString stringWithContentsOfFile:[[folderPath stringByStandardizingPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"txt/%@", file]] encoding:NSUTF8StringEncoding error:NULL];
        if (text) text = [[[text stringByReplacingOccurrencesOfRegex:externalRegex withString:replacementString] stringByReplacingOccurrencesOfRegex:templateRegex withString:replacementString] stringByReplacingOccurrencesOfRegex:interwikiRegex withString:replacementString];
        else continue;
        
        // drop everything beyond the abstract
        //if ([[NSUserDefaults standardUserDefaults] boolForKey:@"abstractsOnly"]) text = [text stringByMatching:<#(*)regex#>];
        
        CFRange range = CFRangeMake(0L, [text length]);
        
        CFStringTokenizerRef tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault, (CFStringRef) text, range, kCFStringTokenizerUnitWord, NULL);
        
        while (CFStringTokenizerAdvanceToNextToken(tokenizer) != kCFStringTokenizerTokenNone) {
            NSAutoreleasePool *tokenpool = [[NSAutoreleasePool alloc] init];
            CFRange tokenRange = CFStringTokenizerGetCurrentTokenRange(tokenizer);
            // only include words without colons and numbers and other junk in them
            NSString *word = [self cleanupWord:[text substringWithRange:NSMakeRange(tokenRange.location, tokenRange.length)]];
            if (word) {
                [docWordCount incrementValueForKey:word];
                [documentFreqs appendValue:page toKey:word];
            }
            [tokenpool release];
        }
        /**NSArray *links = [self findLinksInXML:[self loadArticleWithTitle:page withFormat:@"xml" localInitSuccess:localInitSuccess] addToOutlinksSet:NO];
        for (NSString *link in links) {
            /////********* FIXME: Use link *text* instead of link *target* here! *******///////////
            /*NSString *clean = [self cleanupWord:link];
            if (clean) [docWordCount incrementValueForKey:clean];
        }*/
        CFRelease(tokenizer);
        [looper release];
        [wordCounts setObject:docWordCount forKey:page];
        docsCounted++;
    }
    NSLog(@"analyzed %d docs", docsCounted);
    //[loadbar setIndeterminate:YES];
    //[loadbar startAnimation:nil];
    [uiController beginRollingupCounters:self]; //[stageLabel setStringValue:@"Rolling up document frequency dictionary counter..."];
    //[statusLabel setStringValue:@""];
    [documentFreqs rollupStringCounter];
    //unitVectorWordCounts = [[NSMutableDictionary dictionaryWithCapacity:[wordCounts count]] retain];
    
    [uiController beginCalculatingNormalizedCounts:self]; //[stageLabel setStringValue:@"Calculating tf-idf values..."];
    NSMutableDictionary *idfvals = [NSMutableDictionary dictionaryWithCapacity:[documentFreqs count]];
    NSDictionary *freqs = [documentFreqs immutableBackingstoreCopy];
    for (NSString *word in freqs) {
        double idf = log(docsCounted/(1.0+[[freqs objectForKey:word] doubleValue]));
        [idfvals setObject:[NSNumber numberWithDouble:idf] forKey:word];
    }
    NSLog(@"idf value for \"the\" is %@", [idfvals objectForKey:@"the"]);
    int wcMechanism = [[NSUserDefaults standardUserDefaults] integerForKey:@"wcMechanism"];
    for (NSString *doc in wordCounts) {
        NSAutoreleasePool *looper = [[NSAutoreleasePool alloc] init];
        if (wcMechanism == TF_IDF) {
            [[wordCounts objectForKey:doc] convertToTfIdf:freqs withDocs:idfvals];
        } else { // lol this is kinda bad
            NSLog(@"wcMech is %@", wcMechanism);
            [[wordCounts objectForKey:doc] normalizeVector];
        }
        [looper release];
    }
        
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"shouldSaveLocalResults"] /*&& localInitSuccess*/) {
        NSLog(@"Beginning analysis save...");
        // save our analysis
        /*NSString *wcfilepath = [uiController wcfilepathForTitle:seed];
        NSString *idffilepath = [uiController idffilepathForTitle:seed];
        NSMutableDictionary *tempwc = [NSMutableDictionary dictionaryWithCapacity:[wordCounts count]];
        NSMutableDictionary *topwords = [NSMutableDictionary dictionaryWithCapacity:[wordCounts count]];*/
        for (NSString *doc in wordCounts) {
            NSAutoreleasePool *looper = [[NSAutoreleasePool alloc] init];
            NSDictionary *store = [[wordCounts objectForKey:doc] immutableBackingstoreCopy];
            [store writeToFile:[uiController idffilepathForTitle:doc] atomically:NO];
            if ([[store allKeys] count] > 20) {
                NSArray *topkeys = [[store keysSortedByValueUsingSelector:@selector(compareInReverse:)] objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 20)]];
                [[NSDictionary dictionaryWithObjects:[store objectsForKeys:topkeys notFoundMarker:[NSNull null]] forKeys:topkeys] writeToFile:[[uiController idffilepathForTitle:doc] stringByAppendingString:@"-top.plist"] atomically:NO];
            }
            [looper release];
            NSLog(@"Wrote %@ to disk", doc);
        }
        /*[tempwc writeToFile:wcfilepath atomically:NO];
        [topwords writeToFile:[wcfilepath stringByAppendingString:@"-top.plist"] atomically:NO];*/
        [documentFreqs writeToFile:[uiController idffilepathForTitle:@"<<<ALLDATA>>>"]];
    }
    //[[canvas textStorage] setAttributedString:[[[NSAttributedString alloc] initWithString:[[wordCounts immutableBackingstoreCopy] description]] autorelease]];
    //[loadbar setDoubleValue:0];
    //[loadbar stopAnimation:nil];
    [uiController analysisDidFinish:self]; //[stageLabel setStringValue:@"Done!"];
    //[self showAnalysis];
    [pool release];
}

-(NSString*) cleanupWord:(NSString*) word {
    word = [word lowercaseString];
    NSArray *stopwords = [[NSUserDefaults standardUserDefaults] boolForKey:@"excludeStopwords"] ? [[NSUserDefaults standardUserDefaults] arrayForKey:@"stopWords"] : [NSArray array];
    // only include words without colons and numbers and other junk in them
    if ([word rangeOfString:@":"].location == NSNotFound && [word rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]].location == NSNotFound && [word rangeOfCharacterFromSet:[NSCharacterSet punctuationCharacterSet]].location == NSNotFound &&
        [stopwords indexOfObject:word] == NSNotFound) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"shouldStem"]) {
            // now stem this baby ... pure C integration ftw! lol.
            char *originalString = [word cStringUsingEncoding:NSASCIIStringEncoding];
            if (originalString) {
                int j = [word lengthOfBytesUsingEncoding:NSASCIIStringEncoding]-1;
                int stringend = j;
                @synchronized(uiController) {
                    stringend = stem(originalString, 0, j);
                }
                if (stringend != j) {
                    NSString *stemmedword = [word substringToIndex:stringend+1];
                    word = stemmedword;
                }
            } else {
                // NSString doesn't let you convert to C string losslessly easily, so forget it
            }
        }
        return word;
    } else {
        return nil;
    }
}

-(NSString*)cardTitle {
    return @"Full analysis";
}

-(void) dealloc {
    [wordCounts removeAllObjects];
    [documentFreqs reset];
    [wordCounts release];
    [documentFreqs release];
    [super dealloc];
}    


@end
