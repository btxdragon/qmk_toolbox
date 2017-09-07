//
//  Flashing.m
//  qmk_toolbox
//
//  Created by Jack Humbert on 9/5/17.
//  Copyright © 2017 QMK. All rights reserved.
//

#import "Flashing.h"

@interface Flashing ()

@property Printing * printer;

@end

@implementation Flashing

@synthesize DFUConnected;
@synthesize HalfkayConnected;
@synthesize CaterinaConnected;
@synthesize STM32Connected;
@synthesize delegate;

- (id)initWithPrinter:(Printing *)p {
    if (self = [super init]) {
        _printer = p;
    }
    return self;
}

- (NSString *)runProcess:(NSString *)command withArgs:(NSArray<NSString *> *)args {

    [_printer print:[NSString stringWithFormat:@"%@ %@", command, [args componentsJoinedByString:@" "]] withType:MessageType_Command];
    //int pid = [[NSProcessInfo processInfo] processIdentifier];
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = pipe.fileHandleForReading;

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = [[NSBundle mainBundle] pathForResource:command ofType:@""];
    task.arguments = args;
    task.standardOutput = pipe;
    task.standardError = pipe;

    [task launch];

    NSData *data = [file readDataToEndOfFile];
    [file closeFile];

    NSString *grepOutput = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    // NSLog (@"grep returned:\n%@", grepOutput);
    [_printer printResponse:grepOutput withType:MessageType_Command];
    return grepOutput;
}

- (void)flash:(NSString *)mcu withFile:(NSString *)file {
    if ([delegate canFlash:DFU])
        [self flashDFU:mcu withFile:file];
    else if ([delegate canFlash:Caterina])
        [self flashCaterina:mcu withFile:file];
    else if ([delegate canFlash:Halfkay])
        [self flashHalfkay:mcu withFile:file];
    else if ([delegate canFlash:STM32])
        [self flashSTM32WithFile:file];
}

- (void)reset:(NSString *)mcu {
    if ([delegate canFlash:DFU])
        [self resetDFU:mcu];
    else if ([delegate canFlash:Halfkay])
        [self resetHalfkay:mcu];
}

- (void)flashDFU:(NSString *)mcu withFile:(NSString *)file {
    NSString * result;
    result = [self runProcess:@"dfu-programmer" withArgs:@[mcu, @"erase", @"--force"]];
    result = [self runProcess:@"dfu-programmer" withArgs:@[mcu, @"flash", file]];
    if ([result containsString:@"Bootloader and code overlap."]) {
        result = [self runProcess:@"dfu-programmer" withArgs:@[mcu, @"reset"]];
    } else {
        [_printer print:@"File is too large for device" withType:MessageType_Error];
    }
}

- (void)resetDFU:(NSString *)mcu {
    [self runProcess:@"dfu-programmer" withArgs:@[mcu, @"reset"]];
}

- (void)flashCaterina:(NSString *)mcu withFile:(NSString *)file {
    [self runProcess:@"avrdude" withArgs:@[@"-p", mcu, @"-c", @"avr109", @"-U", [NSString stringWithFormat:@"flash:w:\"%@\":i", file], @"-P"]];
}

- (void)flashHalfkay:(NSString *)mcu withFile:(NSString *)file {
    [self runProcess:@"teensy_loader_cli" withArgs:@[[@"-mmcu=" stringByAppendingString:mcu], file, @"-v"]];
}

- (void)resetHalfkay:(NSString *)mcu {
    [self runProcess:@"teensy_loader_cli" withArgs:@[[@"-mmcu=" stringByAppendingString:mcu], @"-bv"]];
}

- (void)flashSTM32WithFile:(NSString *)file {
    [self runProcess:@"dfu-util" withArgs:@[@"-a", @"0", @"-d", @"0482:df11", @"-s", @"0x8000000", @"-D", file]];
}

@end