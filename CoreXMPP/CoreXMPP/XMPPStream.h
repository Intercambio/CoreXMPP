//
//  XMPPStream.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 04.11.15.
//  Copyright © 2015 Tobias Kräntzer. 
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

#import <Foundation/Foundation.h>
#import <PureXML/PureXML.h>

@class XMPPStream;

typedef NS_ENUM(NSUInteger, XMPPStreamState) {
    XMPPStreamStateClosed = 0,
    XMPPStreamStateDiscovering,
    XMPPStreamStateConnecting,
    XMPPStreamStateOpening,
    XMPPStreamStateOpen,
    XMPPStreamStateClosing,
    XMPPStreamStateDisconnecting
} NS_SWIFT_NAME(StreamState);

NS_SWIFT_NAME(StreamDelegate)
@protocol XMPPStreamDelegate <NSObject>
@optional
- (void)stream:(nonnull XMPPStream *)stream didOpenToHost:(nonnull NSString *)hostname withStreamId:(nonnull NSString *)streamId NS_SWIFT_NAME(stream(_:didOpen:id:));
- (void)stream:(nonnull XMPPStream *)stream didReceiveDocument:(nonnull PXDocument *)document NS_SWIFT_NAME(stream(_:didReceive:));
- (void)stream:(nonnull XMPPStream *)stream didFailWithError:(nonnull NSError *)error NS_SWIFT_NAME(stream(_:didFail:));
- (void)streamDidClose:(nonnull XMPPStream *)stream NS_SWIFT_NAME(streamDidClose(_:));
@end

NS_SWIFT_NAME(Stream)
@interface XMPPStream : NSObject

#pragma mark Life-cycle
- (nonnull instancetype)initWithHostname:(nonnull NSString *)hostname
                                 options:(nullable NSDictionary *)options;

#pragma mark Properties
@property (nonatomic, readonly) NSString *_Nonnull hostname;
@property (nonatomic, readwrite) NSDictionary *_Nonnull options;

#pragma mark Queue

// The methods (and properties) of the stream must be called on the queue. If not, the stream can end up in an unexpected state.
// The delegate will be called on this queue.
// If the queue is not set, the main queue will be used.
// Setting the queue after opening the stream results into undefined behavior.
@property (nonatomic, strong) dispatch_queue_t _Nullable queue;

#pragma mark Delegate
@property (nonatomic, weak) id<XMPPStreamDelegate> _Nullable delegate;

#pragma mark State
@property (nonatomic, readonly) XMPPStreamState state;

#pragma mark Managing Stream
- (void)open;
- (void)reopen;
- (void)close;
- (void)suspend;

#pragma mark Sending Document
- (void)sendDocument:(nonnull PXDocument *)document NS_SWIFT_NAME(send(_:));

@end
