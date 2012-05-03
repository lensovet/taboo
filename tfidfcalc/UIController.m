//
//  UIController.m
//  tfidfcalc
//
//  Created by Paul Borokhov on 10/9/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import "UIController.h"
#import "Counter.h"
#import "RegexKitLite.h"
#import "porter.h"
#define TF_IDF 0
#define NORMALIZED 1


@implementation UIController

- (IBAction)calculate:(id)sender {
    if ([self initPathsFromTextfield]) {
        NSArray *stopWords = [@"i,me,my,myself,we,our,ours,ourselves,you,your,yours,yourself,yourselves,he,him,his,himself,she,her,hers,herself,it,its,itself,they,them,their,theirs,themselves,what,which,who,whom,this,that,these,those,am,is,are,was,were,be,been,being,have,has,had,having,do,does,did,doing,would,should,could,ought,i'm,you're,he's,she's,it's,we're,they're,i've,you've,we've,they've,i'd,you'd,he'd,she'd,we'd,they'd,i'll,you'll,he'll,she'll,we'll,they'll,isn't,aren't,wasn't,weren't,hasn't,haven't,hadn't,doesn't,don't,didn't,won't,wouldn't,shan't,shouldn't,can't,cannot,couldn't,mustn't,let's,that's,who's,what's,here's,there's,when's,where's,why's,how's,a,an,the,and,but,if,or,because,as,until,while,of,at,by,for,with,about,against,between,into,through,during,before,after,above,below,to,from,up,down,in,out,on,off,over,under,again,further,then,once,here,there,when,where,why,how,all,any,both,each,few,more,most,other,some,such,no,nor,not,only,own,same,so,than,too,very" componentsSeparatedByString:@","];
        [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:stopWords, @"stopWords", nil]];
        wordCounts = [[NSMutableDictionary dictionaryWithCapacity:100] retain];
        documentFreqs = [[Counter blankCounterWithStrings] retain];
        ngrams = [[NSUserDefaults standardUserDefaults] integerForKey:@"ngrams"]+1;
        [progressBar setUsesThreadedAnimation:YES];
        [NSThread detachNewThreadSelector:@selector(runWordcountAnalysis) toTarget:self withObject:nil];
    }
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

