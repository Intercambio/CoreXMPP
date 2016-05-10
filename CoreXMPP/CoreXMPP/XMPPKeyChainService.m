//
//  XMPPKeyChainService.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 19.02.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Security/Security.h>

#import "XMPPJID.h"
#import "XMPPKeyChainItemAttributes.h"

#import "XMPPKeyChainService.h"

@implementation XMPPKeyChainService

#pragma mark Life-cycle

- (instancetype)initWithServiceName:(NSString *)serviceName
{
    NSParameterAssert(serviceName);
    self = [super init];
    if (self) {
        _serviceName = serviceName;
    }
    return self;
}

#pragma mark Managing Identities

- (NSArray *)identities
{
    NSMutableDictionary *query = [[NSMutableDictionary alloc] init];

    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [query setObject:self.serviceName forKey:(__bridge id)kSecAttrService];
    [query setObject:(__bridge id)kSecMatchLimitAll forKey:(__bridge id)kSecMatchLimit];
    [query setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnAttributes];

    CFArrayRef _result = nil;
    OSStatus resultCode = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&_result);

    if (resultCode == errSecItemNotFound) {
        return @[];
    } else if (resultCode == noErr) {
        NSMutableArray *identities = [[NSMutableArray alloc] init];
        NSArray *result = (__bridge NSArray *)_result;
        [result enumerateObjectsUsingBlock:^(NSDictionary *attributes, NSUInteger idx, BOOL *_Nonnull stop) {
            XMPPJID *JID = [XMPPJID JIDFromString:[attributes objectForKey:(__bridge id)kSecAttrAccount]];
            [identities addObject:JID];
        }];
        CFRelease(_result);

        return identities;
    } else {
        return nil;
    }
}

- (void)addIdentitiyWithJID:(XMPPJID *)JID
{
    NSMutableDictionary *query = [[NSMutableDictionary alloc] init];

    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [query setObject:(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly forKey:(__bridge id)kSecAttrAccessible];
    [query setObject:self.serviceName forKey:(__bridge id)kSecAttrService];
    [query setObject:[[JID bareJID] stringValue] forKey:(__bridge id)kSecAttrAccount];

    CFMutableDictionaryRef outDictionary = nil;
    OSStatus resultCode = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&outDictionary);

    NSAssert(resultCode == noErr || resultCode == errSecItemNotFound, @"Failed to get item form the key chain.");

    if (resultCode == errSecItemNotFound) {

        [query setObject:[[JID bareJID] stringValue] forKey:(__bridge id)kSecAttrLabel];
        [query setObject:@(YES) forKey:(__bridge id)kSecAttrIsInvisible];

        resultCode = SecItemAdd((__bridge CFDictionaryRef)query, NULL);

        NSAssert(resultCode == noErr, @"Failed to store an item in the key chain");
    }
}

- (void)removeIdentityWithJID:(XMPPJID *)JID
{
    NSMutableDictionary *query = [[NSMutableDictionary alloc] init];

    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [query setObject:self.serviceName forKey:(__bridge id)kSecAttrService];
    [query setObject:[[JID bareJID] stringValue] forKey:(__bridge id)kSecAttrAccount];

    __unused OSStatus resultCode = SecItemDelete((__bridge CFDictionaryRef)query);
    NSAssert(resultCode == noErr || resultCode == errSecItemNotFound, @"Failed to delete key chain item.");
}

#pragma mark Attributes

- (XMPPKeyChainItemAttributes *)attributesForIdentityWithJID:(XMPPJID *)JID
{
    NSMutableDictionary *query = [[NSMutableDictionary alloc] init];

    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [query setObject:self.serviceName forKey:(__bridge id)kSecAttrService];
    [query setObject:[[JID bareJID] stringValue] forKey:(__bridge id)kSecAttrAccount];
    [query setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnAttributes];

    CFDictionaryRef _result = nil;
    OSStatus resultCode = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&_result);

    if (resultCode == errSecItemNotFound) {
        return nil;
    } else if (resultCode == noErr) {

        NSDictionary *result = (__bridge NSDictionary *)_result;

        BOOL suspended = [[result objectForKey:(__bridge id)kSecAttrIsInvisible] boolValue];
        NSData *optionsData = [result objectForKey:(__bridge id)kSecAttrGeneric];
        NSDictionary *options = optionsData ? [NSKeyedUnarchiver unarchiveObjectWithData:optionsData] : @{};

        XMPPKeyChainItemAttributes *attributes = [[XMPPKeyChainItemAttributes alloc] initWithOptions:options
                                                                                           suspended:suspended];

        CFRelease(_result);

        return attributes;
    } else {
        return nil;
    }
}

- (void)setAttributes:(XMPPKeyChainItemAttributes *)attributes forIdentityWithJID:(XMPPJID *)JID
{
    NSMutableDictionary *query = [[NSMutableDictionary alloc] init];

    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [query setObject:self.serviceName forKey:(__bridge id)kSecAttrService];
    [query setObject:[[JID bareJID] stringValue] forKey:(__bridge id)kSecAttrAccount];

    NSData *optionsData = [NSKeyedArchiver archivedDataWithRootObject:attributes.options];

    NSDictionary *values = @{(__bridge id)kSecAttrIsInvisible : @(attributes.suspended),
                             (__bridge id)
                             kSecAttrGeneric : optionsData };

    __unused OSStatus resultCode = SecItemUpdate((__bridge CFDictionaryRef)query,
                                                 (__bridge CFDictionaryRef)values);

    NSAssert(resultCode == noErr, @"Failed to update key chain item (attributes).");
}

#pragma mark Password

- (NSString *)passwordForIdentityWithJID:(XMPPJID *)JID
{
    NSMutableDictionary *query = [[NSMutableDictionary alloc] init];

    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [query setObject:self.serviceName forKey:(__bridge id)kSecAttrService];
    [query setObject:[[JID bareJID] stringValue] forKey:(__bridge id)kSecAttrAccount];
    [query setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];

    CFDataRef _data = nil;
    OSStatus resultCode = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&_data);

    if (resultCode == errSecItemNotFound) {
        return nil;
    } else if (resultCode == noErr) {

        NSData *data = (__bridge NSData *)_data;

        NSString *password = [data length] > 0 ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;

        if (_data) {
            CFRelease(_data);
        }

        return password;
    } else {
        return nil;
    }
}

- (void)setPassword:(NSString *)password forIdentityWithJID:(XMPPJID *)JID
{
    NSMutableDictionary *query = [[NSMutableDictionary alloc] init];

    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [query setObject:self.serviceName forKey:(__bridge id)kSecAttrService];
    [query setObject:[[JID bareJID] stringValue] forKey:(__bridge id)kSecAttrAccount];

    NSData *passwordData = password ? [password dataUsingEncoding:NSUTF8StringEncoding] : [@"" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *values = @{(__bridge id)kSecValueData : passwordData};

    __unused OSStatus resultCode = SecItemUpdate((__bridge CFDictionaryRef)query,
                                                 (__bridge CFDictionaryRef)values);

    NSAssert(resultCode == noErr, @"Failed to update key chain item (password).");
}

@end
