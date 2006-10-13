//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004-2005  Steve Nygard

#import "CDTypeParser.h"

#include <assert.h>
#import <Foundation/Foundation.h>
#import "CDMethodType.h"
#import "CDType.h"
#import "CDTypeName.h"
#import "CDTypeLexer.h"
#import "NSString-Extensions.h"

NSString *CDSyntaxError = @"Syntax Error";

NSString *CDTokenDescription(int token)
{
    if (token < 128)
        return [NSString stringWithFormat:@"%d(%c)", token, token];

    return [NSString stringWithFormat:@"%d", token];
}

@implementation CDTypeParser

- (id)initWithType:(NSString *)aType;
{
    if ([super init] == nil)
        return nil;

    lexer = [[CDTypeLexer alloc] initWithString:aType];
    lookahead = 0;

    return self;
}

- (void)dealloc;
{
    [lexer release];

    [super dealloc];
}

- (CDTypeLexer *)lexer;
{
    return lexer;
}

- (NSArray *)parseMethodType;
{
    NSArray *result;

    NS_DURING {
        lookahead = [lexer scanNextToken];
        result = [self _parseMethodType];
    } NS_HANDLER {
        NSLog(@"caught exception: %@", localException);
        NSLog(@"type: %@", [lexer string]);
        NSLog(@"remaining string: %@", [lexer remainingString]);

        result = nil;
    } NS_ENDHANDLER;

    return result;
}

- (CDType *)parseType;
{
    CDType *result;

    NS_DURING {
        lookahead = [lexer scanNextToken];
        result = [self _parseType];
    } NS_HANDLER {
        NSLog(@"caught exception: %@", localException);
        NSLog(@"type: %@", [lexer string]);
        NSLog(@"remaining string: %@", [lexer remainingString]);

        result = nil;
    } NS_ENDHANDLER;

    return result;
}

@end

@implementation CDTypeParser (Private)

- (void)match:(int)token;
{
    [self match:token enterState:[lexer state]];
}

- (void)match:(int)token enterState:(int)newState;
{
    if (lookahead == token) {
        //NSLog(@"matched %@", CDTokenDescription(token));
        [lexer setState:newState];
        lookahead = [lexer scanNextToken];
    } else {
        [NSException raise:CDSyntaxError format:@"expected token %@, got %@",
                     CDTokenDescription(token),
                     CDTokenDescription(lookahead)];
    }
}

- (void)error:(NSString *)errorString;
{
    [NSException raise:CDSyntaxError format:@"%@", errorString];
}

- (NSArray *)_parseMethodType;
{
    NSMutableArray *methodTypes;
    CDMethodType *aMethodType;
    CDType *type;
    NSString *number;

    methodTypes = [NSMutableArray array];

    // Has to have at least one pair for the return type;
    // Probably needs at least two more, for object and selector

    do {
        type = [self _parseType];
        number = [self parseNumber];

        aMethodType = [[CDMethodType alloc] initWithType:type offset:number];
        [methodTypes addObject:aMethodType];
        [aMethodType release];
    } while ([self isTokenInTypeStartSet:lookahead] == YES);

    return methodTypes;
}

// Plain object types can be:
//     @                     - plain id type
//     @"NSObject"           - NSObject *
//     @"<MyProtocol>"       - id <MyProtocol>
// But these can also be part of a structure, with the member name in quotes before the type:
//     i"foo"                - int foo
//     @"foo"                - id foo
//     @"Foo"                - Foo *
// So this is where the class name heuristics are used.  I think.  Maybe.
//
// I'm going to make a simplifying assumption:  Either the structure/union has member names,
// or is doesn't, it can't have some names and be missing others.
// The two key tests are:
//     {my_struct3="field1"@"field2"i}
//     {my_struct4="field1"@"NSObject""field2"i}
//
// Hmm.  I think having the lexer have a quoted string token would make the lookahead easier.

- (CDType *)_parseType;
{
    return [self _parseTypeCheckFieldNames:NO];
}

