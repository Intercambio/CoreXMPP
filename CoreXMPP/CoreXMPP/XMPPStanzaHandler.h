//
//  XMPPStanzaHandler.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 25.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PXElement;

@protocol XMPPStanzaHandler <NSObject>
- (void)handleStanza:(PXElement *)stanza completion:(void (^)(NSError *error))completion;
@end
