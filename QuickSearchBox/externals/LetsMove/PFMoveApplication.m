//
//  PFMoveApplication.m, version 1.3
//  LetsMove
//
//  Created by Andy Kim at Potion Factory LLC on 9/17/09
//
//  The contents of this file are dedicated to the public domain.
//
//  Contributors:
//	  Andy Kim
//    John Brayton
//    Chad Sellers
//    Kevin LaCoste
//    Rasmus Andersson / Spotify
//

#import "PFMoveApplication.h"
#import <Security/Security.h>

#ifndef NSAppKitVersionNumber10_4
#define NSAppKitVersionNumber10_4 824
#endif


static NSString *AlertSuppressKey = @"moveToApplicationsFolderAlertSuppress";


// Helper functions
static NSString *PreferredInstallLocation(BOOL *isUserDirectory);
static BOOL IsInApplicationsFolder(NSString *path);
static BOOL IsInDownloadsFolder(NSString *path);
static BOOL Trash(NSString *path);
static BOOL AuthorizedInstall(NSString *srcPath, NSString *dstPath, BOOL *canceled);
static BOOL CopyBundle(NSString *srcPath, NSString *dstPath);

// Main worker function
void PFMoveToApplicationsFolderIfNecessary(void) {
	// Skip if user suppressed the alert before
	if ([[NSUserDefaults standardUserDefaults] boolForKey:AlertSuppressKey]) return;

	// Path of the bundle
	NSString *bundlePath = [[NSBundle mainBundle] bundlePath];

	// Skip if the application is already in some Applications folder
	if (IsInApplicationsFolder(bundlePath)) return;

	// File Manager
	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL bundlePathIsWritable = [fm isWritableFileAtPath:bundlePath];

	// Guess if we have launched from a disk image
	BOOL isLaunchedFromDMG = ([bundlePath hasPrefix:@"/Volumes/"] && !bundlePathIsWritable);

	// Fail silently if there's no access to delete the original application
	if (!isLaunchedFromDMG && !bundlePathIsWritable) {
		NSLog(@"INFO -- No access to delete the app. Not offering to move it.");
		return;
	}

	// Since we are good to go, get the preferred installation directory.
	BOOL installToUserApplications = NO;
	NSString *applicationsDirectory = PreferredInstallLocation(&installToUserApplications);
	NSString *bundleName = [bundlePath lastPathComponent];
	NSString *destinationPath = [applicationsDirectory stringByAppendingPathComponent:bundleName];

	// Check if we need admin password to write to the Applications directory
	BOOL needAuthorization = ([fm isWritableFileAtPath:applicationsDirectory] == NO);

	// Setup the alert
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];

  [alert setMessageText:NSLocalizedStringFromTable(@"^Install Quick Search Box", 
                                                   @"MoveApplication", nil)];
  
  NSString *informativeText = nil;

  if ((IsInDownloadsFolder(bundlePath))) {
    informativeText = NSLocalizedStringFromTable(@"^Quick Search Box is currently located in your Downloads folder.", 
                                                 @"MoveApplication", nil);
    informativeText = [informativeText stringByAppendingString:@" "];
  } else {
    informativeText = @"";
  }
  
  NSString *moveText = nil;
  if (installToUserApplications) {
    moveText = NSLocalizedStringFromTable(@"^Would you like to move it to the Applications folder in your Home folder?", 
                                          @"MoveApplication", nil);
  }
  else {
    moveText = NSLocalizedStringFromTable(@"^Would you like to move it to the Applications folder?", 
                                          @"MoveApplication", nil);
  }

  informativeText = [informativeText stringByAppendingString:moveText];
  
  if (needAuthorization) {
    informativeText = [informativeText stringByAppendingString:@"\n\n"];
    informativeText = [informativeText stringByAppendingString:NSLocalizedStringFromTable(@"^Note that this will require an administrator password.", 
                                                                                          @"MoveApplication", nil)];
  }
    
  [alert setInformativeText:informativeText];

  // Add accept button
  [alert addButtonWithTitle:NSLocalizedStringFromTable(@"^Move to Applications Folder", 
                                                       @"MoveApplication", nil)];

  // Add deny button
  NSButton *cancelButton = [alert addButtonWithTitle:NSLocalizedStringFromTable(@"^Do Not Move", 
                                                                                @"MoveApplication", nil)];
  [cancelButton setKeyEquivalent:@"\e"];

  // Setup suppression button
  [alert setShowsSuppressionButton:YES];
  [[[alert suppressionButton] cell] setControlSize:NSSmallControlSize];
  [[[alert suppressionButton] cell] setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];

	// Activate app -- work-around for focus issues related to "scary file from internet" OS dialog.
	if (![NSApp isActive]) {
		[NSApp activateIgnoringOtherApps:YES];
	}
	
	if ([alert runModal] == NSAlertFirstButtonReturn) {
		NSLog(@"Moving myself to the Applications folder");

		if (needAuthorization) {
			BOOL authorizationCanceled;

			if (!AuthorizedInstall(bundlePath, destinationPath, &authorizationCanceled)) {
				if (authorizationCanceled) {
					NSLog(@"INFO -- Not moving because user canceled authorization");
					return;
				}
				else {
					NSLog(@"ERROR -- Could not copy myself to /Applications with authorization");
					goto fail;
				}
			}
		}
		else {
			// If a copy already exists in the Applications folder, put it in the Trash
			if ([fm fileExistsAtPath:destinationPath]) {
				if (!Trash([applicationsDirectory stringByAppendingPathComponent:bundleName])) goto fail;
			}

 			if (!CopyBundle(bundlePath, destinationPath)) {
				NSLog(@"ERROR -- Could not copy myself to /Applications");
				goto fail;
			}
		}

		// Trash the original app. It's okay if this fails.
		// NOTE: This final delete does not work if the source bundle is in a network mounted volume.
		//       Calling rm or file manager's delete method doesn't work either. It's unlikely to happen
		//       but it'd be great if someone could fix this.
		if (!isLaunchedFromDMG && !Trash(bundlePath)) {
			NSLog(@"WARNING -- Could not delete application after moving it to Applications folder");
		}

		// Relaunch.
		// The shell script waits until the original app process terminates.
		// This is done so that the relaunched app opens as the front-most app.
		int pid = [[NSProcessInfo processInfo] processIdentifier];

		// Command run just before running open /final/path
		NSString *preOpenCmd = @"";

		// OS X >=10.5:
		// Before we launch the new app, clear xattr:com.apple.quarantine to avoid
		// duplicate "scary file from the internet" dialog.
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_4
		if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4) {
			preOpenCmd = [NSString stringWithFormat:@"/usr/bin/xattr -d -r com.apple.quarantine '%@';", destinationPath];
		}
