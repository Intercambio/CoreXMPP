//
//  XMPPDocumentHandler.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 25.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PXDocument;

@protocol XMPPDocumentHandler <NSObject>
- (void)handleDocument:(PXDocument *)document completion:(void (^)(NSError *error))completion;
- (void)processPendingDocuments:(void (^)(NSError *error))completion;
@end
