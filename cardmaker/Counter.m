//
//  Counter.m
//  taboo
//
//  Created by Paul Borokhov on 7/12/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import "Counter.h"


@implementation Counter
+ (Counter *) blankCounter {
	return [[[Counter alloc] init] autorelease];
}

+ (Counter *) blankCounterWithStrings {
    Counter *new = [Counter blankCounter];
    [new _setIsStringBased:YES];
    return new;
}

- (Counter *) init {
	if ((self = [super init])) {
		backingStore = [[NSMutableDictionary dictionaryWithCapacity:10] retain];
        isStringBased = NO;
	}
	return self;
}

- (Counter *) initFromFile:(NSString *)filepath withSingleCountsOnly:(BOOL)singleCount {
    if ((self = [super init])) {
        backingStore = [[NSMutableDictionary dictionaryWithContentsOfFile:filepath] retain];
        isStringBased = singleCount;
        if (!backingStore) return nil;
    }
    return self;
}

- (Counter *) _initFromDictionary:(NSDictionary *)store isStringBased:(BOOL)stringBased {
    if ((self = [super init])) {
        backingStore = [[NSMutableDictionary dictionaryWithDictionary:store] retain];
        isStringBased = stringBased;
        if (!backingStore) return nil;
    }
    return self;
}

-(void) incrementValueForKey:(NSString *)key {
    if (!isStringBased) {
        if ([backingStore objectForKey:key]) {
            [backingStore setValue:[NSNumber numberWithInt:[[backingStore objectForKey:key] integerValue]+1] forKey:key];
        } else {
            [backingStore setValue:[NSNumber numberWithInt:1] forKey:key];
        }
    } else {
        // what the hell
    }
}

-(void) appendValue:(NSString *) value toKey:(NSString *) key {
    if (isStringBased) {
        NSMutableSet *pages;
        if ((pages = [backingStore objectForKey:key])) {
            [pages addObject:value];
        } else {
            [backingStore setValue:[NSMutableSet setWithObject:value] forKey:key];
        }
    } else {
        NSLog(@"i hate you");
    }
}

-(int) count {
    return [backingStore count];
}

-(void) rollupStringCounter {
    if (isStringBased) {
        for (NSString *word in [backingStore allKeys]) {
            [backingStore setValue:[NSNumber numberWithInt:[[backingStore objectForKey:word] count]] forKey:word];
        }
    } else {
        NSLog(@"I hate you more");
    }
}

-(void) convertToTfIdf:(NSDictionary*) idfCounts withDocs:(NSDictionary*) idfVals {
    int totalwords = 0;
    for (NSString *word in backingStore) {
        totalwords += [[backingStore objectForKey:word] intValue];
    }
    for (NSString *word in [backingStore allKeys]) {
        int rawwc = [[backingStore objectForKey:word] intValue];
        double normalizedwc = (double) rawwc/(double) totalwords;
        double idf = [[idfVals objectForKey:word] doubleValue];
        //if ([word caseInsensitiveCompare:@"the"] == NSOrderedSame) NSLog(@"Looking at the, raw %d, normalized %.4f, idf %.4f, tf-idf %.4f", rawwc, normalizedwc, idf, normalizedwc*idf);
        [backingStore setObject:[NSNumber numberWithDouble:normalizedwc*idf] forKey:word];
    }
}

-(void) normalizeVector {
    double sumOfSquares = 0;
    for (NSString *word in backingStore) {
        sumOfSquares += [[backingStore objectForKey:word] doubleValue]*[[backingStore objectForKey:word] doubleValue];
    }
    double norm = sqrt(sumOfSquares);
    for (NSString *word in [backingStore allKeys]) {
        double rawwc = [[backingStore objectForKey:word] doubleValue];
        double normalizedValue = rawwc/norm;
        [backingStore setObject:[NSNumber numberWithDouble:normalizedValue] forKey:word];
    }
}
-(double) vectorDotProductWith:(NSDictionary *) seedDoc {
    return [self vectorDotProductWith:seedDoc withLogging:false];
}

-(double) vectorDotProductWith:(NSDictionary *) seedDoc withLogging:(bool)shouldLog {
    double dotproduct = 0;
    NSDictionary *iterator = backingStore;
    NSDictionary *rightSide = seedDoc;
    if (shouldLog) NSLog(@"------------------");
    
    // speed optimization which hopefully doesn't bite us in the ass
    if ([seedDoc count] < [iterator count]) {
        iterator = seedDoc;
        rightSide = backingStore;
    }
    
    for (NSString *word in iterator) {
        if (shouldLog) NSLog(@"Got word %@ for dotprod", word);
        NSNumber *rightpart = [rightSide objectForKey:word];
        if (rightpart) {
            double delta = [[iterator objectForKey:word] doubleValue]*[rightpart doubleValue];
            dotproduct += delta;
            if (shouldLog) NSLog(@"Added %f to dotprod, now = %f", delta, dotproduct);
        }
    }
    return dotproduct;
}

-(NSMutableDictionary*) multpliedByScalar:(double) scalar {
    NSMutableDictionary *retval = [NSMutableDictionary dictionaryWithCapacity:[backingStore count]];
    for (NSString *word in backingStore) {
        [retval setObject:[NSNumber numberWithDouble:scalar*[[backingStore objectForKey:word] doubleValue]] forKey:word];
    }
    return retval;
}

-(void) differenceVectorWith:(NSDictionary*)values {
    NSArray *iterator = [[backingStore allKeys] arrayByAddingObjectsFromArray:[values allKeys]];
    for (NSString *word in iterator) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        //NSLog(@"%@", [values description]);
        //NSNumber *right = [values objectForKey:word];
        double rightvalue = [[values objectForKey:word] doubleValue]; //right ? [right doubleValue] : 0;
        //NSNumber *left = [backingStore objectForKey:word];
        double leftvalue = [[backingStore objectForKey:word] doubleValue]; //left ? [left doubleValue] : 0;
        NSNumber *diff = [NSNumber numberWithDouble:leftvalue-rightvalue];
        //NSLog(@"Word %@: right %@, left %@, oldval %f, newval %f", word, right, left, leftvalue, [diff doubleValue]);
        [backingStore setObject:diff forKey:word];
        [pool release];
    }
}

-(NSDictionary*) immutableBackingstoreCopy {
    return [NSDictionary dictionaryWithDictionary:backingStore];
}

-(void) reset {
    [backingStore removeAllObjects];
}

-(void) dealloc {
    [backingStore release];
    [super dealloc];
}

-(void) _setIsStringBased:(BOOL)value {
    isStringBased = value;
}

-(void) writeToFile:(NSString *)filepath {
    [backingStore writeToFile:filepath atomically:NO];
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeBool:isStringBased forKey:@"isStringBased"];
    [encoder encodeObject:[self immutableBackingstoreCopy] forKey:@"backingStore"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if ((self = [super init])) {
        backingStore = [[NSMutableDictionary dictionaryWithDictionary:[decoder decodeObjectForKey:@"backingStore"]] retain];
        isStringBased = [decoder decodeBoolForKey:@"isStringBased"];
    }
    return self;
}

- (id) copyWithZone:(NSZone *)zone {
	return [[[self class] allocWithZone:zone] _initFromDictionary:[self immutableBackingstoreCopy] isStringBased:isStringBased];
}

- (NSString*) description {
    return [NSString stringWithFormat:@"Counter with stringBased: %@ and backing store %@", [NSNumber numberWithBool:isStringBased], [backingStore description]];
}

@end
