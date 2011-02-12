//
//  Copyright (C) 2007-2009 Atsunori Saito <sai@yedo.com>,
//                2009-2011 Hayato Ito <hayatoito@gmail.com>.
//  All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import <objc/runtime.h>
#import <IOKit/hidsystem/IOLLEvent.h>

// According to: http://hg.pqrs.org/KeyRemap4MacBook/index.cgi/file/tip/src/core/bridge/keycode/data/KeyCode.data
#define KEY_MINUS 27
#define KEY_SLASH 44
#define KEY_SPACE 49

@interface NSApplication (Replace)
- (void)replace_sendEvent: (NSEvent*)event;
@end

@implementation NSApplication (Replace)

- (void)sendKeyEvent: (NSEvent*)event modifierFlags:(NSUInteger)flags 
             keyCode:(unsigned short)keyCode characters:(NSString*)characters
{
  NSEvent* newevent =
  [NSEvent keyEventWithType: [event type]
                   location: [event locationInWindow]
              modifierFlags: flags
                  timestamp: [event timestamp]
               windowNumber: [event windowNumber]
                    context: [event context]
                 characters: characters
charactersIgnoringModifiers: characters
                  isARepeat: [event isARepeat]
                    keyCode: keyCode];
  // NSLog(@"sending: %@", newevent);
  [self replace_sendEvent: newevent];
}

- (void)sendKeyEvent: (NSEvent*)event modifierFlags:(NSUInteger)flags
{
  [self sendKeyEvent: event modifierFlags: flags 
             keyCode: [event keyCode] characters: [event charactersIgnoringModifiers]];
}

- (void)replace_sendEvent: (NSEvent*)event
{
  NSEventType type = [event type];
  if (type != NSKeyDown && type != NSKeyUp) {
    [self replace_sendEvent: event];
    return;
  }    
  NSUInteger flags = [event modifierFlags];
  //NSLog(@"keycode: %d, characters: %@, unmodechars: %@",
  //	  [event keyCode], [event characters], [event charactersIgnoringModifiers]);
  
  bool isControlKeyPressed = flags & NSControlKeyMask;
  bool isCommandKeyPressed = flags & NSCommandKeyMask;
  bool isAlternateKeyPressed = flags & NSAlternateKeyMask;

  if (isCommandKeyPressed && isAlternateKeyPressed) {
    [self replace_sendEvent: event];
    return;
  }
  if (isControlKeyPressed) {
    // NSLog(@"Control is pressed");
    if ([event keyCode] == KEY_SLASH) {
      // NSLog(@"'Control + Slash' pressed");
      // Replace 'Control + Slash' with 'Control + Minus' so that undo can work
      // in Emacs.
      [self sendKeyEvent: event modifierFlags: flags 
                 keyCode: KEY_MINUS characters: @"-"];
      return;
    }
  }
  if (isCommandKeyPressed) {
    // NSLog(@"Command is pressed");
    if ([event keyCode] == KEY_SPACE) {
      /* Send 'Command + Space' as is. */
      [self replace_sendEvent: event];
      return;
    }
    NSUInteger newFlags = flags & (~NSCommandKeyMask) | NSAlternateKeyMask;
    if (flags & NX_DEVICELCMDKEYMASK) {
      newFlags = newFlags & (~NX_DEVICELCMDKEYMASK) | NX_DEVICELALTKEYMASK;
    }
    if (flags & NX_DEVICERCMDKEYMASK) {
      newFlags = newFlags & (~NX_DEVICERCMDKEYMASK) | NX_DEVICERALTKEYMASK;
    }
    [self sendKeyEvent:event modifierFlags:newFlags];
    return;
  }
  if (isAlternateKeyPressed) {
    // NSLog(@"Alternate is pressed");    
    NSUInteger newFlags = flags & (~NSAlternateKeyMask) | NSCommandKeyMask;
    if (flags & NX_DEVICELALTKEYMASK) {
      newFlags = newFlags & (~NX_DEVICELALTKEYMASK) | NX_DEVICELCMDKEYMASK;
    }
    if (flags & NX_DEVICERALTKEYMASK) {
      newFlags = newFlags & (~NX_DEVICERALTKEYMASK) | NX_DEVICERCMDKEYMASK;
    }
    [self sendKeyEvent:event modifierFlags:newFlags];
    return;
  }
  [self replace_sendEvent: event];
}

@end

@interface SwapOptCmdPlugin : NSObject
@end

@implementation SwapOptCmdPlugin

+ (SwapOptCmdPlugin*)sharedInstance
{
  static SwapOptCmdPlugin* plugin = nil;
  if (plugin == nil) plugin = [[SwapOptCmdPlugin alloc] init];
  return plugin;
}

+ (void)load
{
  Method org = class_getInstanceMethod([NSApplication class],
                                       @selector(sendEvent:));
  Method new = class_getInstanceMethod([NSApplication class],
                                       @selector(replace_sendEvent:));
  method_exchangeImplementations(org, new);
  [SwapOptCmdPlugin sharedInstance];
  NSLog(@"SwapOptCmd installed");
}

@end
