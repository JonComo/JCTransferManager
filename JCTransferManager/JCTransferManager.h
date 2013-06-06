//
//  JCTransferManager.h
//  Underground
//
//  Created by Jon Como on 5/8/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AmazonS3Client;

typedef void (^EndBackgroundBlock)(void);
typedef void (^ProgressBlock)(NSString *key, int bytesUploaded, int bytesTotal);
typedef void (^CompletionBlock)(NSString *key, BOOL success, EndBackgroundBlock endBlock);

@interface JCTransferManager : NSObject

@property (nonatomic, strong) AmazonS3Client *client;
@property (nonatomic, strong) NSMutableArray *files;

+(JCTransferManager *)sharedManager;

-(void)authorizeWithKey:(NSString *)key secretKey:(NSString *)secretKey bucket:(NSString *)bucket;

-(void)uploadData:(NSArray *)dataArray filenames:(NSArray *)filenames progress:(ProgressBlock)progress completion:(CompletionBlock)completion;

-(void)endBackgroundProcess;

@end