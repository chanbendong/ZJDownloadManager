//
//  ZJDownloadDelegate.h
//  chanbendong
//
//  Created by 吴孜健 on 2018/1/18.
//  Copyright © 2018年 吴孜健. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZJDownloadModel.h"

@protocol ZJDownloadDelegate <NSObject>

/**<更新下载进度*/
- (void)downloadModel:(ZJDownloadModel *)downloadModel didUpdateProgress:(ZJDownloadProgress *)progress;
/**<更新下载状态*/
- (void)downloadModel:(ZJDownloadModel *)downloadModel didChangeState:(ZJDownloadState)state filePath:(NSString *)filePath error:(NSError *)error;

@end
