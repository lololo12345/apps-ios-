#!/usr/bin/env python3
"""Generate a minimal Xcode 26 project for an iOS SwiftUI app.

The project uses file-system synchronized groups (objectVersion 77), so any file added to
<Name>/, <Name>Tests/ or <Name>UITests/ is picked up automatically without editing the project.

Usage:
    python3 tools/make_xcodeproj.py <AppDir> <Name> <bundle.id> [--display "Name"] [--info KEY=VALUE ...]
        [--shared <Folder>] [--widget]

Creates <AppDir>/<Name>.xcodeproj with targets <Name>, <Name>Tests, <Name>UITests and a shared scheme.
--shared adds a synchronized folder compiled into the app (and into the widget, if any).
--widget adds a WidgetKit extension target <Name>Widget (folder <Name>Widget/, Info.plist in
Config/<Name>Widget-Info.plist) embedded in the app.
"""
import argparse
import hashlib
import os


def make(app_dir: str, name: str, bundle_id: str, display: str, info: dict, info_plist: str | None,
         shared: str | None = None, widget: bool = False):
    def oid(key: str) -> str:
        return hashlib.md5(f"{name}:{key}".encode()).hexdigest()[:24].upper()

    keys = """PROJECT APPTARGET TESTTARGET UITESTTARGET APPPRODUCT TESTPRODUCT UITESTPRODUCT APPGROUP TESTGROUP
    UITESTGROUP MAINGROUP PRODUCTSGROUP APPSOURCES APPFRAMEWORKS APPRESOURCES TESTSOURCES TESTFRAMEWORKS
    TESTRESOURCES UITESTSOURCES UITESTFRAMEWORKS UITESTRESOURCES TESTPROXY TESTDEP UITESTPROXY UITESTDEP
    PROJDEBUG PROJRELEASE APPDEBUG APPRELEASE TESTDEBUG TESTRELEASE UITESTDEBUG UITESTRELEASE PROJCONFIGS
    APPCONFIGS TESTCONFIGS UITESTCONFIGS WIDGETTARGET WIDGETPRODUCT WIDGETGROUP SHAREDGROUP WIDGETSOURCES
    WIDGETFRAMEWORKS WIDGETRESOURCES WIDGETPROXY WIDGETDEP WIDGETDEBUG WIDGETRELEASE WIDGETCONFIGS EMBEDPHASE
    EMBEDFILE""".split()
    I = {k: oid(k) for k in keys}
    T, U, W = f"{name}Tests", f"{name}UITests", f"{name}Widget"

    def phase(key, isa):
        return f"""\t\t{I[key]} = {{
\t\t\tisa = {isa};
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""

    def settings(d):
        return "\n".join(f"\t\t\t\t{k} = {d[k]};" for k in sorted(d))

    common = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
        "CLANG_ANALYZER_NONNULL": "YES",
        "CLANG_CXX_LANGUAGE_STANDARD": '"gnu++20"',
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE",
        "COPY_PHASE_STRIP": "NO",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
        "GCC_C_LANGUAGE_STANDARD": "gnu17",
        "GCC_NO_COMMON_BLOCKS": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": "26.0",
        "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES",
        "SDKROOT": "iphoneos",
        "SWIFT_VERSION": "6.0",
    }
    pdebug = dict(common, **{
        "DEBUG_INFORMATION_FORMAT": "dwarf", "ENABLE_TESTABILITY": "YES", "GCC_OPTIMIZATION_LEVEL": "0",
        "GCC_PREPROCESSOR_DEFINITIONS": '(\n\t\t\t\t\t"DEBUG=1",\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t)',
        "ONLY_ACTIVE_ARCH": "YES", "SWIFT_ACTIVE_COMPILATION_CONDITIONS": '"DEBUG $(inherited)"',
        "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"',
    })
    prelease = dict(common, **{
        "DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"', "ENABLE_NS_ASSERTIONS": "NO",
        "SWIFT_COMPILATION_MODE": "wholemodule", "VALIDATE_PRODUCT": "YES",
    })
    app = {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "DEVELOPMENT_TEAM": '""',
        "ENABLE_PREVIEWS": "YES",
        "GENERATE_INFOPLIST_FILE": "YES",
        "INFOPLIST_KEY_CFBundleDisplayName": f'"{display}"',
        "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption": "NO",
        "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
        "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": "UIInterfaceOrientationPortrait",
        "LD_RUNPATH_SEARCH_PATHS": '(\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t\t"@executable_path/Frameworks",\n\t\t\t\t)',
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": f'"{bundle_id}"',
        "PRODUCT_NAME": '"$(TARGET_NAME)"',
        "SUPPORTED_PLATFORMS": '"iphoneos iphonesimulator"',
        "SUPPORTS_MACCATALYST": "NO",
        "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO",
        "SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD": "NO",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "TARGETED_DEVICE_FAMILY": "1",
    }
    if info_plist:
        app["INFOPLIST_FILE"] = f'"{info_plist}"'
    else:
        app["INFOPLIST_KEY_UILaunchScreen_Generation"] = "YES"
    for key, value in info.items():
        app[f"INFOPLIST_KEY_{key}"] = f'"{value}"'
    test = {
        "BUNDLE_LOADER": '"$(TEST_HOST)"', "CODE_SIGN_STYLE": "Automatic", "CURRENT_PROJECT_VERSION": "1",
        "DEVELOPMENT_TEAM": '""', "GENERATE_INFOPLIST_FILE": "YES", "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": f'"{bundle_id}.tests"', "PRODUCT_NAME": '"$(TARGET_NAME)"',
        "SWIFT_EMIT_LOC_STRINGS": "NO", "TARGETED_DEVICE_FAMILY": "1",
        "TEST_HOST": f'"$(BUILT_PRODUCTS_DIR)/{name}.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/{name}"',
    }
    uitest = {
        "CODE_SIGN_STYLE": "Automatic", "CURRENT_PROJECT_VERSION": "1", "DEVELOPMENT_TEAM": '""',
        "GENERATE_INFOPLIST_FILE": "YES", "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": f'"{bundle_id}.uitests"', "PRODUCT_NAME": '"$(TARGET_NAME)"',
        "SWIFT_EMIT_LOC_STRINGS": "NO", "TARGETED_DEVICE_FAMILY": "1", "TEST_TARGET_NAME": name,
    }

    widget_settings = {
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "CODE_SIGN_STYLE": "Automatic", "CURRENT_PROJECT_VERSION": "1", "DEVELOPMENT_TEAM": '""',
        "GENERATE_INFOPLIST_FILE": "YES", "INFOPLIST_FILE": f'"Config/{W}-Info.plist"',
        "INFOPLIST_KEY_CFBundleDisplayName": f'"{display}"',
        "LD_RUNPATH_SEARCH_PATHS": '(\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t\t"@executable_path/Frameworks",\n\t\t\t\t\t"@executable_path/../../Frameworks",\n\t\t\t\t)',
        "MARKETING_VERSION": "1.0", "PRODUCT_BUNDLE_IDENTIFIER": f'"{bundle_id}.widget"',
        "PRODUCT_NAME": '"$(TARGET_NAME)"', "SKIP_INSTALL": "YES", "SUPPORTED_PLATFORMS": '"iphoneos iphonesimulator"',
        "SUPPORTS_MACCATALYST": "NO", "SWIFT_EMIT_LOC_STRINGS": "YES", "TARGETED_DEVICE_FAMILY": "1",
    }

    def conf(key, label, d):
        return f"""\t\t{I[key]} /* {label} */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{settings(d)}
