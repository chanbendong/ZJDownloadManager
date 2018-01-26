//
//  ZJDownloadSessionManager.m
//  chanbendong
//
//  Created by 吴孜健 on 2018/1/23.
//  Copyright © 2018年 吴孜健. All rights reserved.
//

#import "ZJDownloadSessionManager.h"
#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonDigest.h>
#import "NSURLSession+ZJCorrectedResumeData.h"

#define IS_IOS9BEFORE ([[[UIDevice currentDevice] systemVersion] floatValue] < 9.0)
#define IS_IOS8ORLATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8)
#define IS_IOS10ORLATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 10)

static NSString *const backgroundConfigure = @"ZJDownloadSessionManager.backgroundConfigure";

@interface ZJDownloadSessionManager ()

// >>>>>>>>>>>>>>>>>>>>>>>>>>  file info
// 文件管理
@property (nonatomic, strong) NSFileManager *fileManager;
// 缓存文件目录
@property (nonatomic, strong) NSString *downloadDirectory;

// >>>>>>>>>>>>>>>>>>>>>>>>>>  session info
// 下载seesion会话
@property (nonatomic, strong) NSURLSession *session;
// 下载模型字典 key = url, value = model
@property (nonatomic, strong) NSMutableDictionary *downloadingModelDic;
// 下载中的模型
@property (nonatomic, strong) NSMutableArray *waitingDownloadModels;
// 等待中的模型
@property (nonatomic, strong) NSMutableArray *downloadingModels;
// 回调代理的队列
@property (strong, nonatomic) NSOperationQueue *queue;

@end

@implementation ZJDownloadSessionManager

+ (ZJDownloadSessionManager *)manager
{
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc]init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    if (self = [super init]) {
        _backgroundConfigure = backgroundConfigure;
        _maxDownloadCount = 1;
        _resumeDownloadFIFO = YES;
        _isBatchDownload = NO;
    }
    return self;
}
- (void)configureBackroundSession
{
    if (!_backgroundConfigure) {
        return;
    }
    [self session];
}

#pragma mark - getter
- (NSFileManager *)fileManager
{
    if (!_fileManager) {
        _fileManager = [[NSFileManager alloc]init];
    }
    return _fileManager;
}

- (NSURLSession *)session
{
    if (!_session) {
        if (_backgroundConfigure) {
            if (IS_IOS8ORLATER) {
                NSURLSessionConfiguration *configure = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:_backgroundConfigure];
                _session = [NSURLSession sessionWithConfiguration:configure delegate:self delegateQueue:self.queue];
            }else{
                _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:_backgroundConfigure] delegate:self delegateQueue:self.queue];
            }
        }else{
            _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:self.queue];
        }
    }
    return _session;
}

- (NSOperationQueue *)queue
{
    if (!_queue) {
        _queue = [[NSOperationQueue alloc]init];
        _queue.maxConcurrentOperationCount = 1;
    }
    return _queue;
}

- (NSString *)downloadDirectory
{
    if (!_downloadDirectory) {
        _downloadDirectory = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"ZJDownloadCache"];
    }
    return _downloadDirectory;
}

- (NSMutableDictionary *)downloadingModelDic
{
    if (!_downloadingModelDic) {
        _downloadingModelDic = [NSMutableDictionary dictionary];
    }
    return _downloadingModelDic;
}

- (NSMutableArray *)waitingDownloadModels
{
    if (!_waitingDownloadModels) {
        _waitingDownloadModels = [NSMutableArray array];
    }
    return _waitingDownloadModels;
}

- (NSMutableArray *)downloadingModels
{
    if (!_downloadingModels) {
        _downloadingModels = [NSMutableArray array];
        
    }
    return _downloadingModels;
}

#pragma  mark - download

//开始下载
- (ZJDownloadModel *)startDownloadURLString:(NSString *)URLString toDestinationPath:(NSString *)destinationPath progress:(ZJDownloadProgressBlock)progress state:(ZJDownloadStateBlock)state
{
    //验证下载地址
    if (!URLString) {
        NSLog(@"downloadURL can't nil");
        return nil;
    }
    
    ZJDownloadModel *downloadModel = [self downloadingModelForURLString:URLString];
    
    if (!downloadModel || ![downloadModel.filePath isEqualToString:destinationPath]) {
        downloadModel = [[ZJDownloadModel alloc]initWithUrlString:URLString filePath:destinationPath];
    }
    
    [self startWithDownloadModel:downloadModel progress:progress state:state];
    
    return downloadModel;
}

