//
//  ZJDownloadSessionManager.h
//  chanbendong
//
//  Created by 吴孜健 on 2018/1/23.
//  Copyright © 2018年 吴孜健. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZJDownloadDelegate.h"

/**<下载管理类 封装NSURLSessionDownloadTask*/
@interface ZJDownloadSessionManager : NSObject <NSURLSessionDownloadDelegate>

//下载代理
@property (nonatomic, weak) id<ZJDownloadDelegate> delelgate;

// 等待中的模型 只读
@property (nonatomic, strong,readonly) NSMutableArray *waitingDownloadModels;

// 下载中的模型 只读
@property (nonatomic, strong,readonly) NSMutableArray *downloadingModels;

// 最大下载数
@property (nonatomic, assign) NSInteger maxDownloadCount;

// 等待下载队列 先进先出 默认YES， 当NO时，先进后出
@property (nonatomic, assign) BOOL resumeDownloadFIFO;

// 全部并发 默认NO, 当YES时，忽略maxDownloadCount
@property (nonatomic, assign) BOOL isBatchDownload;

//后台session configure
@property (nonatomic, copy) NSString *backgroundConfigure;
@property (nonatomic, copy) void (^backgroundSessionCompletionHandler)(void);

//后台下载完成后调用 返回文件保存路径filePath
@property (nonatomic, copy) NSString *(^backgroundSessionDownloadCompleteBlock)(NSString *downloadURL);

//单例
+ (ZJDownloadSessionManager *)manager;

//配置后台session
- (void)configureBackroundSession;

//获取正在下载模型
- (ZJDownloadModel *)downloadingModelForURLString:(NSString *)URLString;

//获取已经下载的进度
- (ZJDownloadProgress *)progressWithDownloadModel:(ZJDownloadModel *)downloadModel;

//获取后台运行task
- (NSURLSessionDownloadTask *)backgroundSessionTasksWithDownloadModel:(ZJDownloadModel *)downloadModel;

//是否已经下载
- (BOOL)isDownloadCompletedWithDownloadModel:(ZJDownloadModel *)downloadModel;

//取消所有完成或失败后台task
- (void)cancelAllBackgroundSessionTasks;

//开始下载
- (ZJDownloadModel *)startDownloadURLString:(NSString *)URLString toDestinationPath:(NSString *)destinationPath progress:(ZJDownloadProgressBlock)progress state:(ZJDownloadStateBlock)state;

//开始下载
- (void)startWithDownloadModel:(ZJDownloadModel *)downloadModel;

//开始下载
- (void)startWithDownloadModel:(ZJDownloadModel *)downloadModel progress:(ZJDownloadProgressBlock)progress state:(ZJDownloadStateBlock)state;

//恢复下载(如果该model暂停下载，否则重新下载)
- (void)resumeWithDownloadModel:(ZJDownloadModel *)downloadModel;

//暂停下载
- (void)suspendWithDownloadModel:(ZJDownloadModel *)downloadModel;

//取消下载
- (void)cancelWithDownloadModel:(ZJDownloadModel *)downloadModel;

//删除下载
- (void)deleteFileWithDownloadModel:(ZJDownloadModel *)downloadModel;

@end
