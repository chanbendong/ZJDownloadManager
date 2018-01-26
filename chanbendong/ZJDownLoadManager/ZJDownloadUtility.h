//
//  ZJDownloadUtility.h
//  chanbendong
//
//  Created by 吴孜健 on 2018/1/22.
//  Copyright © 2018年 吴孜健. All rights reserved.
//

#import <Foundation/Foundation.h>

/**<下载工具类*/
@interface ZJDownloadUtility : NSObject

/**<返回文件大小*/
+ (float)calculateFileSizeInUnit:(unsigned long long)contentLength;

/**<返回文件大小的单位*/
+ (NSString *)calculateUnit:(unsigned long long)contentLength;

@end
