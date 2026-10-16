#!/usr/bin/env python3
"""Generate a dependency-free Xcode app project. Run after adding source files."""
from pathlib import Path
import hashlib
import plistlib
root = Path(__file__).resolve().parent.parent
def ident(s): return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def quote(s): return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'
objects = []
def obj(k, value): objects.append(f'{ident(k)} = {{ {value} }};'); return ident(k)
sources = sorted(root.glob('DevPet/**/*.swift'))
builds, files = [], []
for file in sources:
    rel = str(file.relative_to(root))
    ref = obj(rel, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quote(rel)}; sourceTree = SOURCE_ROOT;')
    files.append(ref); builds.append(obj('build:'+rel, f'isa = PBXBuildFile; fileRef = {ref};'))
resources = []
for path, typ in [('DevPet/Resources/Assets.xcassets', 'folder.assetcatalog'), ('Docs/INTEGRATIONS.md', 'net.daringfireball.markdown'), ('DevPet/Resources/Sprites', 'folder')]:
    ref = obj(path, f'isa = PBXFileReference; lastKnownFileType = {typ}; path = {quote(path)}; sourceTree = SOURCE_ROOT;')
    files.append(ref); resources.append(obj('build:'+path, f'isa = PBXBuildFile; fileRef = {ref};'))
product = obj('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = DevPet.app; sourceTree = BUILT_PRODUCTS_DIR;')
group = obj('group', f'isa = PBXGroup; children = ({",".join(files)},{ident("products")}); sourceTree = "<group>";')
obj('products', f'isa = PBXGroup; children = ({product}); name = Products; sourceTree = "<group>";')
src = obj('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)}); runOnlyForDeploymentPostprocessing = 0;')
res = obj('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(resources)}); runOnlyForDeploymentPostprocessing = 0;')
framework = obj('frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
for scope in ['project', 'target']:
    for config in ['Debug', 'Release']:
        settings = 'MACOSX_DEPLOYMENT_TARGET = 14.0; SDKROOT = macosx; SWIFT_VERSION = 5.0; CLANG_ENABLE_MODULES = YES;'
        if scope == 'target':
            settings += ' PRODUCT_BUNDLE_IDENTIFIER = app.devpet.mac; PRODUCT_NAME = DevPet; INFOPLIST_FILE = DevPet/Resources/Info.plist; CODE_SIGN_STYLE = Automatic; ENABLE_HARDENED_RUNTIME = YES; ENABLE_APP_SANDBOX = NO; ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; COMBINE_HIDPI_IMAGES = YES; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks";'
        settings += ' SWIFT_OPTIMIZATION_LEVEL = ' + ('"-Onone"; DEBUG_INFORMATION_FORMAT = dwarf; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;' if config == 'Debug' else '"-O"; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";')
        obj(scope+config, f'isa = XCBuildConfiguration; buildSettings = {{ {settings} }}; name = {config};')
    obj(scope+'configs', f'isa = XCConfigurationList; buildConfigurations = ({ident(scope+"Debug")},{ident(scope+"Release")}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target = obj('target', f'isa = PBXNativeTarget; buildConfigurationList = {ident("targetconfigs")}; buildPhases = ({src},{framework},{res}); buildRules = (); dependencies = (); name = DevPet; productName = DevPet; productReference = {product}; productType = "com.apple.product-type.application";')
project = obj('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1600; }}; buildConfigurationList = {ident("projectconfigs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,tr,Base); mainGroup = {group}; productRefGroup = {ident("products")}; projectDirPath = ""; projectRoot = ""; targets = ({target});')
folder = root/'DevPet.xcodeproj'; folder.mkdir(exist_ok=True)
(folder/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+f'\n}}; rootObject = {project}; }}\n')
scheme = folder/'xcshareddata/xcschemes'; scheme.mkdir(parents=True, exist_ok=True)
(scheme/'DevPet.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="DevPet.app" BlueprintName="DevPet" ReferencedContainer="container:DevPet.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="DevPet.app" BlueprintName="DevPet" ReferencedContainer="container:DevPet.xcodeproj"/></BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
info = {'CFBundleName':'DevPet','CFBundleDisplayName':'DevPet','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundlePackageType':'APPL','CFBundleShortVersionString':'1.6.1','CFBundleVersion':'27','CFBundleIconFile':'AppIcon','LSMinimumSystemVersion':'14.0','LSUIElement':True,'NSHighResolutionCapable':True,'NSPrincipalClass':'NSApplication','CFBundleDevelopmentRegion':'en','CFBundleLocalizations':['en','tr']}
(root/'DevPet/Resources/Info.plist').write_bytes(plistlib.dumps(info))
(root/'DevPet/Resources/Assets.xcassets/Contents.json').write_text('{"info":{"author":"xcode","version":1}}\n')
print('Generated DevPet.xcodeproj')