- (void)startWithDownloadModel:(ZJDownloadModel *)downloadModel progress:(ZJDownloadProgressBlock)progress state:(ZJDownloadStateBlock)state
{
    downloadModel.progressBlock = progress;
    downloadModel.stateBlock = state;
    
    [self startWithDownloadModel:downloadModel];
}

- (void)startWithDownloadModel:(ZJDownloadModel *)downloadModel
{
    if (!downloadModel) {
        return;
    }
    
    if (downloadModel.state == ZJDownloadStateReadying) {
        [self downloadModel:downloadModel didChangeState:ZJDownloadStateReadying filePath:nil error:nil];
        return;
    }
    
    //验证是否存在
    if (downloadModel.task && downloadModel.task.state == NSURLSessionTaskStateRunning) {
        downloadModel.state = ZJDownloadStateRunning;
        [self downloadModel:downloadModel didChangeState:ZJDownloadStateRunning filePath:nil error:nil];
        return;
    }
    
    [self configureBackroundSessionTaskWithDownloadModel:downloadModel];
    
    [self resumeWithDownloadModel:downloadModel];
    
}

//恢复下载
- (void)resumeWithDownloadModel:(ZJDownloadModel *)downloadModel
{
    if (!downloadModel) {
        return;
    }
    
    if (![self canResumeDownloadModel:downloadModel]) {
        return;
    }
    
    
    
    if (!downloadModel.task || downloadModel.task.state == NSURLSessionTaskStateCanceling) {
    
        downloadModel.resumeData = [self resumeDataFromFileWithDownloadModel:downloadModel];
        
        
        if ([self isValideResumeData:downloadModel.resumeData]) {
            if (IS_IOS10ORLATER) {
                downloadModel.task = [self.session downloadTaskWithCorrectResumeData:downloadModel.resumeData];
            }else{
                downloadModel.task = [self.session downloadTaskWithResumeData:downloadModel.resumeData];
            }
        }else{
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:downloadModel.downloadURL]];
            downloadModel.task = [self.session downloadTaskWithRequest:request];
        }
        downloadModel.task.taskDescription = downloadModel.downloadURL;
        downloadModel.downloadDate = [NSDate date];
    }
  
    
    if (!downloadModel.downloadDate) {
        downloadModel.downloadDate = [NSDate date];
    }
    
    if (![self.downloadingModelDic objectForKey:downloadModel.downloadURL]) {
        self.downloadingModelDic[downloadModel.downloadURL] = downloadModel;
    }
    
    [downloadModel.task resume];
    
    downloadModel.state = ZJDownloadStateRunning;
    [self downloadModel:downloadModel didChangeState:ZJDownloadStateRunning filePath:nil error:nil];
}

- (BOOL)isValideResumeData:(NSData *)resumeData
{
    if (!resumeData || resumeData.length == 0) {
        return NO;
    }
    return YES;
}

//暂停下载
- (void)suspendWithDownloadModel:(ZJDownloadModel *)downloadModel
{
    if (!downloadModel.manualCancel) {
        downloadModel.manualCancel = YES;
        [self cancelWithDownloadModel:downloadModel clearResumeData:NO];
    }
}

//取消下载
- (void)cancelWithDownloadModel:(ZJDownloadModel *)downloadModel
{
    if (downloadModel.state != ZJDownloadStateCompleted && downloadModel.state != ZJDownloadStateFailed) {
        [self cancelWithDownloadModel:downloadModel clearResumeData:NO];
    }
}

//删除下载
- (void)deleteFileWithDownloadModel:(ZJDownloadModel *)downloadModel
{
    if (!downloadModel || !downloadModel.filePath) {
        return;
    }
    
    [self cancelWithDownloadModel:downloadModel clearResumeData:YES];
    [self deleteFileIfExist:downloadModel.filePath];
}

