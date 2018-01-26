//
//  ZJDownloadDataManager.h
//  chanbendong
//
//  Created by 吴孜健 on 2018/1/18.
//  Copyright © 2018年 吴孜健. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZJDownloadDelegate.h"
#import "ZJDownloadModel.h"

@interface ZJDownloadDataManager : NSObject <NSURLSessionDelegate>

@property (nonatomic, weak) id<ZJDownloadDelegate> delegate;/**<下载代理*/
@property (nonatomic, strong, readonly) NSMutableArray *waitingDownloadModels;/**<等待中的模型*/
@property (nonatomic, strong, readonly) NSMutableArray *downloadingModels;/**<下载中的模型*/
@property (nonatomic, assign) NSInteger maxDownloadCount;/**<最大下载数*/
@property (nonatomic, assign) BOOL resumeDownloadFIFO;/**<等待下载队列，默认YES为先进先出, NO为，先进后出*/
@property (nonatomic, assign) BOOL isBatchDownload;/**<全部并发，默认为NO，当YES时，忽略maxDownloadCount*/


+ (ZJDownloadDataManager *)manager;

/**<开始下载 --指定下载地址*/
- (ZJDownloadModel *)startDownloadURLString:(NSString *)URLString toDestinationPath:(NSString *)destinationPath progress:(ZJDownloadProgressBlock)progress state:(ZJDownloadStateBlock)state;

/**<开始下载 --默认地址*/
- (void)startWithDownloadModel:(ZJDownloadModel *)downloadModel progress:(ZJDownloadProgressBlock)progress state:(ZJDownloadStateBlock)state;

/**<开始下载*/
- (void)startWithDownloadModel:(ZJDownloadModel *)downloadModel;

/**<恢复下载 (除非确定对这个model进行了suspend，否则使用start)*/
- (void)resumeWithDownloadModel:(ZJDownloadModel *)downloadModel;

/**<暂停下载*/
- (void)suspendWithDownloadModel:(ZJDownloadModel *)downloadModel;

/**<取消下载*/
- (void)cancelWithDownloadModel:(ZJDownloadModel *)downloadModel;

/**<根据下载模型删除下载*/
- (void)deleteFileWithDownloadModel:(ZJDownloadModel *)downloadModel;

/**<根据文件地址删除下载*/
- (void)deleteAllFileWithDownloadDirectory:(NSString *)downloadDirectory;

/**<获取正在下载模型*/
- (ZJDownloadModel *)downloadingModelForURLString:(NSString *)URLString;

/**<获取本地下载模型的进度*/
- (ZJDownloadProgress *)progressWithDownloadModel:(ZJDownloadModel *)downloadModel;

/**<是否已经下载*/
- (BOOL)isDownloadCompletedWithDownloadModel:(ZJDownloadModel *)downloadModel;


@end