-(void) runWordcountAnalysis {    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSLog(@"Beginning tf-idf analysis...");
    [progressBar setIndeterminate:NO];
    [progressBar setDoubleValue:0];
    // for later - regex to clean out external links in articles
    // double-slashes to make gcc happy
    NSString *externalRegex = @"\\[http[^\\]]+\\]";
    // clean out templates
    NSString *templateRegex = @"\\{[^\\}]+\\}";
    // in a very brittle way, attempt to clean out interwiki links
    // this has the potential of wiping out huge sections of articles. dunno.
    NSString *interwikiRegex = @"\\n\\n[a-z]{2,}:.+$";
    // clean out tables, especially prevalent in abstracts
    NSString *tableRegex = @"\\{\\|[^}]+\\|\\}";
    NSString *replacementString = @"";
    
    //// pull all files from dir
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[folderPath stringByStandardizingPath] stringByAppendingPathComponent:[self textDir]] error:NULL];
        
    //[stageLabel setStringValue:@"Analyzing word counts & freqs"];
    [progressBar setMaxValue:[files count]];
    int docsCounted = 0;
    for (NSString *file in files) {
        NSString *page = [[file lastPathComponent] stringByDeletingPathExtension];
        if (!page) continue;
        //[uiController beginAnalyzingSubpage:self withTitle:page];
        
        [progressBar incrementBy:0.99];
        Counter *docWordCount = [Counter blankCounter];
        NSAutoreleasePool *looper = [[NSAutoreleasePool alloc] init];
        NSString *text = [NSString stringWithContentsOfFile:[[folderPath stringByStandardizingPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@", [self textDir], file]] encoding:NSUTF8StringEncoding error:NULL];
        if (text) text = [[[[text stringByReplacingOccurrencesOfRegex:externalRegex withString:replacementString] stringByReplacingOccurrencesOfRegex:templateRegex withString:replacementString] stringByReplacingOccurrencesOfRegex:interwikiRegex withString:replacementString] stringByReplacingOccurrencesOfRegex:tableRegex withString:replacementString];
        else continue;
        //NSLog(@"%@", text);
        
                
        CFRange range = CFRangeMake(0L, [text length]);
        
        CFStringTokenizerRef tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault, (CFStringRef) text, range, kCFStringTokenizerUnitWord, NULL);
        
        NSString *word;
        BOOL exitedOnOwnAccord = NO;
        if (ngrams > 1) {
            while (CFStringTokenizerAdvanceToNextToken(tokenizer) != kCFStringTokenizerTokenNone) {
                CFStringTokenizerAdvanceToNextToken(tokenizer);
                CFRange tokenRange = CFStringTokenizerGetCurrentTokenRange(tokenizer);
                // only include words without colons and numbers and other junk in them
                word = [self cleanupWord:[text substringWithRange:NSMakeRange(tokenRange.location, tokenRange.length)]];
                if (word) {
                    exitedOnOwnAccord = YES;
                    break;
                }
            }
            if (exitedOnOwnAccord) buffer.two = [word retain];
            else continue;
            exitedOnOwnAccord = NO;
            if (ngrams > 2) {
                while (CFStringTokenizerAdvanceToNextToken(tokenizer) != kCFStringTokenizerTokenNone) {
                    CFRange tokenRange = CFStringTokenizerGetCurrentTokenRange(tokenizer);
                    // only include words without colons and numbers and other junk in them
                    word = [self cleanupWord:[text substringWithRange:NSMakeRange(tokenRange.location, tokenRange.length)]];
                    if (word) {
                        exitedOnOwnAccord = YES;
                        break;
                    }
                }
                if (exitedOnOwnAccord) buffer.three = [word retain];
                else continue;
            }
        }
        
        while (CFStringTokenizerAdvanceToNextToken(tokenizer) != kCFStringTokenizerTokenNone) {
            NSAutoreleasePool *tokenpool = [[NSAutoreleasePool alloc] init];
            // advance buffer
            [self advanceBuffer];
            CFRange tokenRange = CFStringTokenizerGetCurrentTokenRange(tokenizer);
            // only include words without colons and numbers and other junk in them
            NSString *word = [self cleanupWord:[text substringWithRange:NSMakeRange(tokenRange.location, tokenRange.length)]];
            if (word) {
                // generate n-gram from buffer
                word = [self getNgram:word];
                [docWordCount incrementValueForKey:word];
                [documentFreqs appendValue:page toKey:word];
            }
            [tokenpool release];
        }
        CFRelease(tokenizer);
        [looper release];
        [wordCounts setObject:docWordCount forKey:page];
        docsCounted++;
    }
    NSLog(@"Analysis complete, analyzed %d docs", docsCounted);
    //[progressBar setIndeterminate:YES];
    //[progressBar startAnimation:nil];
    //[stageLabel setStringValue:@"Rolling up document frequency dictionary counter..."];
    //[statusLabel setStringValue:@""];
    [documentFreqs rollupStringCounter];
    
    //[stageLabel setStringValue:@"Calculating tf-idf values..."];
    NSLog(@"Calculating tf-idf values...");
    NSMutableDictionary *idfvals = [NSMutableDictionary dictionaryWithCapacity:[documentFreqs count]];
    NSDictionary *freqs = [documentFreqs immutableBackingstoreCopy];
    for (NSString *word in freqs) {
        double idf = log(docsCounted/(1.0+[[freqs objectForKey:word] doubleValue]));
        [idfvals setObject:[NSNumber numberWithDouble:idf] forKey:word];
    }
    //NSLog(@"idf value for \"the\" is %@", [idfvals objectForKey:@"the"]);
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
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"shouldSaveLocalResults"]) {
        NSLog(@"Beginning analysis save...");
        // save our analysis
        for (NSString *doc in wordCounts) {
            NSAutoreleasePool *looper = [[NSAutoreleasePool alloc] init];
            NSDictionary *store = [[wordCounts objectForKey:doc] immutableBackingstoreCopy];
            [store writeToFile:[self idffilepathForTitle:doc] atomically:NO];
            if ([[store allKeys] count] > 20) {
                NSArray *topkeys = [[store keysSortedByValueUsingSelector:@selector(compareInReverse:)] objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 20)]];
                [[NSDictionary dictionaryWithObjects:[store objectsForKeys:topkeys notFoundMarker:[NSNull null]] forKeys:topkeys] writeToFile:[[self idffilepathForTitle:doc] stringByAppendingString:@"-top.plist"] atomically:NO];
            }
            [looper release];
            //NSLog(@"Wrote %@ to disk", doc);
        }
        [documentFreqs writeToFile:[self idffilepathForTitle:@"<<<ALLDATA>>>"]];
        NSLog(@"...disk write complete");
    }
    //[[canvas textStorage] setAttributedString:[[[NSAttributedString alloc] initWithString:[[wordCounts immutableBackingstoreCopy] description]] autorelease]];
    //[progressBar setDoubleValue:0];
    //[progressBar stopAnimation:nil];
    //[uiController analysisDidFinish:self]; //[stageLabel setStringValue:@"Done!"];
    [progressBar setMaxValue:1.0];
    [progressBar setDoubleValue:1.0];
    //[self showAnalysis];
    [pool release];
}

-(void) advanceBuffer {
    switch (ngrams) {
        case 1:
            [buffer.one release];
            buffer.one = nil;
            break;
        case 2:
            if (buffer.two != nil) {
                [buffer.one release];
                buffer.one = buffer.two;
                buffer.two = nil;
            }
            break;
        default:
            if (buffer.three != nil) {
                [buffer.one release];
                buffer.one = buffer.two;
                buffer.two = buffer.three;
                buffer.three = nil;
            }
    }
}

-(NSString*) getNgram:(NSString*) newword {
    switch (ngrams) {
        case 1:
            buffer.one = [newword retain];
            return buffer.one;
        case 2:
            buffer.two = [newword retain];
            return [NSString stringWithFormat:@"%@ %@", buffer.one, buffer.two];
        default:
            buffer.three = [newword retain];
            return [NSString stringWithFormat:@"%@ %@ %@", buffer.one, buffer.two, buffer.three];
    }
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
                @synchronized(self) {
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

-(NSString *) textDir {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"abstractsOnly"] ? @"txt-abstracts" : @"txt";
}

@end
