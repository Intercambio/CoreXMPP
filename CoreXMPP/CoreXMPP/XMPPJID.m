//
//  XMPPJID.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 18.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPJID.h"

@implementation XMPPJID

+ (NSRegularExpression *)regularExpression
{
    static NSRegularExpression *expression;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __unused NSError *error = nil;
        expression = [NSRegularExpression regularExpressionWithPattern:@"^(([^@]+)@)?([^/]+)(/(.*))?$"
                                                               options:NSRegularExpressionCaseInsensitive
                                                                 error:&error];
        NSAssert(expression, [error localizedDescription]);
    });
    return expression;
}

#pragma mark Life-cycle

- (nullable instancetype)initWithString:(nullable NSString *)string
{
    if (string == nil) {
        return nil;
    }

    NSRegularExpression *expression = [[self class] regularExpression];

    NSArray *matches = [expression matchesInString:string
                                           options:NSMatchingReportCompletion
                                             range:NSMakeRange(0, [string length])];
    if ([matches count] == 1) {
        NSTextCheckingResult *match = [matches firstObject];
        NSString *user = [match rangeAtIndex:2].length == 0 ? nil : [string substringWithRange:(NSRange)[match rangeAtIndex:2]];
        NSString *host = [match rangeAtIndex:3].length == 0 ? nil : [string substringWithRange:(NSRange)[match rangeAtIndex:3]];
        NSString *resource = [match rangeAtIndex:5].length == 0 ? nil : [string substringWithRange:(NSRange)[match rangeAtIndex:5]];

        if (host) {
            return [self initWithUser:user host:host resource:resource];
        }
    }

    return nil;
}

- (nullable instancetype)initWithUser:(nullable NSString *)user
                                 host:(nonnull NSString *)host
                             resource:(nullable NSString *)resource
{
    self = [super init];
    if (self) {
        _user = [user copy];
        _host = [host copy];
        _resource = [resource copy];
    }
    return self;
}

#pragma mark String Value

- (NSString *)stringValue
{
    if (self.user) {
        if (self.resource) {
            return [NSString stringWithFormat:@"%@@%@/%@", self.user, self.host, self.resource];
        } else {
            return [NSString stringWithFormat:@"%@@%@", self.user, self.host];
        }
    } else {
        return self.host;
    }
}

#pragma mark Bare or Full JID

- (nonnull instancetype)bareJID
{
    return [[XMPPJID alloc] initWithUser:self.user host:self.host resource:nil];
}

- (nonnull instancetype)fullJIDWithResource:(NSString *)resource
{
    return [[XMPPJID alloc] initWithUser:self.user host:self.host resource:resource];
}

#pragma mark NSObject

- (NSString *)description
{
    return self.stringValue;
}

- (NSUInteger)hash
{
    return [_user hash] + [_host hash] + [_resource hash];
}

- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[XMPPJID class]]) {
        return [[self stringValue] isEqualToString:[object stringValue]];
    }
    return NO;
}

#pragma mark NSCopying

- (id)copyWithZone:(nullable NSZone *)zone
{
    return self;
}

#pragma mark Deprecated

+ (nullable instancetype)JIDFromString:(nullable NSString *)string
{
    return [[self alloc] initWithString:string];
}

- (nonnull instancetype)JIDWithResource:(NSString *)resource
{
    return [self fullJIDWithResource:resource];
}

@end
