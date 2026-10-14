#!/usr/bin/env python3
"""Generate the Xcode project; preserve existing signing and bundle identities."""
from pathlib import Path
import hashlib, json, subprocess
ROOT = Path(__file__).resolve().parents[1]
objects = {}
previous = {}
projectfile = ROOT/'RaftPersonal.xcodeproj/project.pbxproj'
if projectfile.exists():
    data = json.loads(subprocess.check_output(['plutil','-convert','json','-o','-',str(projectfile)]))
    old = data['objects']
    for target in old.values():
        if target.get('isa') != 'PBXNativeTarget': continue
        configs = old[target['buildConfigurationList']]['buildConfigurations']
        for key in configs:
            value = old[key]
            previous[(target['name'],value['name'])] = value.get('buildSettings',{})

def oid(name): return hashlib.sha256(name.encode()).hexdigest()[:24].upper()
def obj(object_name, isa, **fields):
    identifier = oid(object_name); objects[identifier] = dict(isa=isa, **fields); return identifier

def serialize(value, level=0):
    if isinstance(value, dict): return '{\n'+''.join('\t'*(level+1)+serialize(k)+' = '+serialize(v,level+1)+';\n' for k,v in value.items())+'\t'*level+'}'
    if isinstance(value,list): return '('+', '.join(serialize(v,level) for v in value)+(',' if value else '')+')'
    return json.dumps(str(value),ensure_ascii=False)

