//
//  JCTransferManager.m
//  Underground
//
//  Created by Jon Como on 5/8/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "JCTransferManager.h"
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
    
    int filesToUpload;
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
    filesToUpload = dataArray.count;
    
    [self runInBackgroundIfPossible:^{
        for (u_int i = 0; i<dataArray.count; i++){
            [transferManager uploadData:dataArray[i] bucket:bucketName key:filenames[i]];
        }
    }];
}

-(void)cancelUpload
{
    filesToUpload = 0;
    
    progressBlock = nil;
    completionBlock = nil;
    
    transferManager = nil;
}

-(void)runInBackgroundIfPossible:(void(^)(void))block
{
    if ([[UIDevice currentDevice] isMultitaskingSupported]) {
        
        background_task = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler: ^ {
            [[UIApplication sharedApplication] endBackgroundTask: background_task];
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
        if (progressBlock) progressBlock(((float)totalBytesWritten / (float)totalBytesExpectedToWrite) * 100.0f / (filesToUpload), totalBytesWritten, totalBytesExpectedToWrite);
    });
}

-(void)request:(AmazonServiceRequest *)request didCompleteWithResponse:(AmazonServiceResponse *)response
{
    filesToUpload --;
    
    if (filesToUpload == 0){
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionBlock) completionBlock(YES, ^{ [self endBackgroundProcess]; });
        });
    }
}

-(void)request:(AmazonServiceRequest *)request didFailWithError:(NSError *)error
{
    if (completionBlock) completionBlock(NO, nil);
    [self endBackgroundProcess];
}

@end
