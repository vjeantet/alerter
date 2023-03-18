//
//  main.m
//  alerter
//
//  Created by Valere JEANTET on 18/12/2015.
//  Copyright © 2020 JEANTET Valere. All rights reserved.
//

#import "AppDelegate.h"


AppDelegate * appDelegate ;

// When the termination signal is received, call the 'bye' method of the app delegate,
// which removes the current notification from the Notification Center
// and exits the program with a failure status code.
void SIGTERM_handler(int signum) {
    [appDelegate bye];
    exit(EXIT_FAILURE);
}

int main(int argc, char *argv[])
{
    signal(SIGTERM, SIGTERM_handler);
    signal(SIGINT, SIGTERM_handler);
    
    NSApplication * application = [NSApplication sharedApplication];
    appDelegate = [AppDelegate new];
    
    [application setDelegate:appDelegate];
    [application run];
    
    return EXIT_SUCCESS;
}

