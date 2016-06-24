//
//  XMPPConnectionStub.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 20.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <CoreXMPP/CoreXMPP.h>

@class PXElement;

@interface XMPPConnectionStub : NSObject <XMPPConnection>
- (void)onHandleDocument:(void (^)(PXDocument *document, void (^completion)(NSError *), id<XMPPDocumentHandler> responseHandler))callback;
@end
