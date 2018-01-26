//
//  ZJDownloadModel.m
//  chanbendong
//
//  Created by 吴孜健 on 2018/1/18.
//  Copyright © 2018年 吴孜健. All rights reserved.
//

#import "ZJDownloadModel.h"


@implementation ZJDownloadModel

- (instancetype)init
{
    if (self = [super init]) {
        _progress = [[ZJDownloadProgress alloc]init];
    }
    return self;
}

- (instancetype)initWithUrlString:(NSString *)URLString
{
    return [self initWithUrlString:URLString filePath:nil];
}

- (instancetype)initWithUrlString:(NSString *)URLString filePath:(NSString *)filePath
{
    if (self = [self init]) {
        _downloadURL = URLString;
        _fileName = filePath.lastPathComponent;
        _downloadDirectory = filePath.stringByDeletingLastPathComponent;
        _filePath = filePath;
    }
    return self;
}


- (NSString *)fileName
{
    if (!_fileName) {
        _fileName = _downloadURL.lastPathComponent;
    }
    return _fileName;
}

- (NSString *)downloadDirectory
{
    if (!_downloadDirectory) {
        _downloadDirectory = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"ZJDownloadCache"];
    }
    return _downloadDirectory;
}

- (NSString *)filePath
{
    if (!_filePath) {
        _filePath = [self.downloadDirectory stringByAppendingPathComponent:self.fileName];
    }
    return _filePath;
}


@end

@implementation ZJDownloadProgress

@end
