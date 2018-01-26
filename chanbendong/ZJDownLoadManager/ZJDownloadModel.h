//
//  ZJDownloadModel.h
//  chanbendong
//
//  Created by 吴孜健 on 2018/1/18.
//  Copyright © 2018年 吴孜健. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSUInteger, ZJDownloadState) {
    ZJDownloadStateNone,/**<未下载或者下载删除*/
    ZJDownloadStateReadying,/**<等待下载*/
    ZJDownloadStateRunning,/**<正在下载*/
    ZJDownloadStateSuspended,/**<下载暂停*/
    ZJDownloadStateCompleted,/**<下载完成*/
    ZJDownloadStateFailed,/**<下载失败*/
};

@class ZJDownloadProgress;

typedef void (^ZJDownloadProgressBlock)(ZJDownloadProgress *progress);
typedef void (^ZJDownloadStateBlock)(ZJDownloadState state, NSString *filePath, NSError *error);

/**<下载原型*/
@interface ZJDownloadModel : NSObject

/**<下载地址*/
@property (nonatomic, strong) NSString *downloadURL;
/**<文件名, 默认nil 则为下载URL中的文件名*/
@property (nonatomic, strong) NSString *fileName;
/**<缓存文件目录，默认nil 则为manager缓存目录*/
@property (nonatomic, strong) NSString *downloadDirectory;


/**<task info*/

/**<下载状态*/
@property (nonatomic, assign) ZJDownloadState state;
/**<下载任务*/
@property (nonatomic, strong) NSURLSessionTask *task;
/**<文件流*/
@property (nonatomic, strong) NSOutputStream *stream;
/**<下载进度*/
@property (nonatomic, strong) ZJDownloadProgress *progress;
/**<下载路径 如果设置了downloadDirectory，文件下载完成后会移动到这个目录， 否则， 在manager默认cache目录里*/
@property (nonatomic, strong) NSString *filePath;
/**<下载时间*/
@property (nonatomic, strong) NSDate *downloadDate;
/**<手动取消当做暂停*/
@property (nonatomic, assign) BOOL manualCancel;
/**<downloadTask所需resumeData*/
@property (nonatomic, strong) NSData *resumeData;

/**<download block*/

/**<下载更新block*/
@property (nonatomic, copy) ZJDownloadProgressBlock progressBlock;
/**<下载状态更新block*/
@property (nonatomic, copy) ZJDownloadStateBlock stateBlock;


- (instancetype)initWithUrlString:(NSString *)URLString;


/**
 初始化方法

 @param URLString 下载地址
 @param filePath 缓存地址， 当为nil时缓存到cache
 @return self
 */
- (instancetype)initWithUrlString:(NSString *)URLString filePath:(NSString *)filePath;

@end

/**<下载进度*/
@interface ZJDownloadProgress : NSObject

/**<续传大小*/
@property (nonatomic, assign) int64_t resumeBytesWritten;
/**<这次写入的数量*/
@property (nonatomic, assign) int64_t bytesWritten;
/**<已下载的数量*/
@property (nonatomic, assign) int64_t totalBytesWritten;
/**<文件的总大小*/
@property (nonatomic, assign) int64_t totalBytesExpectedToWrite;
/**<下载进度*/
@property (nonatomic, assign) float progress;
/**<下载速度*/
@property (nonatomic, assign) float speed;
/**<下载剩余时间*/
@property (nonatomic, assign) int remainingTime;

@end