- (CDType *)_parseTypeCheckFieldNames:(BOOL)shouldCheckFieldNames;
{
    CDType *result;

    if (lookahead == 'r'
        || lookahead == 'n'
        || lookahead == 'N'
        || lookahead == 'o'
        || lookahead == 'O'
        || lookahead == 'R'
        || lookahead == 'V') { // modifiers
        int modifier;
        CDType *unmodifiedType;
        modifier = lookahead;
        [self match:modifier];

        if ([self isTokenInTypeStartSet:lookahead] == YES)
            unmodifiedType = [self _parseTypeCheckFieldNames:shouldCheckFieldNames];
        else
            unmodifiedType = nil;
        result = [[CDType alloc] initModifier:modifier type:unmodifiedType];
    } else if (lookahead == '^') { // pointer
        CDType *type;

        [self match:'^'];
        type = [self _parseTypeCheckFieldNames:shouldCheckFieldNames];
        result = [[CDType alloc] initPointerType:type];
    } else if (lookahead == 'b') { // bitfield
        NSString *number;

        [self match:'b'];
        number = [self parseNumber];
        result = [[CDType alloc] initBitfieldType:number];
    } else if (lookahead == '@') { // id
        [self match:'@'];
#if 0
        if (lookahead == TK_QUOTED_STRING) {
            NSLog(@"%s, quoted string ahead, shouldCheckFieldNames: %d, end: %d",
                  _cmd, shouldCheckFieldNames, [[lexer scanner] isAtEnd]);
            if ([[lexer scanner] isAtEnd] == NO)
                NSLog(@"next character: %d (%c), isInTypeStartSet: %d", [lexer peekChar], [lexer peekChar], [self isTokenInTypeStartSet:[lexer peekChar]]);
        }
#endif
        if (lookahead == TK_QUOTED_STRING && (shouldCheckFieldNames == NO || [[lexer scanner] isAtEnd] || [self isTokenInTypeStartSet:[lexer peekChar]] == NO)) {
            NSString *str;
            CDTypeName *typeName;

            str = [lexer lexText];
            if ([str hasPrefix:@"<"] == YES && [str hasSuffix:@">"] == YES) {
                str = [str substringWithRange:NSMakeRange(1, [str length] - 2)];
                result = [[CDType alloc] initIDTypeWithProtocols:str];
            } else {
                typeName = [[CDTypeName alloc] init];
                [typeName setName:str];
                result = [[CDType alloc] initIDType:typeName];
                [typeName release];
            }

            [self match:TK_QUOTED_STRING];
        } else {
            result = [[CDType alloc] initIDType:nil];
        }
    } else if (lookahead == '{') { // structure
        CDTypeName *typeName;
        NSArray *optionalMembers;
        CDTypeLexerState savedState;

        savedState = [lexer state];
        [self match:'{' enterState:CDTypeLexerStateIdentifier];
        typeName = [self parseTypeName];
        optionalMembers = [self parseOptionalMembers];
        [self match:'}' enterState:savedState];

        result = [[CDType alloc] initStructType:typeName members:optionalMembers];
    } else if (lookahead == '(') { // union
        CDTypeLexerState savedState;

        savedState = [lexer state];
        [self match:'(' enterState:CDTypeLexerStateIdentifier];
        if (lookahead == TK_IDENTIFIER) {
            CDTypeName *typeName;
            NSArray *optionalMembers;

            typeName = [self parseTypeName];
            optionalMembers = [self parseOptionalMembers];
            [self match:')' enterState:savedState];

            result = [[CDType alloc] initUnionType:typeName members:optionalMembers];
        } else {
            NSArray *unionTypes;

            unionTypes = [self parseUnionTypes];
            [self match:')' enterState:savedState];

            result = [[CDType alloc] initUnionType:nil members:unionTypes];
        }
    } else if (lookahead == '[') { // array
        NSString *number;
        CDType *type;

        [self match:'['];
        number = [self parseNumber];
        type = [self _parseType];
        [self match:']'];

        result = [[CDType alloc] initArrayType:type count:number];
    } else if ([self isTokenInSimpleTypeSet:lookahead] == YES) { // simple type
        int simpleType;

        simpleType = lookahead;
        [self match:simpleType];
        result = [[CDType alloc] initSimpleType:simpleType];
    } else {
        result = nil;
        [NSException raise:CDSyntaxError format:@"expected (many things), got %d", lookahead];
    }

    return [result autorelease];
}

// This seems to be used in method types -- no names
- (NSArray *)parseUnionTypes;
{
    NSMutableArray *members;

    members = [NSMutableArray array];

    while ([self isTokenInTypeSet:lookahead] == YES) {
        CDType *aType;

        aType = [self _parseType];
        //[aType setVariableName:@"___"];
        [members addObject:aType];
    }

    return members;
}