\t\t\t}};
\t\t\tname = {label};
\t\t}};
"""

    def clist(key, dk, rk, label):
        return f"""\t\t{I[key]} /* Build configuration list for {label} */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{I[dk]} /* Debug */,
\t\t\t\t{I[rk]} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
"""

    def target(key, tname, cfg, src, fw, res, group, product, ptype, deps, groups=(), extra_phases=()):
        dep_lines = "".join(f"\t\t\t\t{I[x]} /* PBXTargetDependency */,\n" for x in deps)
        ext = ".app" if ptype.endswith("application") else (".appex" if ptype.endswith("app-extension") else ".xctest")
        group_lines = "".join(f"\t\t\t\t{I[g]} /* {label} */,\n" for g, label in [(group, tname), *groups])
        phase_lines = "".join(f"\t\t\t\t{I[x]} /* {label} */,\n" for x, label in extra_phases)
        return f"""\t\t{I[key]} /* {tname} */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {I[cfg]};
\t\t\tbuildPhases = (
\t\t\t\t{I[src]} /* Sources */,
\t\t\t\t{I[fw]} /* Frameworks */,
\t\t\t\t{I[res]} /* Resources */,
{phase_lines}\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
{dep_lines}\t\t\t);
\t\t\tfileSystemSynchronizedGroups = (
{group_lines}\t\t\t);
\t\t\tname = {tname};
\t\t\tpackageProductDependencies = (
\t\t\t);
\t\t\tproductName = {tname};
\t\t\tproductReference = {I[product]} /* {tname}{ext} */;
\t\t\tproductType = "{ptype}";
\t\t}};
"""

    def proxy(key, remote="APPTARGET", remote_name=None):
        return f"""\t\t{I[key]} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = {I['PROJECT']} /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {I[remote]};
