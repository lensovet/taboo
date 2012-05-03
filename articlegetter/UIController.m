#import "UIController.h"

@implementation UIController

- (IBAction)getPages:(id)sender {
    if ([self initPathsFromTextfield]) {
        pagesFetched = 0;
        NSArray *links = [self linksForArticle:[articleName stringValue]]; // [doc objectsForXQuery:@".//pl/@title" error:nil];
        NSMutableSet *linkSet;
        [progressBar setMaxValue:[links count]];
        [progressBar setUsesThreadedAnimation:YES];
        [progressBar setDoubleValue:0];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"linksOfLinks"]) {
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            linkSet = [NSMutableSet setWithCapacity:[links count]*30];
            for (NSXMLNode *article in links) {
                [linkSet addObjectsFromArray:[self linksForArticle:[article stringValue]]];
                [progressBar incrementBy:0.999];
            }
            [progressBar setDoubleValue:0.0];
            [progressBar setMaxValue:[linkSet count]];
            [NSThread detachNewThreadSelector:@selector(fetchArticles:) toTarget:self withObject:[linkSet allObjects]];
            [pool release];
        } else {
            [NSThread detachNewThreadSelector:@selector(fetchArticles:) toTarget:self withObject:links];
            [NSThread detachNewThreadSelector:@selector(loadArticleWithTitle:) toTarget:self withObject:[articleName stringValue]];
        }
    }
}

-(void) fetchArticles:(NSArray*)links {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    BOOL success = YES;
    BOOL abstractsOnly = [[NSUserDefaults standardUserDefaults] boolForKey:@"abstractsOnly"];
    for (NSXMLNode *article in links) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        success == success && [self loadArticleWithTitle:[article stringValue] abstracts:abstractsOnly];
        //NSLog(@"Got article %@", article);
        [progressBar incrementBy:0.99];
        [pool release];
    }
    [progressBar incrementBy:[links count]*0.011];
    NSLog(@"%@", success ? @"YAY!" : @"Boo");
    NSLog(@"Fetched %d pages from the web out of %d linked pages", pagesFetched, [links count]);
    [pool release];
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

//**** Returns AUTORELEASED objects, need to retain if you want to keep them ******//
-(BOOL) loadArticleWithTitle:(NSString*) title {
    return [self loadArticleWithTitle:title abstracts:[[NSUserDefaults standardUserDefaults] boolForKey:@"abstractsOnly"]];
}

//**** Returns AUTORELEASED objects, need to retain if you want to keep them ******//
-(BOOL) loadArticleWithTitle:(NSString*) title abstracts:(BOOL)abstractOnly {
    NSString *contents;
    NSString *urlString;
    NSURL *theURL;
    NSURL *filepathURL;
    NSString *myfilepath;
    NSXMLDocument *doc;
    urlString = [[NSString stringWithFormat:@"http://en.wikipedia.org/w/api.php?action=query&prop=revisions&rvexpandtemplates=0&redirects&rvprop=content&titles=%@&format=xml%@", title, abstractOnly ? @"&rvsection=0" : @""] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    myfilepath = [[folderPath stringByStandardizingPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"txt%@/%@.txt", abstractOnly ? @"-abstracts" : @"", title]];
    
    filepathURL = [NSURL fileURLWithPath:myfilepath];
    theURL = [NSURL URLWithString:urlString];
    
    NSData *rawFile = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:filepathURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:5.0] returningResponse:nil error:nil];
    if (rawFile) return YES;
    
    NSData *raw = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:theURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:5.0] returningResponse:nil error:nil];
    if (!raw) return NO;
    doc = [[[NSXMLDocument alloc] initWithData:raw options:0 error:nil] autorelease];
    if (!doc) return NO;
    NSArray *blah = [doc objectsForXQuery:@".//rev" error:nil];
    if (!blah || [blah count] == 0) return NO;
    
    contents = [[blah objectAtIndex:0] stringValue];
    if (contents && ![contents isEqualToString:@""]) {
        [contents writeToFile:myfilepath atomically:NO encoding:NSUTF8StringEncoding error:nil];
    }
    pagesFetched++;
    return YES;
}

@end
