//
//  ZJDownloadDataManager.m
//  chanbendong
//
//  Created by 吴孜健 on 2018/1/18.
//  Copyright © 2018年 吴孜健. All rights reserved.
//

#import "ZJDownloadDataManager.h"
@interface ZJDownloadDataManager ()

// >>>>>>>>>>>>>>>>>>>>>>>>>>  file info
// 文件管理
@property (nonatomic, strong) NSFileManager *fileManager;
// 缓存文件目录
@property (nonatomic, strong) NSString *downloadDirectory;

// >>>>>>>>>>>>>>>>>>>>>>>>>>  session info
// 下载seesion会话
@property (nonatomic, strong) NSURLSession *session;
// 下载模型字典 key = url
@property (nonatomic, strong) NSMutableDictionary *downloadingModelDic;
// 下载中的模型
@property (nonatomic, strong) NSMutableArray *waitingDownloadModels;
// 等待中的模型
@property (nonatomic, strong) NSMutableArray *downloadingModels;
// 回调代理的队列
@property (strong, nonatomic) NSOperationQueue *queue;

@end

@implementation ZJDownloadDataManager

+ (ZJDownloadDataManager *)manager
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
        _maxDownloadCount = 1;
        _resumeDownloadFIFO = YES;
        _isBatchDownload = NO;
    }
    return self;
}

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
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:self.queue];
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
        _downloadDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject stringByAppendingPathComponent:@"ZJDownloadCache"];
        [self createDirectory:_downloadDirectory];
    }
    return _downloadDirectory;
}

//下载文件信息plist路径
- (NSString *)fileSizePathWithDownloadModel:(ZJDownloadModel *)downloadModel
{
    return [downloadModel.downloadDirectory stringByAppendingPathComponent:@"downloadsFileSize.plist"];
}

//下载model字典
- (NSMutableDictionary *)downloadingModelDic
{
    if (!_downloadingModelDic) {
        _downloadingModelDic = [NSMutableDictionary dictionary];
    }
    return _downloadingModelDic;
}

//等待下载model队列
- (NSMutableArray *)waitingDownloadModels
{
    if (!_waitingDownloadModels) {
        _waitingDownloadModels = [NSMutableArray array];
    }
    return _waitingDownloadModels;
}

//正在下载model队列
- (NSMutableArray *)downloadingModels
{
    if (!_downloadingModels) {
        _downloadingModels = [NSMutableArray array];
    }
    return _downloadingModels;
}

#pragma mark - download

- (ZJDownloadModel *)startDownloadURLString:(NSString *)URLString toDestinationPath:(NSString *)destinationPath progress:(ZJDownloadProgressBlock)progress state:(ZJDownloadStateBlock)state
{
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
    
    //验证是否在等待下载
    if (downloadModel.state == ZJDownloadStateReadying) {
        [self downloadModel:downloadModel didChangeState:ZJDownloadStateReadying filePath:nil error:nil];
        return;
    }
    
    //验证是否已经下载文件
    if ([self isDownloadCompletedWithDownloadModel:downloadModel]) {
        downloadModel.state = ZJDownloadStateCompleted;
        [self downloadModel:downloadModel didChangeState:ZJDownloadStateCompleted filePath:downloadModel.filePath error:nil];
        return;
    }
    
    //验证是否存在
    if (downloadModel.task && downloadModel.task.state == NSURLSessionTaskStateRunning) {
        downloadModel.state = ZJDownloadStateRunning;
        [self downloadModel:downloadModel didChangeState:ZJDownloadStateRunning filePath:downloadModel.filePath error:nil];
        return;
    }
    
    [self resumeWithDownloadModel:downloadModel];
    
}


//自动下载下一个等待队列任务
- (void)willResumeNextWithDownloadModel:(ZJDownloadModel *)downloadModel
{
    if (_isBatchDownload) {
        return;
    }
    
    @synchronized (self) {
        [self.downloadingModels removeObject:downloadModel];
        
        //还有未下载的
        if (self.waitingDownloadModels.count > 0) {
            [self resumeWithDownloadModel:_resumeDownloadFIFO ? self.waitingDownloadModels.firstObject:self.waitingDownloadModels.lastObject];
        }
    }
}