\t\t\tremoteInfo = {remote_name or name};
\t\t}};
"""

    def group(key, path):
        return f"""\t\t{I[key]} /* {path} */ = {{
\t\t\tisa = PBXFileSystemSynchronizedRootGroup;
\t\t\tpath = {path};
\t\t\tsourceTree = "<group>";
\t\t}};
"""

    app_groups = [("SHAREDGROUP", shared)] if shared else []
    app_deps = ["WIDGETDEP"] if widget else []
    app_phases = [("EMBEDPHASE", "Embed Foundation Extensions")] if widget else []
    w_proxy = proxy("WIDGETPROXY", "WIDGETTARGET", W) if widget else ""
    w_fileref = (f"\t\t{I['WIDGETPRODUCT']} /* {W}.appex */ = {{isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; "
                 f"includeInIndex = 0; path = {W}.appex; sourceTree = BUILT_PRODUCTS_DIR; }};\n") if widget else ""
    w_buildfile = (f"\n/* Begin PBXBuildFile section */\n\t\t{I['EMBEDFILE']} /* {W}.appex in Embed Foundation Extensions */ = "
                   f"{{isa = PBXBuildFile; fileRef = {I['WIDGETPRODUCT']} /* {W}.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};\n"
                   "/* End PBXBuildFile section */\n") if widget else ""
    w_copy = (f"""