def configurations(name, settings):
    configs=[]
    for mode in ['Debug','Release']:
        merged=dict(settings, SWIFT_OPTIMIZATION_LEVEL='-Onone' if mode=='Debug' else '-O')
        if mode=='Debug': merged['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='DEBUG'
        old=previous.get((name,mode),{})
        for key in ['DEVELOPMENT_TEAM','PRODUCT_BUNDLE_IDENTIFIER','CODE_SIGN_STYLE','CODE_SIGN_IDENTITY','PROVISIONING_PROFILE_SPECIFIER']:
            if key in old: merged[key]=old[key]
        if name=='RaftStatusWidget':
            app=previous.get(('RaftPersonal',mode),{})
            if 'DEVELOPMENT_TEAM' in app: merged['DEVELOPMENT_TEAM']=app['DEVELOPMENT_TEAM']
        configs.append(obj(name+mode,'XCBuildConfiguration',buildSettings=merged,name=mode))
    return obj(name+'ConfigList','XCConfigurationList',buildConfigurations=configs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')

app_bundle=previous.get(('RaftPersonal','Debug'),{}).get('PRODUCT_BUNDLE_IDENTIFIER','com.example.raftpersonal')
app_group=previous.get(('RaftPersonal','Debug'),{}).get('RAFT_APP_GROUP_ID','group.com.example.raftpersonal')
common=dict(SWIFT_VERSION='5.0', IPHONEOS_DEPLOYMENT_TARGET='17.0', SDKROOT='iphoneos', TARGETED_DEVICE_FAMILY='1,2', CODE_SIGN_STYLE='Automatic', MARKETING_VERSION='0.2.1', CURRENT_PROJECT_VERSION='7', RAFT_APP_GROUP_ID=app_group)
shared_refs=[]
for path in sorted((ROOT/'Shared').glob('*.swift')):
    shared_refs.append(obj(str(path.relative_to(ROOT))+'Ref','PBXFileReference',lastKnownFileType='sourcecode.swift',path=path.name,sourceTree='<group>'))
groups=[obj('SharedGroup','PBXGroup',children=shared_refs,path='Shared',sourceTree='<group>')]
products=[]; targets=[]
app_id=oid('RaftPersonalTarget'); widget_id=oid('RaftStatusWidgetTarget')
widget_product=oid('RaftStatusWidgetProduct')
for name,folder,kind in [('RaftPersonal','App','com.apple.product-type.application'),('RaftStatusWidget','Widget','com.apple.product-type.app-extension'),('RaftPersonalTests','Tests','com.apple.product-type.bundle.unit-test'),('RaftPersonalUITests','UITests','com.apple.product-type.bundle.ui-testing')]:
    refs=[]; builds=[]; resources=[]; deps=[]
    for path in sorted((ROOT/folder).glob('*.swift')):
        ref=obj(str(path.relative_to(ROOT))+'Ref','PBXFileReference',lastKnownFileType='sourcecode.swift',path=path.name,sourceTree='<group>'); refs.append(ref)
        builds.append(obj(name+str(path.relative_to(ROOT))+'Build','PBXBuildFile',fileRef=ref))
    if folder in ['App','Widget']:
        for ref in shared_refs: builds.append(obj(name+ref+'Build','PBXBuildFile',fileRef=ref))
        refs.append(obj(folder+'InfoRef','PBXFileReference',lastKnownFileType='text.plist.xml',path='Info.plist',sourceTree='<group>'))
        entitle='RaftPersonal.entitlements' if folder=='App' else 'RaftWidget.entitlements'
        refs.append(obj(folder+'EntitleRef','PBXFileReference',lastKnownFileType='text.plist.entitlements',path=entitle,sourceTree='<group>'))
    if folder=='App':
        asset=obj('AssetsRef','PBXFileReference',lastKnownFileType='folder.assetcatalog',path='Assets.xcassets',sourceTree='<group>');refs.append(asset)
        resources.append(obj('AssetsBuild','PBXBuildFile',fileRef=asset))
    groups.append(obj(folder+'Group','PBXGroup',children=refs,path=folder,sourceTree='<group>'))
    phases=[obj(name+'Sources','PBXSourcesBuildPhase',buildActionMask=2147483647,files=builds,runOnlyForDeploymentPostprocessing=0),obj(name+'Frameworks','PBXFrameworksBuildPhase',buildActionMask=2147483647,files=[],runOnlyForDeploymentPostprocessing=0),obj(name+'Resources','PBXResourcesBuildPhase',buildActionMask=2147483647,files=resources,runOnlyForDeploymentPostprocessing=0)]
    ext='.app' if folder=='App' else '.appex' if folder=='Widget' else '.xctest'
    filetype='wrapper.application' if folder=='App' else 'wrapper.app-extension' if folder=='Widget' else 'wrapper.cfbundle'
    product=obj(name+'Product','PBXFileReference',explicitFileType=filetype,includeInIndex=0,path=name+ext,sourceTree='BUILT_PRODUCTS_DIR');products.append(product)
    settings=dict(common,PRODUCT_NAME='$(TARGET_NAME)',PRODUCT_BUNDLE_IDENTIFIER=app_bundle+('' if folder=='App' else '.widget' if folder=='Widget' else '.'+folder.lower()),SUPPORTED_PLATFORMS='iphoneos iphonesimulator')
    if folder=='App':
        settings.update(INFOPLIST_FILE='App/Info.plist',GENERATE_INFOPLIST_FILE='NO',ENABLE_TESTABILITY='YES',ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon',CODE_SIGN_ENTITLEMENTS='App/RaftPersonal.entitlements')
        embed=obj('EmbedWidgetBuild','PBXBuildFile',fileRef=widget_product,settings={'ATTRIBUTES':['RemoveHeadersOnCopy']})
        phases.append(obj('EmbedWidgetPhase','PBXCopyFilesBuildPhase',buildActionMask=2147483647,dstPath='',dstSubfolderSpec=13,files=[embed],name='Embed App Extensions',runOnlyForDeploymentPostprocessing=0))
        proxy=obj('WidgetDependencyProxy','PBXContainerItemProxy',containerPortal=oid('Project'),proxyType=1,remoteGlobalIDString=widget_id,remoteInfo='RaftStatusWidget')
        deps.append(obj('WidgetDependency','PBXTargetDependency',target=widget_id,targetProxy=proxy))
    elif folder=='Widget':
        settings.update(INFOPLIST_FILE='Widget/Info.plist',GENERATE_INFOPLIST_FILE='NO',CODE_SIGN_ENTITLEMENTS='Widget/RaftWidget.entitlements',APPLICATION_EXTENSION_API_ONLY='YES',SKIP_INSTALL='YES',LD_RUNPATH_SEARCH_PATHS='$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks')
    else:
        settings.update(GENERATE_INFOPLIST_FILE='YES')
        if folder=='Tests':settings.update(TEST_HOST='$(BUILT_PRODUCTS_DIR)/RaftPersonal.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/RaftPersonal',BUNDLE_LOADER='$(TEST_HOST)')
        else:settings.update(TEST_TARGET_NAME='RaftPersonal')
        proxy=obj(name+'Proxy','PBXContainerItemProxy',containerPortal=oid('Project'),proxyType=1,remoteGlobalIDString=app_id,remoteInfo='RaftPersonal')
        deps.append(obj(name+'Dependency','PBXTargetDependency',target=app_id,targetProxy=proxy))
    targets.append(obj(name+'Target','PBXNativeTarget',buildConfigurationList=configurations(name,settings),buildPhases=phases,buildRules=[],dependencies=deps,name=name,productName=name,productReference=product,productType=kind))
productgroup=obj('ProductsGroup','PBXGroup',children=products,name='Products',sourceTree='<group>')
rootgroup=obj('MainGroup','PBXGroup',children=groups+[productgroup],sourceTree='<group>')
projectsettings=dict(CLANG_ENABLE_MODULES='YES',CLANG_ENABLE_OBJC_ARC='YES',GCC_WARN_INHIBIT_ALL_WARNINGS='NO',DEBUG_INFORMATION_FORMAT='dwarf-with-dsym',SWIFT_EMIT_LOC_STRINGS='YES')
attrs={t:dict(CreatedOnToolsVersion='26.2') for t in targets}
for t in [app_id,widget_id]: attrs[t]['SystemCapabilities']={'com.apple.ApplicationGroups.iOS':{'enabled':1}}
project=obj('Project','PBXProject',attributes=dict(LastUpgradeCheck='2620',BuildIndependentTargetsInParallel='YES',TargetAttributes=attrs),buildConfigurationList=configurations('Project',projectsettings),compatibilityVersion='Xcode 14.0',developmentRegion='en',knownRegions=['en','Base','zh-Hans'],mainGroup=rootgroup,productRefGroup=productgroup,projectDirPath='',projectRoot='',targets=targets)
projectfile.parent.mkdir(exist_ok=True)
projectfile.write_text('// !$*UTF8*$!\n'+serialize(dict(archiveVersion=1,classes={},objectVersion=56,objects=objects,rootObject=project))+'\n')
appref=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_id}" BuildableName="RaftPersonal.app" BlueprintName="RaftPersonal" ReferencedContainer="container:RaftPersonal.xcodeproj"/>'
testables=''.join(f'<TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{oid(name+"Target")}" BuildableName="{name}.xctest" BlueprintName="{name}" ReferencedContainer="container:RaftPersonal.xcodeproj"/></TestableReference>' for name in ['RaftPersonalTests','RaftPersonalUITests'])
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2620" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{appref}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>{testables}</Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO"><BuildableProductRunnable runnableDebuggingMode="0">{appref}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO"><BuildableProductRunnable runnableDebuggingMode="0">{appref}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>'''
schemes=projectfile.parent/'xcshareddata/xcschemes';schemes.mkdir(parents=True,exist_ok=True);(schemes/'RaftPersonal.xcscheme').write_text(scheme)
print('Generated App + Widget project; existing signing identities preserved.')