//删除下载
- (void)deleteAllFielWithDownloadDirectory:(NSString *)downloadDirectory
{
    if (!downloadDirectory) {
        downloadDirectory = self.downloadDirectory;
    }
    for (ZJDownloadModel *downloadModel in [self.downloadingModelDic allValues]) {
        if ([downloadModel.downloadDirectory isEqualToString:downloadDirectory]) {
            [self cancelWithDownloadModel:downloadModel clearResumeData:YES];
        }
    }
    //删除沙盒中所有资源
    [self.fileManager removeItemAtPath:downloadDirectory error:nil];
}

//取消下载，是否删除resumeData
- (void)cancelWithDownloadModel:(ZJDownloadModel *)downloadModel clearResumeData:(BOOL)clearResumeData
{
    if (!downloadModel.task && downloadModel.state == ZJDownloadStateReadying) {
        [self removeDownloadingModelForURLString:downloadModel.downloadURL];
        @synchronized (self) {
            [self.waitingDownloadModels removeObject:downloadModel];
        }
        downloadModel.state = ZJDownloadStateNone;
        [self downloadModel:downloadModel didChangeState:ZJDownloadStateNone filePath:nil error:nil];
        return;
    }
    if (clearResumeData) {
        downloadModel.state = ZJDownloadStateNone;
        downloadModel.resumeData = nil;
        [self deleteFileIfExist:[self resumeDataPathWithDownloadURL:downloadModel.downloadURL]];
        [downloadModel.task cancel];
    }else{
        [(NSURLSessionDownloadTask *)downloadModel.task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        }];
    }
}

- (void)willResumeNextWithDownloadModel:(ZJDownloadModel *)downloadModel
{
    if (_isBatchDownload) {
        return;
    }
    
    @synchronized (self) {
        [self.downloadingModels removeObject:downloadModel];
        //还有未下载
        if (self.waitingDownloadModels.count>0) {
            [self resumeWithDownloadModel:_resumeDownloadFIFO?self.waitingDownloadModels.firstObject:self.waitingDownloadModels.lastObject];
        }
    }
}


- (BOOL)canResumeDownloadModel:(ZJDownloadModel *)downloadModel
{
    if (_isBatchDownload) {
        return YES;
    }
    
    @synchronized (self) {
        if (self.downloadingModels.count>=_maxDownloadCount) {
            if ([self.waitingDownloadModels indexOfObject:downloadModel] == NSNotFound) {
                [self.waitingDownloadModels addObject:downloadModel];
                self.downloadingModelDic[downloadModel.downloadURL] = downloadModel;
            }
            
            downloadModel.state = ZJDownloadStateReadying;
            [self downloadModel:downloadModel didChangeState:ZJDownloadStateReadying filePath:nil error:nil];
            return NO;
        }
        
        if ([self.waitingDownloadModels indexOfObject:downloadModel] != NSNotFound) {
            [self.waitingDownloadModels removeObject:downloadModel];
        }
        
        if ([self.downloadingModels indexOfObject:downloadModel] == NSNotFound) {
            [self.downloadingModels addObject:downloadModel];
        }
        return YES;
    }
}

#pragma mark -configure background task
- (void)configureBackroundSessionTaskWithDownloadModel:(ZJDownloadModel *)downloadModel
{
    if (!_backgroundConfigure) {
        return;
    }
    
    NSURLSessionDownloadTask *task = [self backgroundSessionTasksWithDownloadModel:downloadModel];
    
    if (!task) {
        return;
    }
    
    downloadModel.task = task;
    if (task.state == NSURLSessionTaskStateRunning) {
        [task suspend];
    }
}

- (NSURLSessionDownloadTask *)backgroundSessionTasksWithDownloadModel:(ZJDownloadModel *)downloadModel
{
    NSArray *tasks = [self sessionDownloadTasks];
    for (NSURLSessionDownloadTask *task in tasks) {
        if (task.state == NSURLSessionTaskStateRunning || task.state == NSURLSessionTaskStateSuspended) {
            if ([downloadModel.downloadURL isEqualToString:task.taskDescription]) {
                return task;
            }
        }
    }
    return nil;
}

