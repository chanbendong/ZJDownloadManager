//
//  ViewController.m
//  chanbendong
//
//  Created by 吴孜健 on 2017/12/12.
//  Copyright © 2017年 吴孜健. All rights reserved.
//

#import "ViewController.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import "ZJDownloadSessionManager.h"
#import "ZJDownloadUtility.h"

#define log(_var) ({ NSString *name = @#_var;NSLog(@"%@: %@ -> %p: %@",name,[_var class],_var, _var);})

@interface ViewController ()<ZJDownloadDelegate>

@property (nonatomic, assign) NSNumber *num;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItem *item;
@property (nonatomic, strong) NSMutableArray *array;
@property (weak, nonatomic) IBOutlet UILabel *progressL1;
@property (weak, nonatomic) IBOutlet UIProgressView *progressv1;
@property (weak, nonatomic) IBOutlet UIButton *btn1;
@property (weak, nonatomic) IBOutlet UILabel *l2;
@property (weak, nonatomic) IBOutlet UIProgressView *v2;
@property (weak, nonatomic) IBOutlet UIButton *b2;
@property (weak, nonatomic) IBOutlet UILabel *l3;
@property (weak, nonatomic) IBOutlet UIProgressView *v3;
@property (weak, nonatomic) IBOutlet UIButton *b3;
@property (nonatomic, strong) AVAudioPlayer *avplayer;

@property (nonatomic,strong) ZJDownloadModel *downloadModel1;
@property (nonatomic,strong) ZJDownloadModel *downloadModel2;
@property (nonatomic,strong) ZJDownloadModel *downloadModel3;


@end

static NSString *const downloadUrl1 = @"https://test.bejoint.com/dist/music/song.mp3";
static NSString *const downloadUrl2 = @"https://test.bejoint.com/dist/music/song2.flac";
static NSString *const downloadUrl3 = @"https://test.bejoint.com/dist/music/song3.flac";


@implementation ViewController

__weak id reference = nil;

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
//    NSLog(@"string: %@",reference);
   
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
//    NSLog(@"string: %@",reference);
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [ZJDownloadSessionManager manager].delelgate = self;
    
    ZJDownloadModel *model = [[ZJDownloadModel alloc]initWithUrlString:downloadUrl1];;
//    ZJDownloadProgress *progress = [[ZJDownloadSessionManager manager] progressWithDownloadModel:model];;
//
//    _progressL1.text = [self detailTextForDownloadProgress:progress];
//    _progressv1.progress = progress.progress;
    [self.btn1 setTitle:[[ZJDownloadSessionManager manager] isDownloadCompletedWithDownloadModel:model] ? @"下载完成，重新下载":@"开始" forState:UIControlStateNormal];
    _downloadModel1 = model;


    model = [[ZJDownloadModel alloc]initWithUrlString:downloadUrl2];;
   ZJDownloadProgress *progress = [[ZJDownloadSessionManager manager]progressWithDownloadModel:model];;
    
    _l2.text = [self detailTextForDownloadProgress:progress];
    _v2.progress = progress.progress;
    [_b2 setTitle:[[ZJDownloadSessionManager manager] isDownloadCompletedWithDownloadModel:model] ? @"下载完成，重新下载":@"开始" forState:UIControlStateNormal];
    _downloadModel2 = model;

    model = [[ZJDownloadModel alloc]initWithUrlString:downloadUrl3];;
//    progress = [[ZJDownloadSessionManager manager]progressWithDownloadModel:model];;
//
//    _l3.text = [self detailTextForDownloadProgress:progress];
//    _v3.progress = progress.progress;
    [_b3 setTitle:[[ZJDownloadSessionManager manager] isDownloadCompletedWithDownloadModel:model] ? @"下载完成，重新下载":@"开始" forState:UIControlStateNormal];
    _downloadModel3 = model;
    
    
}
- (IBAction)play:(id)sender {
    NSURL *url = [NSURL fileURLWithPath:_downloadModel1.filePath];
    NSLog(@"url : %@",url);
    
    _avplayer = [[AVAudioPlayer alloc]initWithContentsOfURL:url error:nil];
    if (_avplayer.prepareToPlay ) {
        [_avplayer play];
    }
}

- (IBAction)b1click:(id)sender {
    ZJDownloadSessionManager *manager = [ZJDownloadSessionManager manager];
    
    if (_downloadModel1.state == ZJDownloadStateReadying) {
        [manager cancelWithDownloadModel:_downloadModel1];
        return;
    }
    if ([manager isDownloadCompletedWithDownloadModel:_downloadModel1]) {
        [manager deleteFileWithDownloadModel:_downloadModel1];
    }
    if (_downloadModel1.state == ZJDownloadStateRunning) {
        [manager suspendWithDownloadModel:_downloadModel1];
        return;
    }
    
    [self startDownload1];
}

- (void)startDownload1
{
    ZJDownloadSessionManager *manager = [ZJDownloadSessionManager manager];
    __weak typeof(self) weakSelf = self;
    [manager startWithDownloadModel:_downloadModel1 progress:^(ZJDownloadProgress *progress) {
        weakSelf.progressv1.progress = progress.progress;
        weakSelf.progressL1.text = [weakSelf detailTextForDownloadProgress:progress];
    } state:^(ZJDownloadState state, NSString *filePath, NSError *error) {
        if (state == ZJDownloadStateCompleted) {
            weakSelf.progressv1.progress = 1.0;
            weakSelf.progressL1.text = [NSString stringWithFormat:@"progress  %.2f",weakSelf.progressv1.progress];
        }
        [weakSelf.btn1 setTitle:[weakSelf stateTitleWithState:state] forState:UIControlStateNormal];
    }];
}

