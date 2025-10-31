// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "RichEditor",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macCatalyst(.v17),
    ],
    products: [
        .library(name: "RichEditor", targets: ["RichEditor"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mischa-hildebrand/AlignedCollectionViewFlowLayout", from: "1.1.3"),
        .package(url: "https://github.com/Lakr233/AlertController", from: "2.0.2"),
        .package(url: "https://github.com/Lakr233/ColorfulX", from: "6.0.0"),
        .package(url: "https://github.com/Lakr233/ScrubberKit", from: "0.1.0"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.1.4"),
        .package(path: "../Logger"),
    ],
    targets: [
        .target(name: "RichEditor", dependencies: [
            .product(name: "AlertController", package: "AlertController"),
            .product(name: "AlignedCollectionViewFlowLayout", package: "AlignedCollectionViewFlowLayout"),
            .product(name: "ColorfulX", package: "ColorfulX"),
            .product(name: "ScrubberKit", package: "ScrubberKit"),
            .product(name: "OrderedCollections", package: "swift-collections"),
            .product(name: "Logger", package: "Logger"),
        ]),
    ]
)
