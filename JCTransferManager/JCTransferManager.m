//
//  JCTransferManager.m
//  Underground
//
//  Created by Jon Como on 5/8/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "JCTransferManager.h"
#import "JCTransferObject.h"
#import <AWSS3/AWSS3.h>
#import <AWSS3/S3TransferManager.h>
#import <AWSRuntime/AWSRuntime.h>

@interface JCTransferManager () <AmazonServiceRequestDelegate>
{
    S3TransferManager *transferManager;
    NSString *bucketName;
    
    ProgressBlock progressBlock;
    CompletionBlock completionBlock;
    
    __block UIBackgroundTaskIdentifier background_task;
}

@end

@implementation JCTransferManager

+(JCTransferManager *)sharedManager
{
    static JCTransferManager *sharedManager;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    
    return sharedManager;
}

-(id)init
{
    if (self = [super init]) {
        //init
        _files = [NSMutableArray array];
    }
    
    return self;
}

-(void)authorizeWithKey:(NSString *)key secretKey:(NSString *)secretKey bucket:(NSString *)bucket
{
    self.client = [[AmazonS3Client alloc] initWithAccessKey:key withSecretKey:secretKey];
    transferManager = [S3TransferManager new];
    transferManager.delegate = self;
    transferManager.s3 = self.client;
    bucketName = bucket;
}

-(void)uploadData:(NSArray *)dataArray filenames:(NSArray *)filenames progress:(ProgressBlock)progress completion:(CompletionBlock)completion
{
    progressBlock = progress;
    completionBlock = completion;
    
    NSMutableArray *putObjectRequests = [NSMutableArray array];
    
    for (u_int i = 0; i<dataArray.count; i++)
    {
        NSString *filename = filenames[i];
        NSData *data = dataArray[i];
        
        S3PutObjectRequest *putObject = [[S3PutObjectRequest alloc] initWithKey:filename inBucket:bucketName];
        
        [putObject setData:data];
        putObject.requestTag = filename;
        
        [self.files addObject:[[JCTransferObject alloc] initWithFilename:filename data:data]];
        [putObjectRequests addObject:putObject];
    }
    
    [self runInBackgroundIfPossible:^{
        for (S3PutObjectRequest *request in putObjectRequests)
            [transferManager upload:request];
    }];
}

-(void)runInBackgroundIfPossible:(void(^)(void))block
{
    if ([[UIDevice currentDevice] isMultitaskingSupported]) {
        
        background_task = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler: ^ {
            [[UIApplication sharedApplication] endBackgroundTask:background_task];
            background_task = UIBackgroundTaskInvalid;
        }];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (block) block();
        });
        
        return;
    }
    
    if (block) block();
}

-(void)endBackgroundProcess
{
    [[UIApplication sharedApplication] endBackgroundTask:background_task];
    background_task = UIBackgroundTaskInvalid;
}

-(void)request:(AmazonServiceRequest *)request didReceiveResponse:(NSURLResponse *)response
{
}

-(void)request:(AmazonServiceRequest *)request didReceiveData:(NSData *)data
{
}

-(void)request:(AmazonServiceRequest *)request didSendData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (progressBlock) progressBlock(request.requestTag, totalBytesWritten, totalBytesExpectedToWrite);
    });
}

-(void)request:(AmazonServiceRequest *)request didCompleteWithResponse:(AmazonServiceResponse *)response
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (completionBlock) completionBlock(request.requestTag, YES, ^{ [self endBackgroundProcess]; });
    });
    
    [self.files removeObject:[self objectWithName:request.requestTag]];
    
    if (self.files.count == 0)
        [self endBackgroundProcess];
}

-(void)request:(AmazonServiceRequest *)request didFailWithError:(NSError *)error
{
    //Still keep trying to upload it.
    //[self endBackgroundProcess];
}

-(JCTransferObject *)objectWithName:(NSString *)name
{
    JCTransferObject *object;
    
    for (JCTransferObject *transfer in self.files){
        if ([object.name isEqualToString:name]){
            object = transfer;
            break;
        }
    }
    
    return object;
}

@end
