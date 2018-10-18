# Building RxSwift

This project has a dependencies on the external projects ReactiveX/RxSwift and RxSwiftCommunity/RxDataSources. Before you build this project, you will need to install and build these dependencies.

To do this, you'll need Carthage. You can install Carthage by following the instructions here:
	
	https://github.com/Carthage/Carthage/#installing-carthage

If you already have Homebrew installed, it's as simple as `brew install carthage`.

Once Carthage is installed, then open Terminal, change the directory to where you've installed "ios-app-architectures/Recordings-MVVM-C" and run:
	
	carthage update --platform iOS

You'll need to have an internet connection when you run that command. As I write this, the `--platform iOS` parameter is not just a time saver but necessary since Carthage tries to build for all platforms by default and the "RxCocoa-watchOS" variant isn't building at the moment.

The download and build will take a few minutes. Carthage will download into "~/Library/Caches/org.carthage.CarthageKit", checkout into "Carthage/Checkouts" and build into the "Carthage/Build" directory.

Once complete, you can open the Recordings.xcodeproj file and build and run as you would for any other project.

> NOTE: If you ever need to change the version of RxSwift or RxDataSources that the project uses, you might need to delete the Cartfile.resolved file to ensure that Carthage reprocesses its dependencies.
