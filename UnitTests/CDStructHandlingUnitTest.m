//
// $Id: CDStructHandlingUnitTest.m,v 1.8 2004/01/08 00:43:09 nygard Exp $
//

//  This file is part of class-dump, a utility for examining the
//  Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004  Steve Nygard

#import "CDStructHandlingUnitTest.h"

#import <Foundation/Foundation.h>
#import "CDClassDump.h"
#import "CDType.h"
#import "CDTypeFormatter.h"
#import "CDTypeParser.h"

@implementation CDStructHandlingUnitTest

- (void)dealloc;
{
    [classDump release];

    [super dealloc];
}

- (void)setUp;
{
    classDump = [[CDClassDump2 alloc] init];
}

- (void)tearDown;
{
    [classDump release];
    classDump = nil;
}

- (void)testVariableName:(NSString *)aVariableName type:(NSString *)aType expectedResult:(NSString *)expectedResult;
{
    NSString *result;

    result = [[classDump ivarTypeFormatter] formatVariable:aVariableName type:aType];
    [self assert:result equals:expectedResult];
}

- (void)registerStructsFromType:(NSString *)aTypeString;
{
    CDTypeParser *parser;
    CDType *type;

    parser = [[CDTypeParser alloc] initWithType:aTypeString];
    type = [parser parseType];
    [type registerStructsWithObject:classDump usedInMethod:NO countReferences:YES];
    [parser release];
}

// TODO (2004-01-05): Move this somewhere that we can share it with the main app.
- (void)testFilename:(NSString *)testFilename;
{
    NSString *inputFilename, *outputFilename;
    NSMutableString *resultString;
    NSString *inputContents, *expectedOutputContents;
    NSArray *inputLines, *inputFields;
    int count, index;

    resultString = [NSMutableString string];

    inputFilename = [testFilename stringByAppendingString:@"-in.txt"];
    outputFilename = [testFilename stringByAppendingString:@"-out.txt"];

    inputContents = [NSString stringWithContentsOfFile:inputFilename];
    expectedOutputContents = [NSString stringWithContentsOfFile:outputFilename];

    inputLines = [inputContents componentsSeparatedByString:@"\n"];
    count = [inputLines count];

    // First register structs/unions
    for (index = 0; index < count; index++) {
        NSString *line;
        line = [inputLines objectAtIndex:index];
        inputFields = [line componentsSeparatedByString:@"\t"];
        if ([line length] > 0)
            [self registerStructsFromType:[inputFields objectAtIndex:0]];
    }

    [classDump processIsomorphicStructs];
    [classDump generateNamesForAnonymousStructs];
    [classDump logStructCounts];
    [classDump logNamedStructs];
    [classDump logAnonymousStructs];
    [classDump logAnonymousRemappings];

    // Then generate output
    [classDump appendNamedStructsToString:resultString];
    [classDump appendTypedefsToString:resultString];

    for (index = 0; index < count; index++) {
        NSString *line;
        NSString *type, *variableName;

        line = [inputLines objectAtIndex:index];
        inputFields = [line componentsSeparatedByString:@"\t"];
        if ([line length] > 0) {
            int fieldCount, level;
            NSString *formattedString;

            fieldCount = [inputFields count];
            type = [inputFields objectAtIndex:0];
            if (fieldCount > 1)
                variableName = [inputFields objectAtIndex:1];
            else
                variableName = @"var";

            if (fieldCount > 2)
                level = [[inputFields objectAtIndex:2] intValue];
            else
                level = 0;

            formattedString = [[classDump ivarTypeFormatter] formatVariable:variableName type:type];
            if (formattedString != nil) {
                [resultString appendString:formattedString];
                [resultString appendString:@";\n"];
            } else {
                [resultString appendString:@"Parse failed.\n"];
            }
        }
    }

    [self assert:resultString equals:expectedOutputContents message:testFilename];
}

- (void)testOne;
{
    NSString *first = @"{_NSRange=II}";

    [self assertNotNil:classDump message:@"classDump"];
    [self assertNotNil:[classDump ivarTypeFormatter] message:@"[classDump ivarTypeFormatter]"];

    [self registerStructsFromType:first];
    [self testVariableName:@"foo" type:first expectedResult:@"    struct _NSRange foo"];

    // Register {_NSRange=II}
    // Test {_NSRange=II}
}

- (void)testTwo;
{
    NSString *first = @"{_NSRange=II}";
    NSString *second = @"{_NSRange=\"location\"I\"length\"I}";

    [self registerStructsFromType:first];
    [self registerStructsFromType:second];
    [self testVariableName:@"foo" type:first expectedResult:@"    struct _NSRange foo"];
    [self testVariableName:@"bar" type:second expectedResult:@"    struct _NSRange bar"];

    // Register {_NSRange=II}
    // Register {_NSRange="location"I"length"I}
    // Test {_NSRange=II}
    // Test {_NSRange="location"I"length"I}
}

- (void)testThree;
{
    NSString *first = @"{_NSRange=\"location\"I\"length\"I}";
    NSString *second = @"{_NSRange=II}";

    [self registerStructsFromType:first];
    [self registerStructsFromType:second];
    [self testVariableName:@"foo" type:first expectedResult:@"    struct _NSRange foo"];
    [self testVariableName:@"bar" type:second expectedResult:@"    struct _NSRange bar"];

    // Register {_NSRange="location"I"length"I}
    // Register {_NSRange=II}
    // Test {_NSRange="location"I"length"I}
    // Test {_NSRange=II}
}

- (void)testFour;
{
    [self testFilename:@"shud01"];
}

- (void)testFive;
{
    [self testFilename:@"shud02"];
}

- (void)testSix;
{
    [self testFilename:@"shud03"];
}

- (void)testSeven;
{
    [self testFilename:@"shud04"];
}

- (void)testEight;
{
    [self testFilename:@"shud05"];
}

- (void)testNine;
{
    [self testFilename:@"shud06"];
}

- (void)testTen;
{
    [self testFilename:@"shud07"];
}

- (void)testEleven;
{
    [self testFilename:@"shud08"];
}

@end