#endif

		NSString *script = [NSString stringWithFormat:@"(while [ `ps -p %d | wc -l` -gt 1 ]; do sleep 0.1; done; %@ open '%@') &", pid, preOpenCmd, destinationPath];

		[NSTask launchedTaskWithLaunchPath:@"/bin/sh" arguments:[NSArray arrayWithObjects:@"-c", script, nil]];

		// Launched from within a DMG? -- unmount (if no files are open after 5 seconds,
		// otherwise leave it mounted).
		if (isLaunchedFromDMG) {
			script = [NSString stringWithFormat:@"(sleep 5 && hdiutil detach '%@') &", [bundlePath stringByDeletingLastPathComponent]];
			[NSTask launchedTaskWithLaunchPath:@"/bin/sh" arguments:[NSArray arrayWithObjects:@"-c", script, nil]];
		}

		[NSApp terminate:nil];
	}
	else {
		if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4) {
			// Save the alert suppress preference if checked
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_4
			if ([[alert suppressionButton] state] == NSOnState) {
				[[NSUserDefaults standardUserDefaults] setBool:YES forKey:AlertSuppressKey];
			}
#endif
		}
		else {
			// Always suppress after the first decline on 10.4 since there is no suppression checkbox
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:AlertSuppressKey];
		}
	}

	return;

fail:
  // Show failure message
  alert = [[[NSAlert alloc] init] autorelease];
  [alert setMessageText:NSLocalizedStringFromTable(@"^Could not move Quick Search Box to the Applications folder.", 
                                                   @"MoveApplication", nil)];
  [alert runModal];
}

#pragma mark -
#pragma mark Helper Functions

static NSString *PreferredInstallLocation(BOOL *isUserDirectory) {
	// Return the preferred install location.
	// Assume that if the user has a ~/Applications folder, they'd prefer their
	// applications to go there.

	NSFileManager *fm = [NSFileManager defaultManager];

	NSArray *userApplicationsDirs 
    = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, 
                                          NSUserDomainMask, 
                                          YES);

	if ([userApplicationsDirs count] > 0) {
		NSString *userApplicationsDir = [userApplicationsDirs objectAtIndex:0];
		BOOL isDirectory;

		if ([fm fileExistsAtPath:userApplicationsDir 
                 isDirectory:&isDirectory] && isDirectory) {
			if (isUserDirectory) *isUserDirectory = YES;
			return userApplicationsDir;
		}
	}

	// No user Applications directory. 
  // Return the machine local Applications directory.
	if (isUserDirectory) *isUserDirectory = NO;
	return [NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, 
                                              NSLocalDomainMask, 
                                              YES) lastObject];
}

