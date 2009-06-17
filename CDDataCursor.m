//  This file is part of __APPNAME__, __SHORT_DESCRIPTION__.
//  Copyright (C) 2008 __OWNER__.  All rights reserved.

#import "CDDataCursor.h"

@implementation CDDataCursor

- (id)initWithData:(NSData *)someData;
{
    if ([super init] == nil)
        return nil;

    data = [someData retain];
    offset = 0;
    byteOrder = CDByteOrderLittleEndian;

    return self;
}

- (void)dealloc;
{
    [data release];

    [super dealloc];
}

- (NSData *)data;
{
    return data;
}

- (const void *)bytes;
{
    return [data bytes];
}

- (NSUInteger)offset;
{
    return offset;
}

// Return NO on failure.
- (void)seekToPosition:(NSUInteger)newOffset;
{
    if (newOffset <= [data length]) {
        offset = newOffset;
    } else {
        [NSException raise:NSRangeException format:@"Trying to seek past end of data."];
    }
}

- (void)advanceByLength:(NSUInteger)length;
{
    [self seekToPosition:offset + length];
}

- (NSUInteger)remaining;
{
    return [data length] - offset;
}

- (uint8_t)readByte;
{
    const uint8_t *ptr;

    ptr = [data bytes] + offset;
    offset += 1;

    return *ptr;
}

- (uint16_t)readLittleInt16;
{
    uint16_t result;

    if (offset + sizeof(result) <= [data length]) {
        result = OSReadLittleInt16([data bytes], offset);
        offset += sizeof(result);
    } else {
        [NSException raise:NSRangeException format:@"Trying to read past end in %s", _cmd];
        result = 0;
    }

    return result;
}

- (uint32_t)readLittleInt32;
{
    uint32_t result;

    if (offset + sizeof(result) <= [data length]) {
        result = OSReadLittleInt32([data bytes], offset);
        offset += sizeof(result);
    } else {
        [NSException raise:NSRangeException format:@"Trying to read past end in %s", _cmd];
        result = 0;
    }

    return result;
}

- (uint64_t)readLittleInt64;
{
    uint64_t result;

    if (offset + sizeof(result) <= [data length]) {
        result = OSReadLittleInt64([data bytes], offset);
        offset += sizeof(result);
    } else {
        [NSException raise:NSRangeException format:@"Trying to read past end in %s", _cmd];
        result = 0;
    }

    return result;
}

- (uint16_t)readBigInt16;
{
    uint16_t result;

    if (offset + sizeof(result) <= [data length]) {
        result = OSReadBigInt16([data bytes], offset);
        offset += sizeof(result);
    } else {
        [NSException raise:NSRangeException format:@"Trying to read past end in %s", _cmd];
        result = 0;
    }

    return result;
}

- (uint32_t)readBigInt32;
{
    uint32_t result;

    if (offset + sizeof(result) <= [data length]) {
        result = OSReadBigInt32([data bytes], offset);
        offset += sizeof(result);
    } else {
        [NSException raise:NSRangeException format:@"Trying to read past end in %s", _cmd];
        result = 0;
    }

    return result;
}

- (uint64_t)readBigInt64;
{
    uint64_t result;

    if (offset + sizeof(result) <= [data length]) {
        result = OSReadBigInt64([data bytes], offset);
        offset += sizeof(result);
    } else {
        [NSException raise:NSRangeException format:@"Trying to read past end in %s", _cmd];
        result = 0;
    }

    return result;
}

- (float)readLittleFloat32;
{
    uint32_t val;

    val = [self readLittleInt32];
    return *(float *)&val;
}

- (float)readBigFloat32;
{
    uint32_t val;

    val = [self readBigInt32];
    return *(float *)&val;
}

- (double)readLittleFloat64;
{
    uint32_t v1, v2, *ptr;
    double dval;

    v1 = [self readLittleInt32];
    v2 = [self readLittleInt32];
    ptr = (uint32_t *)&dval;
    *ptr++ = v1;
    *ptr++ = v2;

    return dval;
}

- (void)appendBytesOfLength:(NSUInteger)length intoData:(NSMutableData *)targetData;
{
    if (offset + length <= [data length]) {
        [targetData appendBytes:[self bytes] length:length];
        offset += length;
    } else {
        [NSException raise:NSRangeException format:@"Trying to read past end in %s", _cmd];
    }
}

- (BOOL)isAtEnd;
{
    return offset >= [data length];
}

- (CDByteOrder)byteOrder;
{
    return byteOrder;
}

- (void)setByteOrder:(CDByteOrder)newByteOrder;
{
    byteOrder = newByteOrder;
}

//
// Read using the current byteOrder
//

- (uint16_t)readInt16;
{
    if (byteOrder == CDByteOrderLittleEndian)
        return [self readLittleInt16];

    return [self readBigInt16];
}

- (uint32_t)readInt32;
{
    if (byteOrder == CDByteOrderLittleEndian)
        return [self readLittleInt32];

    return [self readBigInt32];
}

- (uint64_t)readInt64;
{
    if (byteOrder == CDByteOrderLittleEndian)
        return [self readLittleInt64];

    return [self readBigInt64];
}

@end
