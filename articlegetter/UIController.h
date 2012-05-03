#import <Cocoa/Cocoa.h>

@interface UIController : NSObject {
    IBOutlet NSTextField *articleName;
    IBOutlet NSTextField *dataFolder;
    IBOutlet NSProgressIndicator *progressBar;
    IBOutlet NSWindow *mainWindow;
    
    NSString *folderPath;
    int pagesFetched;
}
- (IBAction)getPages:(id)sender;
- (IBAction)showBrowsePanel:(id)sender;
-(BOOL) initPathsFromTextfield;
-(BOOL) loadArticleWithTitle:(NSString*) title;
-(BOOL) loadArticleWithTitle:(NSString*) title abstracts:(BOOL)abstractOnly;
-(NSArray*) linksForArticle:(NSString*) title;

@end
