//
//  Counter.h
//  taboo
//
//  Created by Paul Borokhov on 7/12/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <math.h>

@interface Counter : NSObject <NSCoding, NSCopying> {
    @private
    NSMutableDictionary *backingStore;
    BOOL isStringBased;
    NSMutableDictionary *uniques;
    
    @public
}
+ (Counter *) blankCounter;
+ (Counter *) blankCounterWithStrings;
- (Counter *) init;
- (Counter *) initFromFile:(NSString *)filepath withSingleCountsOnly:(BOOL)singleCount;
- (Counter *) _initFromDictionary:(NSDictionary *)store isStringBased:(BOOL)stringBased;
-(void) incrementValueForKey:(NSString *)key;
-(void) appendValue:(NSString *) value toKey:(NSString *) key;

-(void) rollupStringCounter;
-(void) convertToTfIdf:(NSDictionary*) idfCounts withDocs:(NSDictionary*) docCount;
-(void) normalizeVector;
-(double) vectorDotProductWith:(NSDictionary *) seedDoc;
-(int) count;

-(NSDictionary*) immutableBackingstoreCopy;
-(void) reset;
-(void) _setIsStringBased:(BOOL)value;
-(void) writeToFile:(NSString *)filepath;

- (void)encodeWithCoder:(NSCoder *)encoder;
- (id)initWithCoder:(NSCoder *)decoder;
- (id) copyWithZone:(NSZone *)zone;
-(void) dealloc;

@end