//获取所有的后台下载session
- (NSArray *)sessionDownloadTasks
{
    __block NSArray *tasks = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [self.session getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> * _Nonnull dataTasks, NSArray<NSURLSessionUploadTask *> * _Nonnull uploadTasks, NSArray<NSURLSessionDownloadTask *> * _Nonnull downloadTasks) {
        tasks = downloadTasks;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return tasks;
}

#pragma mark -public

//获取下载模型
- (ZJDownloadModel *)downloadingModelForURLString:(NSString *)URLString
{
    return [self.downloadingModelDic objectForKey:URLString];
}

//获取下载进度
- (ZJDownloadProgress *)progressWithDownloadModel:(ZJDownloadModel *)downloadModel
{
    ZJDownloadProgress *progress = [[ZJDownloadProgress alloc]init];
    progress.totalBytesExpectedToWrite = [self fileSizeInCachePlistWithDownloadModel:downloadModel];
    progress.totalBytesWritten = MIN([self fileSizeWithDownload:downloadModel], progress.totalBytesExpectedToWrite);
    progress.progress = progress.totalBytesExpectedToWrite>0?1.0*progress.totalBytesWritten/progress.totalBytesExpectedToWrite:0;
    return progress;
}

//是否已经下载
- (BOOL)isDownloadCompletedWithDownloadModel:(ZJDownloadModel *)downloadModel
{
    return [self.fileManager fileExistsAtPath:downloadModel.filePath];
}

//取消所有后台
- (void)cancelAllBackgroundSessionTasks
{
    if (!_backgroundConfigure) {
        return;
    }
    
    for (NSURLSessionDownloadTask *task in [self sessionDownloadTasks]) {
        [task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        }];
    }
}

#pragma mark -private
- (void)downloadModel:(ZJDownloadModel *)downloadModel didChangeState:(ZJDownloadState)state filePath:(NSString *)filePath error:(NSError *)error
{
    if (_delelgate && [_delelgate respondsToSelector:@selector(downloadModel:didChangeState:filePath:error:)]) {
        [_delelgate downloadModel:downloadModel didChangeState:state filePath:filePath error:error];
    }
    
    if (downloadModel.stateBlock) {
        downloadModel.stateBlock(state, filePath, error);
    }
}

- (void)downloadModel:(ZJDownloadModel *)downloadModel updateProgress:(ZJDownloadProgress *)progress
{
    if (_delelgate && [_delelgate respondsToSelector:@selector(downloadModel:didUpdateProgress:)]) {
        [_delelgate downloadModel:downloadModel didUpdateProgress:progress];
    }
    if (downloadModel.progressBlock) {
        downloadModel.progressBlock(progress);
    }
}

- (void)removeDownloadingModelForURLString:(NSString *)URLString
{
    [self.downloadingModelDic removeObjectForKey:URLString];
}

//获取resumeData

- (NSData *)resumeDataFromFileWithDownloadModel:(ZJDownloadModel *)downloadModel
{
    if (downloadModel.resumeData) {
        return downloadModel.resumeData;
    }
    
    NSString *resumeDataPath = [self resumeDataPathWithDownloadURL:downloadModel.downloadURL];
    
    if ([_fileManager fileExistsAtPath:resumeDataPath]) {
        NSData *resumeData = [NSData dataWithContentsOfFile:resumeDataPath];
        return resumeData;
    }
    return nil;

}

//获取resumeData路径
- (NSString *)resumeDataPathWithDownloadURL:(NSString *)downloadURL
{
    NSString *resumeFileName = [[self class] md5:downloadURL];
    return [self.downloadDirectory stringByAppendingPathComponent:resumeFileName];
}

+ (NSString *)md5:(NSString *)str
{
    const char *cStr = [str UTF8String];
    if (cStr == NULL) {
        cStr = "";
    }
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5( cStr, (CC_LONG)strlen(cStr), result );
    return [NSString stringWithFormat:
            @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];
}

