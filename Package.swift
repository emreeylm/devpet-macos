// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "DevPet", platforms: [.macOS(.v14)], products: [.executable(name: "DevPet", targets: ["DevPet"])], targets: [
    .target(name: "DevPetCore", path: "DevPet/Core"),
    .executableTarget(name: "DevPet", dependencies: ["DevPetCore"], path: "DevPet", exclude: ["Core", "Resources/Assets.xcassets", "Resources/Info.plist"], resources: [.copy("Resources/Sprites")]),
    .testTarget(name: "DevPetCoreTests", dependencies: ["DevPetCore"], path: "Tests/DevPetCoreTests")
])
