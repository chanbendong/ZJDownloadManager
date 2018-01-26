//
//  NSURLSession+ZJCorrectedResumeData.h
//  chanbendong
//
//  Created by 吴孜健 on 2018/1/24.
//  Copyright © 2018年 吴孜健. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURLSession (ZJCorrectedResumeData)

- (NSURLSessionDownloadTask *)downloadTaskWithCorrectResumeData:(NSData *)resumeData;

@end
