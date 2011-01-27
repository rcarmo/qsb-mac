provider vermilion {
	/*
	 *  search-start and search-finish arguments:
	 *	   Extension ID (e.g., com.google.qsb.applications.source)
	 *	   Raw search query
	 *	   Unique (until search-finish) identifier to match starts an finishes
	 */
	probe search__start(char *,char *,char *);
	probe search__finish(char *,char *,char *);
};