//是否开启下载等待队列任务
- (BOOL)canResumeDownloadModel:(ZJDownloadModel *)downloadModel
{
    if (_isBatchDownload) {
        return YES;
    }

    @synchronized (self) {
        //如果正在下载的数量大于等于最大下载量，则返回NO
        if (self.downloadingModels.count >= _maxDownloadCount) {
            //如果等待下载的List中没有则添加
            if ([self.waitingDownloadModels indexOfObject:downloadModel] == NSNotFound) {
                [self.waitingDownloadModels addObject:downloadModel];
                self.downloadingModelDic[downloadModel.downloadURL] = downloadModel;
            }
            downloadModel.state = ZJDownloadStateReadying;
            [self downloadModel:downloadModel didChangeState:ZJDownloadStateReadying filePath:nil error:nil];
            return NO;
        }
        //如果可以开启下载，则在等待序列中删除，并在下载序列中添加
        if ([self.waitingDownloadModels indexOfObject:downloadModel] != NSNotFound) {
            [self.waitingDownloadModels removeObject:downloadModel];
        }
        
        if ([self.downloadingModels indexOfObject:downloadModel] == NSNotFound) {
            [self.downloadingModels addObject:downloadModel];
        }
        return YES;
    }
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
        NSString *URLString = downloadModel.downloadURL;
        
        //创建请求
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString]];
        
        //设置请求头
        NSString *range = [NSString stringWithFormat:@"bytes=%zd-",[self fileSizeWithDownloadModel:downloadModel]];
        [request setValue:range forHTTPHeaderField:@"Range"];
        
        //创建流
        downloadModel.stream = [NSOutputStream outputStreamToFileAtPath:downloadModel.filePath append:YES];
        
        downloadModel.downloadDate = [NSDate date];
        self.downloadingModelDic[downloadModel.downloadURL] = downloadModel;
        //创建一个data任务
        downloadModel.task = [self.session dataTaskWithRequest:request];
        downloadModel.task.taskDescription = URLString;
    }

    [downloadModel.task resume];
    
    downloadModel.state = ZJDownloadStateRunning;
    [self downloadModel:downloadModel didChangeState:ZJDownloadStateRunning filePath:nil error:nil];
}

//暂停下载
- (void)suspendWithDownloadModel:(ZJDownloadModel *)downloadModel
{
    if (!downloadModel.manualCancel) {
        downloadModel.manualCancel = YES;
        [downloadModel.task cancel];
    }
}

//取消下载
- (void)cancelWithDownloadModel:(ZJDownloadModel *)downloadModel
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
    
    if (downloadModel.state != ZJDownloadStateCompleted && downloadModel.state != ZJDownloadStateFailed) {
        [downloadModel.task cancel];
    }
   
}

#pragma mark - delete file
- (void)deleteFileWithDownloadModel:(ZJDownloadModel *)downloadModel
{
    if (!downloadModel || !downloadModel.filePath) {
        return;
    }
    
    if ([self.fileManager fileExistsAtPath:downloadModel.filePath]) {
        
        //删除任务
        downloadModel.task.taskDescription = nil;
        [downloadModel.task cancel];
        downloadModel.task = nil;
        
        //删除流
        if (downloadModel.stream.streamStatus > NSStreamStatusNotOpen && downloadModel.stream.streamStatus < NSStreamStatusClosed) {
            [downloadModel.stream close];
        }
        downloadModel.stream = nil;
        
        NSError *error = nil;
        [self.fileManager removeItemAtPath:downloadModel.filePath error:&error];
        if (error) {
            NSLog(@"delete file error %@", error);
        }
        
        [self removeDownloadingModelForURLString:downloadModel.downloadURL];
        //删除资源plist保存的资源总长度
        if ([self.fileManager fileExistsAtPath:[self fileSizePathWithDownloadModel:downloadModel]]) {
            @synchronized (self){
                NSMutableDictionary *dict = [self fileSizePlistWithDownloadModel:downloadModel];
                [dict removeObjectForKey:downloadModel.downloadURL];
                [dict writeToFile:[self fileSizePathWithDownloadModel:downloadModel] atomically:YES];
            }
        }
    }
    
}

- (void)deleteAllFileWithDownloadDirectory:(NSString *)downloadDirectory
{
    if (!downloadDirectory) {
        downloadDirectory = self.downloadDirectory;
    }
    if ([self.fileManager fileExistsAtPath:downloadDirectory]) {
        for (ZJDownloadModel *model in [self.downloadingModelDic allValues]) {
            if ([model.downloadDirectory isEqualToString:downloadDirectory]) {
                model.task.taskDescription = nil;
                [model.task cancel];
                model.task = nil;
                
                if (model.stream.streamStatus > NSStreamStatusNotOpen && model.stream.streamStatus < NSStreamStatusClosed) {
                    [model.stream close];
                }
                model.stream = nil;
            }
            
        }
        [self.fileManager removeItemAtPath:downloadDirectory error:nil];
    }
}