- (IBAction)b2click:(id)sender {
    ZJDownloadSessionManager *manager = [ZJDownloadSessionManager manager];
    
    if (_downloadModel2.state == ZJDownloadStateReadying) {
        [manager cancelWithDownloadModel:_downloadModel2];
        return;
    }
    if ([manager isDownloadCompletedWithDownloadModel:_downloadModel2]) {
        [manager deleteFileWithDownloadModel:_downloadModel2];
    }
    if (_downloadModel2.state == ZJDownloadStateRunning) {
        [manager suspendWithDownloadModel:_downloadModel2];
        return;
    }
    
    [self startDownload2];
}

- (void)startDownload2
{
    ZJDownloadSessionManager *manager = [ZJDownloadSessionManager manager];
    __weak typeof(self) weakSelf = self;
    [manager startWithDownloadModel:_downloadModel2 progress:^(ZJDownloadProgress *progress) {
        weakSelf.v2.progress = progress.progress;
        weakSelf.l2.text = [weakSelf detailTextForDownloadProgress:progress];
    } state:^(ZJDownloadState state, NSString *filePath, NSError *error) {
        if (state == ZJDownloadStateCompleted) {
            weakSelf.v2.progress = 1.0;
            weakSelf.l2.text = [NSString stringWithFormat:@"progress  %.2f",weakSelf.v2.progress];
        }
        [weakSelf.b2 setTitle:[weakSelf stateTitleWithState:state] forState:UIControlStateNormal];
    }];
}

- (IBAction)b3click:(id)sender {
    ZJDownloadSessionManager *manager = [ZJDownloadSessionManager manager];
    
    if (_downloadModel3.state == ZJDownloadStateReadying) {
        [manager cancelWithDownloadModel:_downloadModel3];
        return;
    }
    if ([manager isDownloadCompletedWithDownloadModel:_downloadModel3]) {
        [manager deleteFileWithDownloadModel:_downloadModel3];
    }
    if (_downloadModel3.state == ZJDownloadStateRunning) {
        [manager suspendWithDownloadModel:_downloadModel3];
        return;
    }
    
    [self startDownload3];
}

- (void)startDownload3
{
    ZJDownloadSessionManager *manager = [ZJDownloadSessionManager manager];
    __weak typeof(self) weakSelf = self;
    [manager startWithDownloadModel:_downloadModel3 progress:^(ZJDownloadProgress *progress) {
        weakSelf.v3.progress = progress.progress;
        weakSelf.l3.text = [weakSelf detailTextForDownloadProgress:progress];
    } state:^(ZJDownloadState state, NSString *filePath, NSError *error) {
        if (state == ZJDownloadStateCompleted) {
            weakSelf.v3.progress = 1.0;
            weakSelf.l3.text = [NSString stringWithFormat:@"progress  %.2f",weakSelf.v3.progress];
        }
        [weakSelf.b3 setTitle:[weakSelf stateTitleWithState:state] forState:UIControlStateNormal];
    }];
}


- (NSString *)detailTextForDownloadProgress:(ZJDownloadProgress *)progress
{
    NSString *fileSizeInUnits = [NSString stringWithFormat:@"%.2f %@",
                                 [ZJDownloadUtility calculateFileSizeInUnit:(unsigned long long)progress.totalBytesExpectedToWrite],
                                 [ZJDownloadUtility calculateUnit:(unsigned long long)progress.totalBytesExpectedToWrite]];
    
    NSMutableString *detailLabelText = [NSMutableString stringWithFormat:@"File Size: %@\nDownloaded: %.2f %@ (%.2f%%)\nSpeed: %.2f %@/sec\nLeftTime: %dsec",fileSizeInUnits,
                                        [ZJDownloadUtility calculateFileSizeInUnit:(unsigned long long)progress.totalBytesWritten],
                                        [ZJDownloadUtility calculateUnit:(unsigned long long)progress.totalBytesWritten],progress.progress*100,
                                        [ZJDownloadUtility calculateFileSizeInUnit:(unsigned long long) progress.speed],
                                        [ZJDownloadUtility calculateUnit:(unsigned long long)progress.speed]
                                        ,progress.remainingTime];
    return detailLabelText;
}



- (NSString *)stateTitleWithState:(ZJDownloadState)state
{
    switch (state) {
        case ZJDownloadStateReadying:
            return @"等待下载";
            break;
        case ZJDownloadStateRunning:
            return @"暂停下载";
            break;
        case ZJDownloadStateFailed:
            return @"下载失败";
            break;
        case ZJDownloadStateCompleted:
            return @"下载完成，重新下载";
            break;
        default:
            return @"开始下载";
            break;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)dowloadModel:(ZJDownloadModel *)downloadModel didUpdateProgress:(ZJDownloadProgress *)progress {
    NSLog(@"delegate progress %.3f",progress.progress);
}

- (void)downloadModel:(ZJDownloadModel *)downloadModel didChangeState:(ZJDownloadState)state filePath:(NSString *)filePath error:(NSError *)error {
     NSLog(@"delegate state %ld error%@ filePath%@",state,error,filePath);
}



@end
