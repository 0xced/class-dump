#import "CDTypeFormatter.h"

#include <assert.h>

#import "CDMethodType.h"
#import "CDType.h"
#import "CDTypeParser.h"

#import <Foundation/Foundation.h>
#import "NSScanner-Extensions.h"
#import "NSString-Extensions.h"

//----------------------------------------------------------------------

@implementation CDTypeFormatter

+ (id)sharedTypeFormatter;
{
    static CDTypeFormatter *instance = nil;

    if (instance == nil) {
        instance = [[CDTypeFormatter alloc] init];
    }

    return instance;
}

+ (id)sharedIvarTypeFormatter;
{
    static CDTypeFormatter *instance = nil;

    if (instance == nil) {
        instance = [[CDTypeFormatter alloc] init];
        [instance setShouldExpand:NO];
        [instance setShouldAutoExpand:YES];
    }

    return instance;
}

+ (id)sharedMethodTypeFormatter;
{
    static CDTypeFormatter *instance = nil;

    if (instance == nil) {
        instance = [[CDTypeFormatter alloc] init];
        [instance setShouldExpand:NO];
        [instance setShouldAutoExpand:NO];
    }

    return instance;
}

+ (id)sharedStructDeclarationTypeFormatter;
{
    static CDTypeFormatter *instance = nil;

    if (instance == nil) {
        instance = [[CDTypeFormatter alloc] init];
        [instance setShouldExpand:YES];
        [instance setShouldAutoExpand:NO];
    }

    return instance;
}

- (BOOL)shouldExpand;
{
    return shouldExpand;
}

- (void)setShouldExpand:(BOOL)newFlag;
{
    shouldExpand = newFlag;
}

- (BOOL)shouldAutoExpand;
{
    return shouldAutoExpand;
}

- (void)setShouldAutoExpand:(BOOL)newFlag;
{
    shouldAutoExpand = newFlag;
}

- (id)delegate;
{
    return nonretainedDelegate;
}

- (void)setDelegate:(id)newDelegate;
{
    nonretainedDelegate = newDelegate;
}

- (NSString *)formatVariable:(NSString *)name type:(NSString *)type atLevel:(int)level;
{
    CDTypeParser *aParser;
    CDType *resultType;
    NSMutableString *resultString;

    //NSLog(@"%s, shouldExpandStructures: %d", _cmd, shouldExpandStructures);
    //NSLog(@" > %s", _cmd);
    //NSLog(@"name: '%@', type: '%@', level: %d", name, type, level);

    aParser = [[CDTypeParser alloc] initWithType:type];
    resultType = [aParser parseType];
    //NSLog(@"resultType: %p", resultType);

    if (resultType == nil) {
        [aParser release];
        //NSLog(@"<  %s", _cmd);
        return nil;
    }

    resultString = [NSMutableString string];
    [resultType setVariableName:name];
    [resultString appendString:[NSString spacesIndentedToLevel:level spacesPerLevel:4]];
    [resultString appendString:[resultType formattedString:nil formatter:self level:level]];

    //free_allocated_methods();
    //free_allocated_types();
    [aParser release];

    //NSLog(@"<  %s", _cmd);
    return resultString;
}

- (NSString *)formatMethodName:(NSString *)methodName type:(NSString *)type;
{
    CDTypeParser *aParser;
    NSArray *methodTypes;
    NSMutableString *resultString;

    aParser = [[CDTypeParser alloc] initWithType:type];
    methodTypes = [aParser parseMethodType];
    [aParser release];

    if (methodTypes == nil || [methodTypes count] == 0) {
        return nil;
    }

    resultString = [NSMutableString string];
    {
        int count, index;
        BOOL noMoreTypes;
        CDMethodType *aMethodType;
        NSScanner *scanner;

        count = [methodTypes count];
        index = 0;
        noMoreTypes = NO;

        aMethodType = [methodTypes objectAtIndex:index];
        if ([[aMethodType type] isIDType] == NO) {
            NSString *str;

            [resultString appendString:@"("];
            // TODO (2003-12-11): Don't expect anonymous structures anywhere in method types.
            str = [[aMethodType type] formattedString:nil formatter:self level:0];
            if (str != nil)
                [resultString appendFormat:@"%@", str];
            [resultString appendString:@")"];
        }

        index += 3;

        scanner = [[NSScanner alloc] initWithString:methodName];
        while ([scanner isAtEnd] == NO) {
            NSString *str;

            // We can have unnamed paramenters, :::
            if ([scanner scanUpToString:@":" intoString:&str] == YES) {
                //NSLog(@"str += '%@'", str);
                [resultString appendString:str];
            }
            if ([scanner scanString:@":" intoString:NULL] == YES) {
                NSString *typeString;

                [resultString appendString:@":"];
                if (index >= count) {
                    noMoreTypes = YES;
                } else {
                    NSString *ch;

                    aMethodType = [methodTypes objectAtIndex:index];
                    typeString = [[aMethodType type] formattedString:nil formatter:self level:0];
                    if ([[aMethodType type] isIDType] == NO)
                        [resultString appendFormat:@"(%@)", typeString];
                    [resultString appendFormat:@"fp%@", [aMethodType offset]];

                    ch = [scanner peekCharacter];
                    // if next character is not ':' nor EOS then add space
                    if (ch != nil && [ch isEqual:@":"] == NO)
                        [resultString appendString:@" "];
                    index++;
                }
            }
        }

        if (noMoreTypes == YES) {
            NSLog(@" /* Error: Ran out of types for this method. */");
        }
    }

    return resultString;
}

- (NSString *)typedefNameForStruct:(NSString *)structTypeString;
{
    NSLog(@"%s, structTypeString: %@", _cmd, structTypeString);
    if ([nonretainedDelegate respondsToSelector:_cmd]);
        return [nonretainedDelegate typedefNameForStruct:structTypeString];

    return nil;
}

@end