//创建缓存目录文件
- (void)createDirectory:(NSString *)directory
{
    if (![self.fileManager fileExistsAtPath:directory]) {
        [self.fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    }
}

- (void)moveFileAtUrl:(NSURL *)srcURL toPath:(NSString *)destinationPath
{
    if (!destinationPath) {
        NSLog(@"error filePath is nil");
    }
    NSError *error = nil;
    if ([self.fileManager fileExistsAtPath:destinationPath]) {
        [self.fileManager removeItemAtPath:destinationPath error:&error];
        if (error) {
            NSLog(@"removeItem error %@",error);
        }
    }
    
    NSURL *destinationURL = [NSURL fileURLWithPath:destinationPath];
    [self.fileManager moveItemAtURL:srcURL toURL:destinationURL error:&error];
    if (error) {
        NSLog(@"moveItem error : %@",error);
    }
}

- (void)deleteFileIfExist:(NSString *)filePath
{
    if ([self.fileManager fileExistsAtPath:filePath]) {
        NSError *error = nil;
        [self.fileManager removeItemAtPath:filePath error:&error];
        if (error) {
            NSLog(@"removeItem error %@",error);
        }
    }
}



//下载文件信息plist路径
- (NSString *)fileSizePathWithDownloadModel:(ZJDownloadModel *)downloadModel
{
    return [downloadModel.downloadDirectory stringByAppendingPathComponent:@"downloadsFileSize.plist"];
}
//获取plist保存文件大小
- (long long)fileSizeInCachePlistWithDownloadModel:(ZJDownloadModel *)downloadModel
{
    NSDictionary *downloadsFileSizePlist = [NSDictionary dictionaryWithContentsOfFile:[self fileSizePathWithDownloadModel:downloadModel]];
    long long totalSize = [downloadsFileSizePlist[downloadModel.downloadURL] longLongValue];
    return totalSize;
}

//获取plist内容
- (NSMutableDictionary *)fileSizePlistWithDownloadModel:(ZJDownloadModel *)downloadModel
{
    NSMutableDictionary *downloadsFileSizePlist = [NSMutableDictionary dictionaryWithContentsOfFile:[self fileSizePathWithDownloadModel:downloadModel]];
    if (!downloadsFileSizePlist) {
        downloadsFileSizePlist = [NSMutableDictionary dictionary];
    }
    return downloadsFileSizePlist;
}

//获取resumeData大小
- (long long)fileSizeWithDownload:(ZJDownloadModel *)downloadModel
{
    NSData *resumeData = [self resumeDataFromFileWithDownloadModel:downloadModel];
    return [self fileSizeWithResumeData:resumeData];
}

//解析resumeData数据获取已下载大小
- (long long)fileSizeWithResumeData:(NSData *)resumeData
{
    
    NSString *resumeStr = [[NSString alloc]initWithData:resumeData encoding:NSUTF8StringEncoding];
    if ([resumeStr isEqualToString:@""]) {
        return 0;
    }
    NSRange oneStringRange = [resumeStr rangeOfString:@"NSURLSessionResumeBytesReceived"];
    NSRange twoStringRange = [resumeStr rangeOfString:@"NSURLSessionResumeCurrentRequest"];
    NSString *tmpString = [resumeStr substringWithRange:NSMakeRange(oneStringRange.location+oneStringRange.length, twoStringRange.location-oneStringRange.location-oneStringRange.length)];
    
    NSRange preRange = [tmpString rangeOfString:@"<integer>"];
    NSRange backRange = [tmpString rangeOfString:@"</integer>"];
    NSString *lengthStr = [tmpString substringWithRange:NSMakeRange(preRange.location+preRange.length, backRange.location-preRange.location-preRange.length)];
    return [lengthStr longLongValue];
    
}

#pragma mark -NSURLSessionDownloadDelegate

//恢复下载
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
    ZJDownloadModel *downloadModel = [self downloadingModelForURLString:downloadTask.taskDescription];
    
    if (!downloadModel || downloadModel.state == ZJDownloadStateSuspended) {
        return;
    }
    
    downloadModel.progress.resumeBytesWritten = fileOffset;
}

//监听文件下载进度
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    ZJDownloadModel *downloadModel = [self downloadingModelForURLString:downloadTask.taskDescription];
    
    if(!downloadModel || downloadModel.state == ZJDownloadStateSuspended) return;
    
    float progress = (double)totalBytesWritten/totalBytesExpectedToWrite;
    
    int64_t resumeBytesWritten = downloadModel.progress.resumeBytesWritten;
    
    NSTimeInterval downloadTime = -1*[downloadModel.downloadDate timeIntervalSinceNow];
    float speed = totalBytesWritten- resumeBytesWritten/downloadTime;
    
    int64_t remainingContentLength = totalBytesExpectedToWrite-totalBytesWritten;
    int remainingTime = ceil(remainingContentLength/speed);
    
    downloadModel.progress.bytesWritten = bytesWritten;
    downloadModel.progress.totalBytesWritten = totalBytesWritten;
    downloadModel.progress.totalBytesExpectedToWrite = totalBytesExpectedToWrite;
    downloadModel.progress.progress = progress;
    downloadModel.progress.speed = speed;
    downloadModel.progress.remainingTime = remainingTime;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self downloadModel:downloadModel updateProgress:downloadModel.progress];
    });
    
    
    
}

