//
//  XMPPStanza.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 09.08.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPStanza.h"
#import "XMPPJID.h"

@implementation XMPPStanza

- (XMPPJID *)to
{
    NSString *JIDString = [self valueForAttribute:@"to"];
    if (JIDString) {
        return [[XMPPJID alloc] initWithString:JIDString];
    } else {
        return nil;
    }
}

- (void)setTo:(XMPPJID *)to
{
    NSString *JIDString = [to stringValue];
    [self setValue:JIDString forAttribute:@"to"];
}

- (XMPPJID *)from
{
    NSString *JIDString = [self valueForAttribute:@"from"];
    if (JIDString) {
        return [[XMPPJID alloc] initWithString:JIDString];
    } else {
        return nil;
    }
}

- (void)setFrom:(XMPPJID *)from
{
    NSString *JIDString = [from stringValue];
    [self setValue:JIDString forAttribute:@"from"];
}

- (NSString *)stanzaID
{
    return [self valueForAttribute:@"id"];
}

- (void)setStanzaID:(NSString *)stanzaID
{
    [self setValue:stanzaID forAttribute:@"id"];
}

@end
