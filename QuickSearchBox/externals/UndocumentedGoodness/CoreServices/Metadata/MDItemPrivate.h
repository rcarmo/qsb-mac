//
// MDItemPrivate.h
// Header file for undocumented MDItem SPI
//

#import <CoreFoundation/CoreFoundation.h>

#ifdef __cplusplus
extern "C" {
#endif

enum {
  MDItemPrivateGroupFirst= 1,
  MDItemPrivateGroupMessage = 1,
  MDItemPrivateGroupContact = 2,
  MDItemPrivateGroupSystemPref = 3,
  MDItemPrivateGroupFont = 4,
  MDItemPrivateGroupWeb = 5,
  MDItemPrivateGroupCalendar = 6,
  MDItemPrivateGroupMovie = 7,
  MDItemPrivateGroupApplication = 8,
  MDItemPrivateGroupDirectory = 9,
  MDItemPrivateGroupMusic = 10,
  MDItemPrivateGroupPDF = 11,
  MDItemPrivateGroupPresentation = 12,
  MDItemPrivateGroupImage = 13,
  MDItemPrivateGroupDocument = 14,
  MDItemPrivateGroupLast = 15,
}; 
  
typedef CFOptionFlags MDItemPrivateGroup;

// Spotlight Group ID.
extern const CFStringRef kMDItemPrivateAttributeGroupId;

#ifdef __cplusplus
}
#endif