static BOOL IsInApplicationsFolder(NSString *path) {
	NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, 
                                                      NSAllDomainsMask, 
                                                      YES);

	for (NSString *appDirPath in dirs) {
		if ([path hasPrefix:appDirPath]) return YES;
	}

	return NO;
}

static BOOL IsInDownloadsFolder(NSString *path) {
  NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, 
                                                      NSAllDomainsMask, 
                                                      YES);
  for (NSString *downloadsDirPath in dirs) {
    if ([path hasPrefix:downloadsDirPath]) return YES;
  }
  return NO;
}

static BOOL Trash(NSString *path) {
  NSWorkspace *ws = [NSWorkspace sharedWorkspace];
	if ([ws performFileOperation:NSWorkspaceRecycleOperation
                        source:[path stringByDeletingLastPathComponent]
                   destination:@""
                         files:[NSArray arrayWithObject:[path lastPathComponent]]
                           tag:NULL]) {
		return YES;
	}
	else {
		NSLog(@"ERROR -- Could not trash '%@'", path);
		return NO;
	}
}

static BOOL AuthorizedInstall(NSString *srcPath, 
                              NSString *dstPath, 
                              BOOL *canceled) {
	if (canceled) *canceled = NO;

	// Make sure that the destination path is an app bundle. 
  // We're essentially running 'sudo rm -rf'
	// so we really don't want to screw this up.
	if (![dstPath hasSuffix:@".app"]) return NO;

	// Do some more checks
  NSCharacterSet *ws = [NSCharacterSet whitespaceCharacterSet];
	if ([[dstPath stringByTrimmingCharactersInSet:ws] length] == 0) return NO;
	if ([[srcPath stringByTrimmingCharactersInSet:ws] length] == 0) return NO;

	int pid, status;
	AuthorizationRef myAuthorizationRef;

	// Get the authorization
	OSStatus err = AuthorizationCreate(NULL, 
                                     kAuthorizationEmptyEnvironment, 
                                     kAuthorizationFlagDefaults, 
                                     &myAuthorizationRef);
	if (err != errAuthorizationSuccess) return NO;

	AuthorizationItem myItems = {kAuthorizationRightExecute, 0, NULL, 0};
	AuthorizationRights myRights = {1, &myItems};
	AuthorizationFlags myFlags = (kAuthorizationFlagInteractionAllowed 
                                | kAuthorizationFlagPreAuthorize
                                | kAuthorizationFlagExtendRights);

	err = AuthorizationCopyRights(myAuthorizationRef, 
                                &myRights, NULL, myFlags, NULL);
	if (err != errAuthorizationSuccess) {
		if (err == errAuthorizationCanceled && canceled)
			*canceled = YES;
		goto fail;
	}

	// Delete the destination
  const char *rmArgs[] = {"-rf", [dstPath UTF8String], NULL};
  err = AuthorizationExecuteWithPrivileges(myAuthorizationRef, 
                                           "/bin/rm", 
                                           kAuthorizationFlagDefaults, 
                                           (char * const *)rmArgs, NULL);
  if (err != errAuthorizationSuccess) goto fail;

  // Wait until it's done
  pid = wait(&status);
  // We don't care about exit status as the destination most likely does not
  // exist
  if (pid == -1 || !WIFEXITED(status)) goto fail; 

	// Copy

  const char *cpArgs[] = {
    "-pR", 
    [srcPath fileSystemRepresentation], 
    [dstPath fileSystemRepresentation], 
    NULL
  };
  err = AuthorizationExecuteWithPrivileges(myAuthorizationRef, 
                                           "/bin/cp", 
                                           kAuthorizationFlagDefaults, 
                                           (char * const *)cpArgs, NULL);
  if (err != errAuthorizationSuccess) goto fail;

  // Wait until it's done
  pid = wait(&status);
  if (pid == -1 || !WIFEXITED(status) || WEXITSTATUS(status)) goto fail;

	AuthorizationFree(myAuthorizationRef, kAuthorizationFlagDefaults);
	return YES;

fail:
	AuthorizationFree(myAuthorizationRef, kAuthorizationFlagDefaults);
	return NO;
}

static BOOL CopyBundle(NSString *srcPath, NSString *dstPath) {
  BOOL wasGood = YES;
	NSFileManager *fm = [NSFileManager defaultManager];
  NSError *error = nil;
  if (![fm copyItemAtPath:srcPath toPath:dstPath error:&error]) {
    NSLog(@"Could not copy '%@' to '%@' (%@)", srcPath, dstPath, error);
    wasGood = NO;
  }
  return wasGood;
}