- (NSArray *)parseOptionalMembers;
{
    NSArray *result;

    if (lookahead == '=') {
        [self match:'='];
        result = [self parseMemberList];
    } else
        result = nil;

    return result;
}

- (NSArray *)parseMemberList;
{
    NSMutableArray *result;
    BOOL hasMemberNames;

    result = [NSMutableArray array];
    hasMemberNames = (lookahead == TK_QUOTED_STRING);
    //NSLog(@"%s, hasMemberNames: %d", _cmd, hasMemberNames);

    if (lookahead == TK_QUOTED_STRING) {
        while (lookahead == TK_QUOTED_STRING)
            [result addObject:[self parseMemberWithName:YES]];
    } else {
        while ([self isTokenInTypeSet:lookahead] == YES)
            [result addObject:[self parseMemberWithName:NO]];
    }

    return result;
}

- (CDType *)parseMemberWithName:(BOOL)hasMemberName;
{
    CDType *result;

    //NSLog(@" > %s, hasMemberName: %d", _cmd, hasMemberName);
    if (hasMemberName == YES) {
        NSString *identifier;

        identifier = [lexer lexText];
        [self match:TK_QUOTED_STRING];

        result = [self _parseTypeCheckFieldNames:hasMemberName];
        [result setVariableName:identifier];
    } else {
        result = [self _parseType];
    }

    //NSLog(@"<  %s", _cmd);
    return result;
}

- (CDTypeName *)parseTypeName;
{
    CDTypeName *typeName;

    typeName = [[[CDTypeName alloc] init] autorelease];
    [typeName setName:[self parseIdentifier]];

    if (lookahead == '<') {
        CDTypeLexerState savedState;

        savedState = [lexer state];
        [self match:'<' enterState:CDTypeLexerStateTemplateTypes];
        [typeName addTemplateType:[self parseTypeName]];
        while (lookahead == ',') {
            [self match:','];
            [typeName addTemplateType:[self parseTypeName]];
        }

        // iPhoto 5 has types like.... vector<foo,bar<blegga> >  -- note the extra space
        // Also, std::pair<const double, int>
        [self match:'>' enterState:savedState];
    }

    return typeName;
}

- (NSString *)parseIdentifier;
{
    if (lookahead == TK_IDENTIFIER) {
        NSString *result;

        result = [lexer lexText];
        [self match:TK_IDENTIFIER];
        return result;
    }

    return nil;
}

- (NSString *)parseNumber;
{
    if (lookahead == TK_NUMBER) {
        NSString *result;

        result = [lexer lexText];
        [self match:TK_NUMBER];
        return result;
    }

    return nil;
}

- (BOOL)isTokenInModifierSet:(int)aToken;
{
    if (aToken == 'r'
        || aToken == 'n'
        || aToken == 'N'
        || aToken == 'o'
        || aToken == 'O'
        || aToken == 'R'
        || aToken == 'V')
        return YES;

    return NO;
}

- (BOOL)isTokenInSimpleTypeSet:(int)aToken;
{
    if (aToken == 'c'
        || aToken == 'i'
        || aToken == 's'
        || aToken == 'l'
        || aToken == 'q'
        || aToken == 'C'
        || aToken == 'I'
        || aToken == 'S'
        || aToken == 'L'
        || aToken == 'Q'
        || aToken == 'f'
        || aToken == 'd'
        || aToken == 'B'
        || aToken == 'v'
        || aToken == '*'
        || aToken == '#'
        || aToken == ':'
        || aToken == '%'
        || aToken == '?')
        return YES;

    return NO;
}

- (BOOL)isTokenInTypeSet:(int)aToken;
{
    if ([self isTokenInModifierSet:aToken] == YES
        || [self isTokenInSimpleTypeSet:aToken] == YES
        || aToken == '^'
        || aToken == 'b'
        || aToken == '@'
        || aToken == '{'
        || aToken == '('
        || aToken == '[')
        return YES;

    return NO;
}

- (BOOL)isTokenInTypeStartSet:(int)aToken;
{
    if (aToken == 'r'
        || aToken == 'n'
        || aToken == 'N'
        || aToken == 'o'
        || aToken == 'O'
        || aToken == 'R'
        || aToken == 'V'
        || aToken == '^'
        || aToken == 'b'
        || aToken == '@'
        || aToken == '{'
        || aToken == '('
        || aToken == '['
        || [self isTokenInSimpleTypeSet:aToken] == YES)
        return YES;

    return NO;
}

@end
