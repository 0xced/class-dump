//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004-2006  Steve Nygard

#import <ObjcUnit/TestCase.h>

@interface CDTypeParserUnitTest : TestCase
{
}

- (void)setUp;
- (void)tearDown;

- (void)testType:(NSString *)aType showLexing:(BOOL)shouldShowLexing;
- (void)testMethodType:(NSString *)aMethodType showLexing:(BOOL)shouldShowLexing;

- (void)testLoneConstType;
- (void)testObjectQuotedStringTypes;

@end