/* Begin PBXCopyFilesBuildPhase section */
\t\t{I['EMBEDPHASE']} /* Embed Foundation Extensions */ = {{
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "";
\t\t\tdstSubfolderSpec = 13;
\t\t\tfiles = (
\t\t\t\t{I['EMBEDFILE']} /* {W}.appex in Embed Foundation Extensions */,
\t\t\t);
\t\t\tname = "Embed Foundation Extensions";
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXCopyFilesBuildPhase section */
""") if widget else ""
    extra_groups = (group("SHAREDGROUP", shared) if shared else "") + (group("WIDGETGROUP", W) if widget else "")
    main_children = (f"\t\t\t\t{I['SHAREDGROUP']} /* {shared} */,\n" if shared else "") + (f"\t\t\t\t{I['WIDGETGROUP']} /* {W} */,\n" if widget else "")
    product_children = f"\t\t\t\t{I['WIDGETPRODUCT']} /* {W}.appex */,\n" if widget else ""
    w_phases = (phase('WIDGETFRAMEWORKS', 'PBXFrameworksBuildPhase'), phase('WIDGETRESOURCES', 'PBXResourcesBuildPhase'), phase('WIDGETSOURCES', 'PBXSourcesBuildPhase')) if widget else ("", "", "")
    w_target = target('WIDGETTARGET', W, 'WIDGETCONFIGS', 'WIDGETSOURCES', 'WIDGETFRAMEWORKS', 'WIDGETRESOURCES', 'WIDGETGROUP', 'WIDGETPRODUCT',
                      'com.apple.product-type.app-extension', [], groups=app_groups) if widget else ""
    w_attr = f"\t\t\t\t\t{I['WIDGETTARGET']} = {{\n\t\t\t\t\t\tCreatedOnToolsVersion = 26.0;\n\t\t\t\t\t}};\n" if widget else ""
    w_target_ref = f"\t\t\t\t{I['WIDGETTARGET']} /* {W} */,\n" if widget else ""
    w_dep = f"""\t\t{I['WIDGETDEP']} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {I['WIDGETTARGET']} /* {W} */;
\t\t\ttargetProxy = {I['WIDGETPROXY']} /* PBXContainerItemProxy */;
\t\t}};
""" if widget else ""
    w_confs = (conf('WIDGETDEBUG', 'Debug', widget_settings) + conf('WIDGETRELEASE', 'Release', widget_settings)) if widget else ""
    w_clist = clist('WIDGETCONFIGS', 'WIDGETDEBUG', 'WIDGETRELEASE', W) if widget else ""

    pbx = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 77;
\tobjects = {{

/* Begin PBXContainerItemProxy section */
{proxy('TESTPROXY')}{proxy('UITESTPROXY')}{w_proxy}/* End PBXContainerItemProxy section */
{w_buildfile}{w_copy}
/* Begin PBXFileReference section */
\t\t{I['APPPRODUCT']} /* {name}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {name}.app; sourceTree = BUILT_PRODUCTS_DIR; }};
\t\t{I['TESTPRODUCT']} /* {T}.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = {T}.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};
\t\t{I['UITESTPRODUCT']} /* {U}.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = {U}.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};
{w_fileref}/* End PBXFileReference section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
{group('APPGROUP', name)}{group('TESTGROUP', T)}{group('UITESTGROUP', U)}{extra_groups}/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXFrameworksBuildPhase section */
{phase('APPFRAMEWORKS', 'PBXFrameworksBuildPhase')}{phase('TESTFRAMEWORKS', 'PBXFrameworksBuildPhase')}{phase('UITESTFRAMEWORKS', 'PBXFrameworksBuildPhase')}{w_phases[0]}/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t{I['MAINGROUP']} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{I['APPGROUP']} /* {name} */,
\t\t\t\t{I['TESTGROUP']} /* {T} */,
\t\t\t\t{I['UITESTGROUP']} /* {U} */,
{main_children}\t\t\t\t{I['PRODUCTSGROUP']} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{I['PRODUCTSGROUP']} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{I['APPPRODUCT']} /* {name}.app */,
\t\t\t\t{I['TESTPRODUCT']} /* {T}.xctest */,
\t\t\t\t{I['UITESTPRODUCT']} /* {U}.xctest */,
{product_children}\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
{target('APPTARGET', name, 'APPCONFIGS', 'APPSOURCES', 'APPFRAMEWORKS', 'APPRESOURCES', 'APPGROUP', 'APPPRODUCT', 'com.apple.product-type.application', app_deps, groups=app_groups, extra_phases=app_phases)}{target('TESTTARGET', T, 'TESTCONFIGS', 'TESTSOURCES', 'TESTFRAMEWORKS', 'TESTRESOURCES', 'TESTGROUP', 'TESTPRODUCT', 'com.apple.product-type.bundle.unit-test', ['TESTDEP'])}{target('UITESTTARGET', U, 'UITESTCONFIGS', 'UITESTSOURCES', 'UITESTFRAMEWORKS', 'UITESTRESOURCES', 'UITESTGROUP', 'UITESTPRODUCT', 'com.apple.product-type.bundle.ui-testing', ['UITESTDEP'])}{w_target}/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{I['PROJECT']} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 2600;
\t\t\t\tLastUpgradeCheck = 2600;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{I['APPTARGET']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 26.0;
\t\t\t\t\t}};
\t\t\t\t\t{I['TESTTARGET']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 26.0;
\t\t\t\t\t\tTestTargetID = {I['APPTARGET']};
\t\t\t\t\t}};
\t\t\t\t\t{I['UITESTTARGET']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 26.0;
\t\t\t\t\t\tTestTargetID = {I['APPTARGET']};
\t\t\t\t\t}};
{w_attr}\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {I['PROJCONFIGS']};
\t\t\tdevelopmentRegion = es;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\tes,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {I['MAINGROUP']};
\t\t\tminimizedProjectReferenceProxies = 1;
\t\t\tpreferredProjectObjectVersion = 77;
\t\t\tproductRefGroup = {I['PRODUCTSGROUP']} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{I['APPTARGET']} /* {name} */,
\t\t\t\t{I['TESTTARGET']} /* {T} */,
\t\t\t\t{I['UITESTTARGET']} /* {U} */,
{w_target_ref}\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
{phase('APPRESOURCES', 'PBXResourcesBuildPhase')}{phase('TESTRESOURCES', 'PBXResourcesBuildPhase')}{phase('UITESTRESOURCES', 'PBXResourcesBuildPhase')}{w_phases[1]}/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
{phase('APPSOURCES', 'PBXSourcesBuildPhase')}{phase('TESTSOURCES', 'PBXSourcesBuildPhase')}{phase('UITESTSOURCES', 'PBXSourcesBuildPhase')}{w_phases[2]}/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
\t\t{I['TESTDEP']} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {I['APPTARGET']} /* {name} */;
\t\t\ttargetProxy = {I['TESTPROXY']} /* PBXContainerItemProxy */;
\t\t}};
\t\t{I['UITESTDEP']} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {I['APPTARGET']} /* {name} */;
\t\t\ttargetProxy = {I['UITESTPROXY']} /* PBXContainerItemProxy */;
\t\t}};
{w_dep}/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
{conf('PROJDEBUG', 'Debug', pdebug)}{conf('PROJRELEASE', 'Release', prelease)}{conf('APPDEBUG', 'Debug', app)}{conf('APPRELEASE', 'Release', app)}{conf('TESTDEBUG', 'Debug', test)}{conf('TESTRELEASE', 'Release', test)}{conf('UITESTDEBUG', 'Debug', uitest)}{conf('UITESTRELEASE', 'Release', uitest)}{w_confs}/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
{clist('PROJCONFIGS', 'PROJDEBUG', 'PROJRELEASE', 'PBXProject')}{clist('APPCONFIGS', 'APPDEBUG', 'APPRELEASE', name)}{clist('TESTCONFIGS', 'TESTDEBUG', 'TESTRELEASE', T)}{clist('UITESTCONFIGS', 'UITESTDEBUG', 'UITESTRELEASE', U)}{w_clist}/* End XCConfigurationList section */
\t}};
\trootObject = {I['PROJECT']} /* Project object */;
}}
"""

    def bref(key, tname, product):
        return f"""<BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{I[key]}"
               BuildableName = "{product}"
               BlueprintName = "{tname}"
               ReferencedContainer = "container:{name}.xcodeproj">
            </BuildableReference>"""

    scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            {bref('APPTARGET', name, name + '.app')}
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
      <Testables>
         <TestableReference
            skipped = "NO"
            parallelizable = "YES">
            {bref('TESTTARGET', T, T + '.xctest')}
         </TestableReference>
         <TestableReference
            skipped = "NO"
            parallelizable = "NO">
            {bref('UITESTTARGET', U, U + '.xctest')}
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         {bref('APPTARGET', name, name + '.app')}
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         {bref('APPTARGET', name, name + '.app')}
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
    proj = os.path.join(app_dir, f"{name}.xcodeproj")
    os.makedirs(os.path.join(proj, "project.xcworkspace"), exist_ok=True)
    os.makedirs(os.path.join(proj, "xcshareddata", "xcschemes"), exist_ok=True)
    with open(os.path.join(proj, "project.pbxproj"), "w") as f:
        f.write(pbx)
    with open(os.path.join(proj, "project.xcworkspace", "contents.xcworkspacedata"), "w") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n<Workspace\n   version = "1.0">\n   <FileRef\n      location = "self:">\n   </FileRef>\n</Workspace>\n')
    with open(os.path.join(proj, "xcshareddata", "xcschemes", f"{name}.xcscheme"), "w") as f:
        f.write(scheme)
    for sub in (name, T, U, *([shared] if shared else []), *([W] if widget else [])):
        os.makedirs(os.path.join(app_dir, sub), exist_ok=True)
    if widget:
        plist = os.path.join(app_dir, "Config", f"{W}-Info.plist")
        os.makedirs(os.path.dirname(plist), exist_ok=True)
        if not os.path.exists(plist):
            with open(plist, "w") as f:
                f.write('<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
                        '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n<dict>\n'
                        '\t<key>NSExtension</key>\n\t<dict>\n\t\t<key>NSExtensionPointIdentifier</key>\n'
                        '\t\t<string>com.apple.widgetkit-extension</string>\n\t</dict>\n</dict>\n</plist>\n')
    print(f"Created {proj}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("app_dir")
    parser.add_argument("name")
    parser.add_argument("bundle_id")
    parser.add_argument("--display")
    parser.add_argument("--info-plist", help="Partial Info.plist path relative to the project (e.g. Config/App-Info.plist)")
    parser.add_argument("--info", action="append", default=[], help="Extra INFOPLIST_KEY_ entries as KEY=VALUE")
    parser.add_argument("--shared", help="Extra synchronized folder compiled into the app and the widget")
    parser.add_argument("--widget", action="store_true", help="Add a WidgetKit extension embedded in the app")
    args = parser.parse_args()
    extra = dict(item.split("=", 1) for item in args.info)
    make(args.app_dir, args.name, args.bundle_id, args.display or args.name, extra, args.info_plist, args.shared, args.widget)
