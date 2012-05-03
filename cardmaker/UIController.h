//
//  UIController.h
//  cardmaker
//
//  Created by Paul Borokhov on 10/9/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Counter.h"

typedef struct {
    NSString *name;
    double dotprod;
} tuple;


@interface UIController : NSObject {
    IBOutlet NSTextField *articleName;
    IBOutlet NSTextView *canvas;
    IBOutlet NSProgressIndicator *progressBar;
    IBOutlet NSWindow *mainWindow;
    IBOutlet NSTextField *dataFolder;
    
    NSString *folderPath;
    Counter *documentFreqs;
    NSString *seed;
    NSMutableDictionary *visitedPages;
    NSMutableSet *outlinks;
    NSMutableDictionary *pageCounters;
}

-(IBAction) generateCard:(id)sender;
- (IBAction)showBrowsePanel:(id)sender;
-(NSArray*) linksForArticle:(NSString*) title;
-(void) linkParsingComplete ;
- (IBAction)showBrowsePanel:(id)sender ;
- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode  contextInfo:(void  *)contextInfo ;
-(BOOL) initPathsFromTextfield ;
-(id) performCalculation ;
-(id) showAnalysis ;
-(NSString*)cardTitle ;
-(void) freeStorage;
-(void) dealloc ;    
-(NSString *) idffilepathForTitle:(NSString *)cardTitle ;
-(NSString *) stemstatus ;
-(NSString *) stopwordStatus ;
-(NSString *) abstracts ;
-(NSString *) cardresultfilepath:(NSString*) cardTitle ;
-(void) saveDotProduct:(NSArray*)articles ;
-(tuple)getTopScoringArticle:(NSDictionary*)mainCard ignoredWords:(NSArray*)ignoredArray;

@end
