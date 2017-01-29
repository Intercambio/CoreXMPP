//
//  XMPPConnectionStub.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 20.01.16.
//  Copyright © 2015, 2016, 2017 Tobias Kräntzer. 
//
//  This file is part of CoreXMPP.
//
//  CoreXMPP is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation, either version 3 of the License, or (at your option)
//  any later version.
//
//  CoreXMPP is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
//  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with
//  CoreXMPP. If not, see <http://www.gnu.org/licenses/>.
//
//  Linking this library statically or dynamically with other modules is making
//  a combined work based on this library. Thus, the terms and conditions of the
//  GNU General Public License cover the whole combination.
//
//  As a special exception, the copyright holders of this library give you
//  permission to link this library with independent modules to produce an
//  executable, regardless of the license terms of these independent modules,
//  and to copy and distribute the resulting executable under terms of your
//  choice, provided that you also meet, for each linked independent module, the
//  terms and conditions of the license of that module. An independent module is
//  a module which is not derived from or based on this library. If you modify
//  this library, you must extend this exception to your version of the library.
//

#import "XMPPConnectionStub.h"

@interface XMPPConnectionStub () {
    dispatch_queue_t _operationQueue;
    NSMutableArray *_onHandleStanzaCallbacks;
}

@end

@implementation XMPPConnectionStub

@synthesize connectionDelegate = _connectionDelegate;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _operationQueue = dispatch_queue_create("XMPPConnectionStub", DISPATCH_QUEUE_SERIAL);
        _onHandleStanzaCallbacks = [[NSMutableArray alloc] init];
    }
    return self;
}

#pragma mark XMPPConnection

- (void)handleDocument:(PXDocument *)document completion:(void (^)(NSError *))completion
{
    dispatch_async(_operationQueue, ^{
        void (^_callback)(PXDocument *document, void (^completion)(NSError *), id<XMPPDocumentHandler> responseHandler) = [_onHandleStanzaCallbacks firstObject];
        if (_callback) {
            [_onHandleStanzaCallbacks removeObjectAtIndex:0];
            dispatch_async(dispatch_get_main_queue(), ^{
                _callback(document, completion, _connectionDelegate);
            });
        } else {
            if (completion) {
                completion(nil);
            }
        }
    });
}

- (void)processPendingDocuments:(void (^)(NSError *))completion
{
    dispatch_async(_operationQueue, ^{
        if (completion) {
            completion(nil);
        }
    });
}

#pragma mark -

- (void)onHandleDocument:(void (^)(PXDocument *document, void (^completion)(NSError *), id<XMPPDocumentHandler> responseHandler))callback;
{
    dispatch_async(_operationQueue, ^{
        if (callback) {
            [_onHandleStanzaCallbacks addObject:callback];
        }
    });
}

@end
