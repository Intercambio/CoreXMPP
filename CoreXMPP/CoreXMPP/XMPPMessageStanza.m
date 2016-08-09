//
//  XMPPMessageStanza.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 09.08.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPMessageStanza.h"
#import "XMPPMessageBody.h"

@implementation XMPPMessageStanza

+ (void)load
{
    [PXDocument registerElementClass:[XMPPMessageStanza class]
                    forQualifiedName:PXQN(@"jabber:client", @"message")];
}

+ (nonnull PXDocument *)documentWithMessageFrom:(nullable XMPPJID *)from to:(nullable XMPPJID *)to
{
    PXDocument *document = [[PXDocument alloc] initWithElementName:@"message"
                                                         namespace:@"jabber:client"
                                                            prefix:nil];
    if ([document.root isKindOfClass:[XMPPMessageStanza class]]) {
        XMPPMessageStanza *message = (XMPPMessageStanza *)[document root];
        message.from = from;
        message.to = to;
        message.stanzaID = [[[NSUUID UUID] UUIDString] lowercaseString];
    }
    return document;
}

- (XMPPMessageStanzaType)type
{
    NSString *typeString = [self valueForAttribute:@"type"];
    if ([typeString isEqualToString:@"chat"]) {
        return XMPPMessageStanzaTypeChat;
    } else if ([typeString isEqualToString:@"error"]) {
        return XMPPMessageStanzaTypeError;
    } else if ([typeString isEqualToString:@"groupchat"]) {
        return XMPPMessageStanzaTypeGroupchat;
    } else if ([typeString isEqualToString:@"headline"]) {
        return XMPPMessageStanzaTypeHeadline;
    } else if ([typeString isEqualToString:@"normal"]) {
        return XMPPMessageStanzaTypeNormal;
    } else {
        return XMPPMessageStanzaTypeUndefined;
    }
}

- (void)setType:(XMPPMessageStanzaType)type
{
    NSString *typeString = nil;
    switch (type) {
    case XMPPMessageStanzaTypeChat:
        typeString = @"chat";
        break;
    case XMPPMessageStanzaTypeError:
        typeString = @"error";
        break;
    case XMPPMessageStanzaTypeGroupchat:
        typeString = @"groupchat";
        break;
    case XMPPMessageStanzaTypeHeadline:
        typeString = @"headline";
        break;
    case XMPPMessageStanzaTypeNormal:
        typeString = @"normal";
        break;
    case XMPPMessageStanzaTypeUndefined:
    default:
        break;
    }
    [self setValue:typeString forAttribute:@"type"];
}

- (XMPPMessageBody *)body
{
    __block XMPPMessageBody *body = nil;
    [self enumerateChildrenUsingBlock:^(PXNode *child, BOOL *stop) {
        if ([child isKindOfClass:[XMPPMessageBody class]]) {
            body = (XMPPMessageBody *)child;
            *stop = YES;
        }
    }];
    return body;
}

- (void)setBody:(XMPPMessageBody *)body
{
    NSMutableArray *bodies = [[NSMutableArray alloc] init];
    [self enumerateChildrenUsingBlock:^(PXNode *child, BOOL *stop) {
        if ([child isKindOfClass:[XMPPMessageBody class]]) {
            [bodies addObject:child];
        }
    }];

    for (PXElement *element in bodies) {
        [element removeFromParent];
    }

    [self addElement:body];
}

@end