#pragma mark - public

//获取下载模型
- (ZJDownloadModel *)downloadingModelForURLString:(NSString *)URLString
{
    return [self.downloadingModelDic objectForKey:URLString];
}

//是否已经下载
- (BOOL)isDownloadCompletedWithDownloadModel:(ZJDownloadModel *)downloadModel
{
    long long fileSize = [self fileSizeInCachePlistWithDownloadModel:downloadModel];
    if (fileSize > 0 && fileSize == [self fileSizeWithDownloadModel:downloadModel]) {
        return YES;
    }
    return NO;
}

//当前下载进度
- (ZJDownloadProgress *)progressWithDownloadModel:(ZJDownloadModel *)downloadModel
{
    ZJDownloadProgress *progress = [[ZJDownloadProgress alloc]init];
    progress.totalBytesExpectedToWrite = [self fileSizeInCachePlistWithDownloadModel:downloadModel];
    progress.totalBytesWritten = MIN([self fileSizeWithDownloadModel:downloadModel], progress.totalBytesExpectedToWrite);
    progress.progress = progress.totalBytesExpectedToWrite>0?1.0*progress.totalBytesWritten/progress.totalBytesExpectedToWrite:0;
    
    return progress;
}


#pragma mark - privite
- (void)downloadModel:(ZJDownloadModel *)downloadModel didChangeState:(ZJDownloadState)state filePath:(NSString *)filePath error:(NSError *)error
{
    if (_delegate && [_delegate respondsToSelector:@selector(downloadModel:didChangeState:filePath:error:)]) {
        [_delegate downloadModel:downloadModel didChangeState:state filePath:filePath error:error];
    }
    
    if (downloadModel.stateBlock) {
        downloadModel.stateBlock(state, filePath, error);
    }
}

- (void)downloadModel:(ZJDownloadModel *)downloadModel updateProgress:(ZJDownloadProgress *)progress
{
    if (_delegate && [_delegate respondsToSelector:@selector(downloadModel:didUpdateProgress:)]) {
        [_delegate downloadModel:downloadModel didUpdateProgress:progress];
    }
    
    if (downloadModel.progressBlock) {
        downloadModel.progressBlock(progress);
    }
}


