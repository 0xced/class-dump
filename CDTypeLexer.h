#import <Foundation/NSObject.h>

#define TK_NUMBER 257
#define TK_IDENTIFIER 258
#define T_NAMED_OBJECT 259

@class NSCharacterSet, NSScanner;

@interface CDTypeLexer : NSObject
{
    NSScanner *scanner;
    BOOL isInIdentifierState;
    NSString *lexText;

    NSCharacterSet *identifierStartSet;
    NSCharacterSet *identifierSet;
}

- (id)initWithString:(NSString *)aString;
- (void)dealloc;

- (BOOL)isInIdentifierState;
- (void)setIsInIdentifierState:(BOOL)newFlag;

- (int)nextToken;

- (NSString *)lexText;
- (void)_setLexText:(NSString *)newString;

@end
