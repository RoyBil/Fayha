// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Generated file. Do not edit.
//

import PackageDescription

let package = Package(
    name: "FlutterGeneratedPluginSwiftPackage",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "FlutterGeneratedPluginSwiftPackage", type: .static, targets: ["FlutterGeneratedPluginSwiftPackage"])
    ],
    dependencies: [
        .package(name: "webview_flutter_wkwebview", path: "../.packages/webview_flutter_wkwebview-3.26.0"),
        .package(name: "url_launcher_ios", path: "../.packages/url_launcher_ios-6.3.4"),
        .package(name: "video_player_avfoundation", path: "../.packages/video_player_avfoundation-2.9.7"),
        .package(name: "shared_preferences_foundation", path: "../.packages/shared_preferences_foundation-2.5.4"),
        .package(name: "path_provider_foundation", path: "../.packages/path_provider_foundation-2.4.2"),
        .package(name: "app_links", path: "../.packages/app_links-6.4.1"),
        .package(name: "image_picker_ios", path: "../.packages/image_picker_ios-0.8.13"),
        .package(name: "geolocator_apple", path: "../.packages/geolocator_apple-2.3.13"),
        .package(name: "firebase_messaging", path: "../.packages/firebase_messaging-15.2.10"),
        .package(name: "firebase_core", path: "../.packages/firebase_core-3.15.2"),
        .package(name: "file_selector_ios", path: "../.packages/file_selector_ios-0.5.3+2"),
        .package(name: "audioplayers_darwin", path: "../.packages/audioplayers_darwin-6.4.0"),
        .package(name: "FlutterFramework", path: "../.packages/FlutterFramework")
    ],
    targets: [
        .target(
            name: "FlutterGeneratedPluginSwiftPackage",
            dependencies: [
                .product(name: "webview-flutter-wkwebview", package: "webview_flutter_wkwebview"),
                .product(name: "url-launcher-ios", package: "url_launcher_ios"),
                .product(name: "video-player-avfoundation", package: "video_player_avfoundation"),
                .product(name: "shared-preferences-foundation", package: "shared_preferences_foundation"),
                .product(name: "path-provider-foundation", package: "path_provider_foundation"),
                .product(name: "app-links", package: "app_links"),
                .product(name: "image-picker-ios", package: "image_picker_ios"),
                .product(name: "geolocator-apple", package: "geolocator_apple"),
                .product(name: "firebase-messaging", package: "firebase_messaging"),
                .product(name: "firebase-core", package: "firebase_core"),
                .product(name: "file-selector-ios", package: "file_selector_ios"),
                .product(name: "audioplayers-darwin", package: "audioplayers_darwin"),
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
