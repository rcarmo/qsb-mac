This template builds a basic Objective-C plugin for Quick Search Box.

It requires that you set up two source trees in Xcode to compile. You will have 
to have the QuickSearchBox source tree downloaded to your machine. Instructions 
on getting the QSB source tree can be found here: 
http://code.google.com/p/qsb-mac/source/checkout

To set up the source trees in Xcode:
1) Go to "Xcode>Preferences" and click on the "Source Trees" icon.
2) Click on the "Plus" button on the left hand side of the window.
3) Set the "Setting Name" of your new tree to "QSBBUILDROOT"
4) Set the "Display Name" to "QSBBUILDROOT"
5) Set the path to the debug build directory for QSB. For me the path looks 
   like this "/Users/dmaclach/src/QuickSearchBox/QSB/build/Debug". If you use 
   a common build directory or some other customized build location, you will 
   have to set it here.
6) Click on the "Plus" button again
7) Set the "Setting Name" of your new tree to "QSBSRCROOT"
8) Set the "Display Name" to "QSBSRCROOT"
9) Set the path to the root directory for QSB. For me the path looks 
   like this "/Users/dmaclach/src/QuickSearchBox".

The plugin should now build cleanly.

You should only have to add the source trees to Xcode the first time you 
build a QSB plugin.

Before you start coding you plugin, you will want to make some changes in
the Info.plist file to make your plugin unique. Open the Info.plist file and
update the "CFBundleIdentifier" and the two "HGSExtensionIdentifier" entries 
to be something appropriate. You will find the "HGSExtensionIdentifier" entries
under the "HGSExtension" entry.

Now you are ready to add your own code in the two source files to actually
make your plugin do something.

If you are developing plugins, please join our mailing list:
http://groups.google.com/group/qsb-mac-dev

