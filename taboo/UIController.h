//
//  UIController.h
//  taboo
//
//  Created by Paul Borokhov on 8/2/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class LinkedParser;
@class PageParser;
@class NonanalyticLinkParser;
@class Counter;

@interface UIController : NSObject {
    @private
    NSMutableDictionary *linkParsers;
    NSString *folderPath;
    BOOL didAskForAlert;
    BOOL useCacheForAll;
    NSMutableDictionary *cardResults;
    
    @public
    IBOutlet NSTextField *filePath;
    IBOutlet NSTextField *linksLabel;
    IBOutlet NSWindow *docWindow;
    IBOutlet NSTextView *canvas;
    IBOutlet NSTextField *webSeed;
    IBOutlet NSProgressIndicator *loadbar;
    IBOutlet NSTextField *statusLabel;
    IBOutlet NSTextField *stageLabel;
    IBOutlet NSPopUpButton *wcMechanism;    
    IBOutlet NSPopUpButton *seedArticleOrCategory;
}

-(void) awakeFromNib;
-(IBAction) fetchInfoFromWeb:(id)sender;
-(IBAction) showFilePicker:(id)sender;
-(void) alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;
-(void) presentCachedAnalysisAlert:(LinkedParser*)parser;
-(NSString *) wcfilepathForTitle:(NSString *)cardTitle;
-(NSString *) idffilepathForTitle:(NSString *)cardTitle;
-(NSString *) cardDicPath;
-(NSString *) tfidfstatus;
-(NSString *) stemstatus;
-(NSString *) stopwordStatus;
-(NSString *) abstracts;
-(BOOL) initPathsFromTextfield;
-(BOOL) isSingleArticle;
-(BOOL) cachedCopyExistsForTitle:(NSString*)cardTitle;

// faux delegate methods
-(void) linksTidied:(PageParser*)parser;
-(void) beginArticleXMLGet:(PageParser*)parser;
-(void) beginGettingOnehopLinks:(PageParser*)parser;
-(void) aboutToGetPages:(PageParser*)parser;
-(void) beginGettingPageContents:(PageParser*)parser;
-(void) setTotalSubpageCount:(PageParser*)parser number:(int)num;
-(void) beginGettingSubpageContents:(PageParser*)parser forTitle:(NSString*)title;
-(void) beginAnalyzingCounts:(PageParser*)parser;
-(void) setTotalAnalysisSubpageCount:(PageParser*)parser count:(int)count;
-(void) beginAnalyzingSubpage:(PageParser*)parser withTitle:(NSString*)title;
-(void) beginRollingupCounters:(PageParser*)parser;
-(void) beginCalculatingNormalizedCounts:(PageParser*)parser;
-(void) analysisDidFinish:(PageParser*)parser;
-(void) beginVectorDotProducts:(PageParser*)parser;
-(void) didFinishEverything:(PageParser*)parser;

-(void) setSeedPagesSet:(NSSet*)pages;

-(void) saveDotProduct:(NSArray*)articles forCard:(PageParser*)parser;
@end
