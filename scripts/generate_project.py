#!/usr/bin/env python3
"""Generate the standalone Xcode project without third-party tooling."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
objects = {}

def oid(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()

def obj(object_name, isa, **fields):
    identifier = oid(object_name)
    objects[identifier] = dict(isa=isa, **fields)
    return identifier

def serialize(value, level=0):
    if isinstance(value, dict):
        return "{\n" + "".join("\t"*(level+1) + serialize(k) + " = " + serialize(v, level+1) + ";\n" for k, v in value.items()) + "\t"*level + "}"
    if isinstance(value, list):
        return "(" + ", ".join(serialize(v, level) for v in value) + ("," if value else "") + ")"
    return json.dumps(str(value), ensure_ascii=False)

def configurations(name, settings):
    configs = []
    for mode in ["Debug", "Release"]:
        merged = dict(settings)
        merged["SWIFT_OPTIMIZATION_LEVEL"] = "-Onone" if mode == "Debug" else "-O"
        if mode == "Debug": merged["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG"
        configs.append(obj(name+mode, "XCBuildConfiguration", buildSettings=merged, name=mode))
    return obj(name+"ConfigList", "XCConfigurationList", buildConfigurations=configs, defaultConfigurationIsVisible=0, defaultConfigurationName="Release")

product_refs = []
groups = []
targets = []
app_target_id = oid("RaftPersonalTarget")
common = dict(SWIFT_VERSION="5.0", IPHONEOS_DEPLOYMENT_TARGET="17.0", SDKROOT="iphoneos", TARGETED_DEVICE_FAMILY="1,2", CODE_SIGN_STYLE="Automatic", MARKETING_VERSION="0.1.2", CURRENT_PROJECT_VERSION="3")
for name, folder, product_type in [
    ("RaftPersonal", "App", "com.apple.product-type.application"),
    ("RaftPersonalTests", "Tests", "com.apple.product-type.bundle.unit-test"),
    ("RaftPersonalUITests", "UITests", "com.apple.product-type.bundle.ui-testing")
]:
    refs, builds = [], []
    for path in sorted((ROOT/folder).glob("*.swift")):
        ref = obj(str(path.relative_to(ROOT))+"Ref", "PBXFileReference", lastKnownFileType="sourcecode.swift", path=path.name, sourceTree="<group>")
        refs.append(ref)
        builds.append(obj(str(path.relative_to(ROOT))+"Build", "PBXBuildFile", fileRef=ref))
    resources = []
    if folder == "App":
        refs.append(obj("InfoRef", "PBXFileReference", lastKnownFileType="text.plist.xml", path="Info.plist", sourceTree="<group>"))
        assets = obj("AssetsRef", "PBXFileReference", lastKnownFileType="folder.assetcatalog", path="Assets.xcassets", sourceTree="<group>")
        refs.append(assets)
        resources.append(obj("AssetsBuild", "PBXBuildFile", fileRef=assets))
    groups.append(obj(folder+"Group", "PBXGroup", children=refs, path=folder, sourceTree="<group>"))
    phases = [obj(name+"Sources", "PBXSourcesBuildPhase", buildActionMask=2147483647, files=builds, runOnlyForDeploymentPostprocessing=0),
              obj(name+"Frameworks", "PBXFrameworksBuildPhase", buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0),
              obj(name+"Resources", "PBXResourcesBuildPhase", buildActionMask=2147483647, files=resources, runOnlyForDeploymentPostprocessing=0)]
    ext = ".app" if folder == "App" else ".xctest"
    product = obj(name+"Product", "PBXFileReference", explicitFileType="wrapper.application" if folder == "App" else "wrapper.cfbundle", includeInIndex=0, path=name+ext, sourceTree="BUILT_PRODUCTS_DIR")
    product_refs.append(product)
    settings = dict(common, PRODUCT_NAME="$(TARGET_NAME)", PRODUCT_BUNDLE_IDENTIFIER="com.example.raftpersonal"+("" if folder=="App" else "."+folder.lower()), SUPPORTED_PLATFORMS="iphoneos iphonesimulator")
    dependencies = []
    if folder == "App":
        settings.update(INFOPLIST_FILE="App/Info.plist", GENERATE_INFOPLIST_FILE="NO", ENABLE_TESTABILITY="YES", ASSETCATALOG_COMPILER_APPICON_NAME="AppIcon")
    else:
        settings.update(GENERATE_INFOPLIST_FILE="YES")
        if folder == "Tests": settings.update(TEST_HOST="$(BUILT_PRODUCTS_DIR)/RaftPersonal.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/RaftPersonal", BUNDLE_LOADER="$(TEST_HOST)")
        else: settings.update(TEST_TARGET_NAME="RaftPersonal")
        proxy = obj(name+"Proxy", "PBXContainerItemProxy", containerPortal=oid("Project"), proxyType=1, remoteGlobalIDString=app_target_id, remoteInfo="RaftPersonal")
        dependencies.append(obj(name+"Dependency", "PBXTargetDependency", target=app_target_id, targetProxy=proxy))
    targets.append(obj(name+"Target", "PBXNativeTarget", buildConfigurationList=configurations(name, settings), buildPhases=phases, buildRules=[], dependencies=dependencies, name=name, productName=name, productReference=product, productType=product_type))

products = obj("ProductsGroup", "PBXGroup", children=product_refs, name="Products", sourceTree="<group>")
rootgroup = obj("MainGroup", "PBXGroup", children=groups+[products], sourceTree="<group>")
projectsettings = dict(CLANG_ENABLE_MODULES="YES", CLANG_ENABLE_OBJC_ARC="YES", GCC_WARN_INHIBIT_ALL_WARNINGS="NO", DEBUG_INFORMATION_FORMAT="dwarf-with-dsym", SWIFT_EMIT_LOC_STRINGS="YES")
project = obj("Project", "PBXProject", attributes=dict(LastUpgradeCheck="2620", BuildIndependentTargetsInParallel="YES", TargetAttributes={t:dict(CreatedOnToolsVersion="26.2") for t in targets}), buildConfigurationList=configurations("Project", projectsettings), compatibilityVersion="Xcode 14.0", developmentRegion="en", knownRegions=["en", "Base", "zh-Hans"], mainGroup=rootgroup, productRefGroup=products, projectDirPath="", projectRoot="", targets=targets)
projectdir = ROOT/"RaftPersonal.xcodeproj"
projectdir.mkdir(exist_ok=True)
(projectdir/"project.pbxproj").write_text("// !$*UTF8*$!\n"+serialize(dict(archiveVersion=1, classes={}, objectVersion=56, objects=objects, rootObject=project))+"\n")
testables = "".join(f'<TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{oid(name+"Target")}" BuildableName="{name}.xctest" BlueprintName="{name}" ReferencedContainer="container:RaftPersonal.xcodeproj"/></TestableReference>' for name in ["RaftPersonalTests", "RaftPersonalUITests"])
appref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target_id}" BuildableName="RaftPersonal.app" BlueprintName="RaftPersonal" ReferencedContainer="container:RaftPersonal.xcodeproj"/>'
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2620" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{appref}</BuildActionEntry></BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>{testables}</Testables></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{appref}</BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{appref}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
schemes = projectdir/"xcshareddata/xcschemes"
schemes.mkdir(parents=True, exist_ok=True)
(schemes/"RaftPersonal.xcscheme").write_text(scheme)
print("Generated", projectdir)
