#import "CDTypeParser.h"

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "datatypes.h"
//#include "gram.h" // for TK_IDENTIFIER

#import <Foundation/Foundation.h>
#import "CDTypeLexer.h"
#import "NSString-Extensions.h"

//static struct method_type *rtype = NULL; // Yuck

//----------------------------------------------------------------------

NSString *CDSyntaxError = @"Syntax Error";

NSString *CDTokenDescription(int token)
{
    if (token < 128)
        return [NSString stringWithFormat:@"%d(%c)", token, token];

    return [NSString stringWithFormat:@"%d", token];
}

@implementation CDTypeParser

- (id)init;
{
    if ([super init] == nil)
        return nil;

    lexer = nil;

    return self;
}

- (void)dealloc;
{
    [lexer release];

    [super dealloc];
}

- (void)match:(int)token;
{
    [self match:token allowIdentifier:NO];
}

- (void)match:(int)token allowIdentifier:(BOOL)shouldAllowIdentifier;
{
    if (lookahead == token) {
        //NSLog(@"matched %@", CDTokenDescription(token));
        if (shouldAllowIdentifier == YES)
            [lexer setIsInIdentifierState:YES];
        lookahead = [lexer nextToken];
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

- (NSString *)parseType:(NSString *)type name:(NSString *)name;
{
    struct my_objc_type *result;
    NSMutableString *resultString;

    //NSLog(@" > %s", _cmd);
    //NSLog(@"name: %@, type: %@", name, type);

    assert(lexer == nil);
    lexer = [[CDTypeLexer alloc] initWithString:type];
#if 0
    {
        int token;

        NSLog(@"Lexing string '%@'", type);
        //token = [lexer nextToken];
        //token = [lexer nextToken];
        //[lexer setIsInIdentifierState:YES];
        do {
            token = [lexer nextToken];
            if (token > 0 && token < 128)
                NSLog(@"token %d(%c)", token, token);
            else
                NSLog(@"token %d, lex text '%@'", token, [lexer lexText]);
        } while (token != 0);
        [lexer release];
        lexer = nil;
        return NULL;
    }
#endif
    lookahead = [lexer nextToken];


    NS_DURING {
        result = [self parseType];
    } NS_HANDLER {
        NSLog(@"caught exception: %@", localException);
        NSLog(@"type: %s, name: %s", type, name);

        free_allocated_methods();
        free_allocated_types();
        result = NULL;
    } NS_ENDHANDLER;

    [lexer release];
    lexer = nil;

    if (result == NULL)
        return nil;

    resultString = [NSMutableString string];
    result->var_name = [name retain];
    [resultString appendString:[NSString spacesIndentedToLevel:1]];
    [resultString appendString:string_from_type(result, nil, NO, 1)];
    [resultString appendString:@";"];

    free_allocated_methods();
    free_allocated_types();

    //NSLog(@"<  %s", _cmd);

    return resultString;
}

- (struct method_type *)parseMethodName:(NSString *)name type:(NSString *)type;
{
#if 0
    yy_scan_string(type);

    free_allocated_methods();
    free_allocated_types();
#endif
    return NULL;
}


- (struct my_objc_type *)parseType;
{
    struct my_objc_type *result;

    if (lookahead == 'r'
        || lookahead == 'n'
        || lookahead == 'N'
        || lookahead == 'o'
        || lookahead == 'O'
        || lookahead == 'R'
        || lookahead == 'V') { // modifiers
        int modifier;
        struct my_objc_type *unmodifiedType;
        modifier = lookahead;
        [self match:modifier];

        unmodifiedType = [self parseType];
        result = create_modified_type(modifier, unmodifiedType);
    } else if (lookahead == '^') { // pointer
        struct my_objc_type *type;

        [self match:'^'];
        type = [self parseType];
        result = create_pointer_type(type);
    } else if (lookahead == 'b') { // bitfield
        NSString *number;

        [self match:'b'];
        number = [self parseNumber];
        result = create_bitfield_type(number);
    } else if (lookahead == '@') { // id
        [self match:'@'];
        if (lookahead == '"') {
            NSString *name;

            name = [self parseQuotedName];
            //NSLog(@"-----------> name = %p:'%s'", name, name);
            result = create_id_type(name);
        } else {
            result = create_id_type(NULL);
        }
    } else if (lookahead == '{') { // structure
        NSString *typeName;
        struct my_objc_type *optionalFormat;

        [self match:'{' allowIdentifier:YES];
        typeName = [self parseTypeName];
        optionalFormat = [self parseOptionalFormat];
        [self match:'}'];

        result = create_struct_type(typeName, optionalFormat);
    } else if (lookahead == '(') { // union
        [self match:'(' allowIdentifier:YES];
        if (lookahead == TK_IDENTIFIER) {
            NSString *identifier;
            struct my_objc_type *optionalFormat;

            identifier = [self parseIdentifier];
            optionalFormat = [self parseOptionalFormat];
            [self match:')'];

            result = create_union_type(optionalFormat, identifier);
        } else {
            struct my_objc_type *unionTypes;

            unionTypes = [self parseUnionTypes];
            [self match:')'];

            result = create_union_type(unionTypes, NULL);
        }
    } else if (lookahead == '[') { // array
        NSString *number;
        struct my_objc_type *type;

        [self match:'['];
        number = [self parseNumber];
        type = [self parseType];
        [self match:']'];

        result = create_array_type(number, type);
    } else if ([self isLookaheadInSimpleTypeSet] == YES) { // simple type
        int simpleType;

        simpleType = lookahead;
        [self match:simpleType];
        result = create_simple_type(simpleType);
    } else {
        result = NULL;
        [NSException raise:CDSyntaxError format:@"expected (many things), got %d", lookahead];
    }

    return result;
}

- (struct my_objc_type *)parseUnionTypes;
{
    struct my_objc_type *result;

    result = NULL;
    while ([self isLookaheadInTypeSet] == YES) {
        struct my_objc_type *type;

        type = [self parseType];
        type->var_name = [@"___" retain];
        type->next = result;
        result = type;
    }

    return result;
}

- (struct my_objc_type *)parseOptionalFormat;
{
    struct my_objc_type *result;

    if (lookahead == '=') {
        [self match:'='];
        result = [self parseTagList];
    } else
        result = NULL;

    return result;
}

- (struct my_objc_type *)parseTagList;
{
    struct my_objc_type *result;

    result = NULL;
    while (lookahead == '"' || [self isLookaheadInTypeSet] == YES) {
        struct my_objc_type *tag;

        tag = [self parseTag];
        tag->next = result;
        result = tag;
    }

    return result;
}

- (struct my_objc_type *)parseTag;
{
    struct my_objc_type *result;

    if (lookahead == '"') {
        NSString *identifier;

        identifier = [self parseQuotedName];
        result = [self parseType];
        result->var_name = [identifier retain];
    } else {
        result = [self parseType];
        result->var_name = [@"___" retain];
    }

    return result;
}

- (NSString *)parseTypeName;
{
    NSString *identifier;

    identifier = [self parseIdentifier];
    if (lookahead == '<') {
        [self match:'<' allowIdentifier:YES];
        [self parseIdentifier];
        while (lookahead == ',') {
            [self match:',' allowIdentifier:YES];
            [self parseIdentifier];
        }
    }

    return identifier;
}

- (NSString *)parseIdentifier;
{
    if (lookahead == TK_IDENTIFIER) {
        NSString *result;

        result = [lexer lexText];
        //NSLog(@"---> identifier %p:(%s)", result, result);
        [self match:TK_IDENTIFIER];
        return result;
    }

    return NULL;
}

- (NSString *)parseNumber;
{
    if (lookahead == TK_NUMBER) {
        NSString *result;

        result = [lexer lexText];
        [self match:TK_NUMBER];
        return result;
    }

    return NULL;
}

- (NSString *)parseQuotedName;
{
    [self match:'"' allowIdentifier:YES];
    if (lookahead == '"') {
        [self match:'"'];
        return @"";
    } else {
        NSString *identifier;

        identifier = [self parseIdentifier];
        [self match:'"'];
        return identifier;
    }
}

- (BOOL)isLookaheadInModifierSet;
{
    if (lookahead == 'r'
        || lookahead == 'n'
        || lookahead == 'N'
        || lookahead == 'o'
        || lookahead == 'O'
        || lookahead == 'R'
        || lookahead == 'V')
        return YES;

    return NO;
}

- (BOOL)isLookaheadInSimpleTypeSet;
{
    if (lookahead == 'c'
        || lookahead == 'i'
        || lookahead == 's'
        || lookahead == 'l'
        || lookahead == 'q'
        || lookahead == 'C'
        || lookahead == 'I'
        || lookahead == 'S'
        || lookahead == 'L'
        || lookahead == 'Q'
        || lookahead == 'f'
        || lookahead == 'd'
        || lookahead == 'B'
        || lookahead == 'v'
        || lookahead == '*'
        || lookahead == '#'
        || lookahead == ':'
        || lookahead == '%'
        || lookahead == '?')
        return YES;

    return NO;
}

- (BOOL)isLookaheadInTypeSet;
{
    if ([self isLookaheadInModifierSet] == YES
        || [self isLookaheadInSimpleTypeSet] == YES
        || lookahead == '^'
        || lookahead == 'b'
        || lookahead == '@'
        || lookahead == '{'
        || lookahead == '('
        || lookahead == '[')
        return YES;

    return NO;
}

@end