//  创建缓存目录文件
- (void)createDirectory:(NSString *)directory
{
    if (![self.fileManager fileExistsAtPath:directory]) {
        [self.fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    }
}

- (void)removeDownloadingModelForURLString:(NSString *)URLString
{
    [self.downloadingModelDic removeObjectForKey:URLString];
}

//获取文件大小
- (long long)fileSizeWithDownloadModel:(ZJDownloadModel *)downloadModel
{
    NSString *filePath = downloadModel.filePath;
    if (![self.fileManager fileExistsAtPath:filePath]) {
        return 0;
    }
    return [[self.fileManager attributesOfItemAtPath:filePath error:nil] fileSize];
}

//获取plist保存文件大小
- (long long)fileSizeInCachePlistWithDownloadModel:(ZJDownloadModel *)downloadModel
{
    NSDictionary *downloadsFileSizePlist = [NSDictionary dictionaryWithContentsOfFile:[self fileSizePathWithDownloadModel:downloadModel]];
    return [downloadsFileSizePlist[downloadModel.downloadURL] longLongValue];
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

#pragma mark -NSURLSessionDelegate

//接受到响应
- (void)URLSession:(NSURLSession *)session dataTask:(nonnull NSURLSessionDataTask *)dataTask didReceiveResponse:(nonnull NSURLResponse *)response completionHandler:(nonnull void (^)(NSURLSessionResponseDisposition))completionHandler
{
    ZJDownloadModel *downloadModel = [self downloadingModelForURLString:dataTask.taskDescription];
    if (!downloadModel) {
        return;
    }
    
    [self createDirectory:_downloadDirectory];
    NSLog(@"downloadDirectory : %@",_downloadDirectory);
    [self createDirectory:downloadModel.downloadDirectory];
    NSLog(@"downloadModel : %@",downloadModel.downloadDirectory);
    
    //打开流
    [downloadModel.stream open];
    
    long long totalBytesWritten = [self fileSizeWithDownloadModel:downloadModel];
    long long totalBytesExpectedToWrite  = totalBytesWritten+dataTask.countOfBytesExpectedToReceive;
    
    downloadModel.progress.resumeBytesWritten = totalBytesWritten;
    downloadModel.progress.totalBytesWritten = totalBytesWritten;
    downloadModel.progress.totalBytesExpectedToWrite = totalBytesExpectedToWrite;
    
    @synchronized (self) {
        NSMutableDictionary *dic = [self fileSizePlistWithDownloadModel:downloadModel];
        dic[downloadModel.downloadURL] = @(totalBytesExpectedToWrite);
        [dic writeToFile:[self fileSizePathWithDownloadModel:downloadModel] atomically:YES];
    }
    
    //接受这个请求，允许接受服务器的数据
    completionHandler(NSURLSessionResponseAllow);
    
}

//接受到服务器返回的数据

- (void)URLSession:(NSURLSession *)session dataTask:(nonnull NSURLSessionDataTask *)dataTask didReceiveData:(nonnull NSData *)data
{
    ZJDownloadModel *downloadModel = [self downloadingModelForURLString:dataTask.taskDescription];
    if (!downloadModel || downloadModel.state == ZJDownloadStateSuspended) {
        return;
    }
    
    
    //写入数据
    [downloadModel.stream write:data.bytes maxLength:data.length];
    
    //下载进度
    downloadModel.progress.bytesWritten = data.length;
    downloadModel.progress.totalBytesWritten += downloadModel.progress.bytesWritten;
    downloadModel.progress.progress = MIN(1.0, 1.0*downloadModel.progress.totalBytesWritten/downloadModel.progress.totalBytesExpectedToWrite);
    
    //时间
    NSTimeInterval downloadTiem = -1 *[downloadModel.downloadDate timeIntervalSinceNow];
    downloadModel.progress.speed = (downloadModel.progress.totalBytesWritten-downloadModel.progress.resumeBytesWritten)/downloadTiem;
    
    int64_t remainingContentLength = downloadModel.progress.totalBytesExpectedToWrite-downloadModel.progress.totalBytesWritten;
    downloadModel.progress.remainingTime = ceilf(remainingContentLength/downloadModel.progress.speed);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self downloadModel:downloadModel updateProgress:downloadModel.progress];
    });
}

//请求完毕
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error
{
    ZJDownloadModel *downloadModel = [self downloadingModelForURLString:task.taskDescription];
    
    if (!downloadModel) {
        return;
    }
    
    //关闭流
    [downloadModel.stream close];
    downloadModel.stream  = nil;
    downloadModel.task = nil;
    
    [self removeDownloadingModelForURLString:downloadModel.downloadURL];
    
    if (downloadModel.manualCancel) {
        //手动暂停下载
        dispatch_async(dispatch_get_main_queue(), ^{
            downloadModel.manualCancel = NO;
            downloadModel.state = ZJDownloadStateSuspended;
            [self downloadModel:downloadModel didChangeState:ZJDownloadStateSuspended filePath:nil error:nil];
            [self willResumeNextWithDownloadModel:downloadModel];
        });
    }else if (error){
        //下载失败
        dispatch_async(dispatch_get_main_queue(), ^{
            downloadModel.state = ZJDownloadStateFailed;
            [self downloadModel:downloadModel didChangeState:ZJDownloadStateFailed filePath:nil error:error];
            [self willResumeNextWithDownloadModel:downloadModel];
        });
    }else if ([self isDownloadCompletedWithDownloadModel:downloadModel]){
        //下载完成
        dispatch_async(dispatch_get_main_queue(), ^{
            downloadModel.state = ZJDownloadStateCompleted;
            [self downloadModel:downloadModel didChangeState:ZJDownloadStateCompleted filePath:downloadModel.filePath error:nil];
            [self willResumeNextWithDownloadModel:downloadModel];
        });
    }else{
        //下载完成
        dispatch_async(dispatch_get_main_queue(), ^{
            downloadModel.state = ZJDownloadStateCompleted;
            [self downloadModel:downloadModel didChangeState:ZJDownloadStateCompleted filePath:downloadModel.filePath error:nil];
            [self willResumeNextWithDownloadModel:downloadModel];
        });
    }
}

@end
