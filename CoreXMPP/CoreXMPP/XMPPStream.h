//
//  XMPPStream.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 04.11.15.
//  Copyright © 2015 Tobias Kräntzer. All rights reserved.
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