//下载成功
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    ZJDownloadModel *downloadModel = [self downloadingModelForURLString:downloadTask.taskDescription];
    if (!downloadModel && _backgroundSessionDownloadCompleteBlock) {
        NSString *filePath = _backgroundSessionDownloadCompleteBlock(downloadTask.taskDescription);
        //移动文件到下载目录
        [self createDirectory:filePath.stringByDeletingLastPathComponent];
        [self moveFileAtUrl:location toPath:filePath];
    }
    
    if (location) {
        [self createDirectory:downloadModel.downloadDirectory];
        [self moveFileAtUrl:location toPath:downloadModel.filePath];
    }
}

//下载完成
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    ZJDownloadModel *downloadModel = [self downloadingModelForURLString:task.taskDescription];
    
    if (!downloadModel) {
        NSData *resumeData = error?[error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData]:nil;
        if (resumeData) {
            [self createDirectory:_downloadDirectory];
            [resumeData writeToFile:[self resumeDataPathWithDownloadURL:task.taskDescription] atomically:YES];
        }else{
            [self deleteFileIfExist:[self resumeDataPathWithDownloadURL:task.taskDescription]];
        }
        return;
    }
    
    NSData *resumeData = nil;
    if (error) {
        resumeData = [error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData];
    }
    
    //缓存resumeData
    if (resumeData) {
        downloadModel.resumeData = resumeData;
        [self createDirectory:self.downloadDirectory];
        [downloadModel.resumeData writeToFile:[self resumeDataPathWithDownloadURL:downloadModel.downloadURL] atomically:YES];
    }else{
        downloadModel.resumeData = nil;
        [self deleteFileIfExist:[self resumeDataPathWithDownloadURL:downloadModel.downloadURL]];
        
    }
    
    downloadModel.progress.resumeBytesWritten = 0;
    downloadModel.task = nil;
    [self removeDownloadingModelForURLString:downloadModel.downloadURL];
    
    if (downloadModel.manualCancel) {
        //手动取消，当做暂停
        dispatch_async(dispatch_get_main_queue(), ^{
            downloadModel.manualCancel = NO;
            downloadModel.state = ZJDownloadStateSuspended;
            [self downloadModel:downloadModel didChangeState:ZJDownloadStateSuspended filePath:nil error:nil];
            [self willResumeNextWithDownloadModel:downloadModel];
        });
    }else if (error){
        if (downloadModel.state == ZJDownloadStateNone) {
            //删除下载
            dispatch_async(dispatch_get_main_queue(), ^{
                downloadModel.state = ZJDownloadStateNone;
                [self downloadModel:downloadModel didChangeState:ZJDownloadStateNone filePath:nil error:error];
                [self willResumeNextWithDownloadModel:downloadModel];
            });
        }else{
            //下载失败
            dispatch_async(dispatch_get_main_queue(), ^{
                downloadModel.state = ZJDownloadStateFailed;
                [self downloadModel:downloadModel didChangeState:ZJDownloadStateFailed filePath:nil error:error];
                [self willResumeNextWithDownloadModel:downloadModel];
            });
        }
    }else{
        //下载完成
        dispatch_async(dispatch_get_main_queue(), ^{
            downloadModel.state = ZJDownloadStateCompleted;
            [self downloadModel:downloadModel didChangeState:ZJDownloadStateCompleted filePath:downloadModel.filePath error:nil];
            [self willResumeNextWithDownloadModel:downloadModel];
        });
    }
    
}

//后台session下载完成
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
    if (self.backgroundSessionCompletionHandler) {
        self.backgroundSessionCompletionHandler();
    }
}


@end
