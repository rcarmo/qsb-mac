//
// MDQueryPrivate.h
// Header file for undocumented MDQuery SPI
//

#include <CoreServices/CoreServices.h>

#ifdef __cplusplus
extern "C" {
#endif

// Type of the callback function used to enumerate the group of a result based
// on it's attributes.  
// 'attrs' A C array of attribute values for a result. The values occur in the
// array in the same order and position that the attribute names were passed in
// the valueAttrs array when the query was created. The values of the attributes
// might be NULL, if the attribute doesn't exist on a result or if read access
// to that attribute is not allowed.
// 'context' The user-defined context parameter given to 
//  _MDQuerySetGroupComparator().
//  Returns The function must return an index for a group to place the result in.
typedef CFIndex (*MDQueryPrivateGroupComparatorFunction)(const CFTypeRef attrs[], void *context);

// Converts a raw query string with operators into a valid spotlight query string.
extern CFStringRef _MDQueryCreateQueryString(CFAllocatorRef allocator, CFStringRef query);

// Sets whether the query looks through support files. Default is YES.
extern void MDQuerySetMatchesSupportFiles(MDQueryRef query, Boolean matches);

// Returns an array of dictionaries for the indexing status of the attached volumes.
extern CFArrayRef _MDCopyIndexingStatus(void);

// Set a function on the query that allows you to sort your results into various
// groups (numbered) depending on their attributes.
extern void _MDQuerySetGroupComparator(MDQueryRef query, MDQueryPrivateGroupComparatorFunction comparator, void *context);
  
// Returns a result count for all of the groups.
extern CFIndex _MDQueryGetResultCountForAllGroups(MDQueryRef query);

// Returns the number of groups. Some groups may have no results in them.
extern CFIndex _MDQueryGetGroupCount(MDQueryRef query);
  
// Returns the result count for a particular group.
extern CFIndex _MDQueryGetResultCountForGroup(MDQueryRef query, CFIndex group);

// Returns a result for a group at an index.
extern const void* _MDQueryGetResultAtIndexForGroup(MDQueryRef query, CFIndex idx, CFIndex group);
  
// Gets the attribute value for a result at an index in a group.
extern void* _MDQueryGetAttributeValueOfResultAtIndexForGroup(MDQueryRef query, CFStringRef name, CFIndex idx, CFIndex group);
  
// Returns true is spotlight is currently indexing a volume.
extern Boolean MDQueryPrivateIsSpotlightIndexing(void);

  
#ifdef __cplusplus
}
#endif
