//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 2007 Steve Nygard.  All rights reserved.

#import "CDMultiFileVisitor.h"

#import "NSArray-Extensions.h"
#import "CDClassDump.h"
#import "CDClassFrameworkVisitor.h"
#import "CDSymbolReferences.h"
#import "CDOCClass.h"
#import "CDOCProtocol.h"
#import "CDOCIvar.h"

@implementation CDMultiFileVisitor

- (id)init;
{
    if ([super init] == nil)
        return nil;

    outputPath = nil;
    frameworkNamesByClassName = nil;

    return self;
}

- (void)dealloc;
{
    [outputPath release];
    [frameworkNamesByClassName release];

    [super dealloc];
}

- (NSString *)outputPath;
{
    return outputPath;
}

- (void)setOutputPath:(NSString *)newOutputPath;
{
    if (newOutputPath == outputPath)
        return;

    [outputPath release];
    outputPath = [newOutputPath retain];
}

- (void)createOutputPathIfNecessary;
{
    if (outputPath != nil) {
        NSFileManager *fileManager;
        BOOL isDirectory;

        fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:outputPath isDirectory:&isDirectory] == NO) {
            BOOL result;

            result = [fileManager createDirectoryAtPath:outputPath attributes:nil];
            if (result == NO) {
                NSLog(@"Error: Couldn't create output directory: %@", outputPath);
                return;
            }
        } else if (isDirectory == NO) {
            NSLog(@"Error: File exists at output path: %@", outputPath);
            return;
        }
    }
}

- (void)buildClassFrameworks;
{
    if (frameworkNamesByClassName == nil) {
        CDClassFrameworkVisitor *visitor;

        visitor = [[CDClassFrameworkVisitor alloc] init];
        [visitor setClassDump:classDump];
        [classDump recursivelyVisit:visitor];
        frameworkNamesByClassName = [[visitor frameworkNamesByClassName] retain];
        [visitor release];
    }
}

- (NSString *)frameworkForClassName:(NSString *)aClassName;
{
    return [frameworkNamesByClassName objectForKey:aClassName];
}

- (void)appendImportForClassName:(NSString *)aClassName;
{
    if (aClassName != nil) {
        NSString *classFramework;

        classFramework = [self frameworkForClassName:aClassName];
        if (classFramework == nil)
            [resultString appendFormat:@"#import \"%@.h\"\n\n", aClassName];
        else
            [resultString appendFormat:@"#import <%@/%@.h>\n\n", classFramework, aClassName];
    }
}

- (void)generateStructureHeader;
{
    NSString *filename;
    NSString *referenceString;

    [resultString setString:@""];
    [classDump appendHeaderToString:resultString];

    NSParameterAssert(symbolReferences == nil);
    symbolReferences = [[CDSymbolReferences alloc] init];
    referenceIndex = [resultString length];

    [classDump appendStructuresToString:resultString symbolReferences:symbolReferences];

    referenceString = [symbolReferences referenceString];
    if (referenceString != nil)
        [resultString insertString:referenceString atIndex:referenceIndex];

    filename = @"CDStructures.h";
    if (outputPath != nil)
        filename = [outputPath stringByAppendingPathComponent:filename];

    [[resultString dataUsingEncoding:NSUTF8StringEncoding] writeToFile:filename atomically:YES];

    [symbolReferences release];
    symbolReferences = nil;
}

- (void)willBeginVisiting;
{
    [super willBeginVisiting];

    [classDump appendHeaderToString:resultString];

    // TODO (2007-06-14): Make sure this generates no output files in this case.
    if ([classDump containsObjectiveCSegments] == NO)
        NSLog(@"Warning: This file does not contain any Objective-C runtime information.");

    [self buildClassFrameworks];
    [self createOutputPathIfNecessary];
    [self generateStructureHeader];
}

- (void)willVisitClass:(CDOCClass *)aClass;
{
    // First, we set up some context...
    [resultString setString:@""];
    [classDump appendHeaderToString:resultString];

    NSParameterAssert(symbolReferences == nil);
    symbolReferences = [[CDSymbolReferences alloc] init];

    [self appendImportForClassName:[aClass superClassName]];
    referenceIndex = [resultString length];

    // And then generate the regular output
    [super willVisitClass:aClass];
}

- (void)didVisitClass:(CDOCClass *)aClass;
{
    NSString *referenceString;
    NSString *filename;

    // Generate the regular output
    [super didVisitClass:aClass];

    // Then insert the imports and write the file.
    [symbolReferences removeClassName:[aClass name]];
    [symbolReferences removeClassName:[aClass superClassName]];
    referenceString = [symbolReferences referenceString];
    if (referenceString != nil)
        [resultString insertString:referenceString atIndex:referenceIndex];

    filename = [NSString stringWithFormat:@"%@.h", [aClass name]];
    if (outputPath != nil)
        filename = [outputPath stringByAppendingPathComponent:filename];

    [[resultString dataUsingEncoding:NSUTF8StringEncoding] writeToFile:filename atomically:YES];

    [symbolReferences release];
    symbolReferences = nil;
}

- (void)willVisitCategory:(CDOCCategory *)aCategory;
{
    // First, we set up some context...
    [resultString setString:@""];
    [classDump appendHeaderToString:resultString];

    NSParameterAssert(symbolReferences == nil);
    symbolReferences = [[CDSymbolReferences alloc] init];

    [self appendImportForClassName:[aCategory className]];
    referenceIndex = [resultString length];

    // And then generate the regular output
    [super willVisitCategory:aCategory];
}

- (void)didVisitCategory:(CDOCCategory *)aCategory;
{
    NSString *referenceString;
    NSString *filename;

    // Generate the regular output
    [super didVisitCategory:aCategory];

    // Then insert the imports and write the file.
    [symbolReferences removeClassName:[aCategory className]];
    referenceString = [symbolReferences referenceString];
    if (referenceString != nil)
        [resultString insertString:referenceString atIndex:referenceIndex];

    filename = [NSString stringWithFormat:@"%@-%@.h", [aCategory className], [aCategory name]];
    if (outputPath != nil)
        filename = [outputPath stringByAppendingPathComponent:filename];

    [[resultString dataUsingEncoding:NSUTF8StringEncoding] writeToFile:filename atomically:YES];

    [symbolReferences release];
    symbolReferences = nil;
}

- (void)willVisitProtocol:(CDOCProtocol *)aProtocol;
{
    [resultString setString:@""];
    [classDump appendHeaderToString:resultString];

    NSParameterAssert(symbolReferences == nil);
    symbolReferences = [[CDSymbolReferences alloc] init];

    //[self appendImportForClassName:[aClass superClassName]];
    referenceIndex = [resultString length];

    // And then generate the regular output
    [super willVisitProtocol:aProtocol];
}

- (void)didVisitProtocol:(CDOCProtocol *)aProtocol;
{
    NSString *referenceString;
    NSString *filename;

    // Generate the regular output
    [super didVisitProtocol:aProtocol];

    // Then insert the imports and write the file.
    //[symbolReferences removeClassName:[aClass name]];
    //[symbolReferences removeClassName:[aClass superClassName]];
    referenceString = [symbolReferences referenceString];
    if (referenceString != nil)
        [resultString insertString:referenceString atIndex:referenceIndex];

    filename = [NSString stringWithFormat:@"%@-Protocol.h", [aProtocol name]];
    if (outputPath != nil)
        filename = [outputPath stringByAppendingPathComponent:filename];

    [[resultString dataUsingEncoding:NSUTF8StringEncoding] writeToFile:filename atomically:YES];

    [symbolReferences release];
    symbolReferences = nil;
}

@end
