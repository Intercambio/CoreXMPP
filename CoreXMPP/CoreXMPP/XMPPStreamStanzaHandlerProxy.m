//
//  XMPPStreamStanzaHandlerProxy.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 25.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPStreamStanzaHandlerProxy.h"
#import "XMPPError.h"

@implementation XMPPStreamStanzaHandlerProxy

- (instancetype)initWithStream:(XMPPStream *)stream
{
    self = [super init];
    if (self) {
        _stream = stream;
    }
    return self;
}

- (void)handleStanza:(PXElement *)stanza completion:(void (^)(NSError *))completion
{
    if (_stream.state != XMPPStreamStateOpen) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:XMPPDispatcherErrorDomain
                                                 code:XMPPDispatcherErrorCodeNotConnected
                                             userInfo:nil];
            completion(error);
        }
    } else {
        PXDocument *document = [[PXDocument alloc] initWithElement:stanza];
        [_stream sendDocument:document];
        if (completion) {
            completion(nil);
        }
    }
}

- (void)processPendingStanzas:(void (^)(NSError *))completion
{
    if (completion) {
        completion(nil);
    }
}

@end
