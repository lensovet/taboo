#import <Foundation/Foundation.h>
#import "porter.h"

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    // insert code here...
    NSLog(@"Hello, World!");
    NSString *cardtitle = @"bird";
    NSString *pageTitle = @"turkey (bird)";
    if ([pageTitle rangeOfString:cardtitle].location != NSNotFound) {
        NSLog(@"The strings match!");
    }
    [pool drain];
    return 0;
}
