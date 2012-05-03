//
//  UIController.h
//  tfidfcalc
//
//  Created by Paul Borokhov on 10/9/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Counter.h"
typedef struct {
    NSString *one;
    NSString *two;
    NSString *three;
} ngram;


@interface UIController : NSObject {
@private
    NSMutableDictionary *wordCounts;
    Counter *documentFreqs;
    IBOutlet NSTextField *dataFolder;
    IBOutlet NSProgressIndicator *progressBar;
    IBOutlet NSWindow *mainWindow;
    ngram buffer;
    int ngrams;
    
    NSString *folderPath;    
@public
}

- (IBAction)calculate:(id)sender;
- (IBAction)showBrowsePanel:(id)sender;
-(BOOL) initPathsFromTextfield;
-(NSString*) cleanupWord:(NSString*) word;
-(NSString *) idffilepathForTitle:(NSString *)cardTitle;
-(NSString *) stemstatus;
-(NSString *) stopwordStatus;
-(NSString *) abstracts;
-(NSString *) textDir;
-(void) advanceBuffer;
-(NSString*) getNgram:(NSString*) newword;

@end
