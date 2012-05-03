//
//  PageParser.h
//  taboo
//
//  Created by Paul Borokhov on 7/11/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Counter.h"
#import "RegexKitLite.h"
#import "porter.h"
#import "NSNumberAdditions.h"
#import "UIController.h"
#define DEBUG (NO)
@class UIController;

@interface PageParser : NSObject {
    @private
    NSMutableDictionary *wordCounts;

    @protected
    NSString *folderPath;
    Counter *documentFreqs;
    
    UIController *uiController;
    
    @public
}

-(PageParser *)initWithLocalDataDir:(NSString *)filePath withUIController:(UIController *)controller;
-(void)setWordCounts:(NSMutableDictionary*)dic;
-(void)setDocumentFreqs:(Counter*)counter;

-(id) loadArticleWithTitle:(NSString*) title withFormat:(NSString*) format localInitSuccess:(BOOL)localInitSuccess;
-(void) runWordcountAnalysis;
-(NSString*) cleanupWord:(NSString*) word;

-(NSString*)cardTitle;

@end