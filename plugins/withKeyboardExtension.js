const { withXcodeProject, withEntitlementsPlist, createRunOncePlugin } = require('@expo/config-plugins');
const fs = require('fs');
const path = require('path');

const APP_GROUP_IDENTIFIER = 'group.com.writeflow.assistant';
const EXTENSION_NAME = 'WritingAssistantKeyboard';
const EXTENSION_BUNDLE_ID = 'com.writeflow.assistant.keyboard';

// 1. Add App Group entitlement to Main App
function withMainAppEntitlements(config) {
  return withEntitlementsPlist(config, (mod) => {
    if (!mod.modResults['com.apple.security.application-groups']) {
      mod.modResults['com.apple.security.application-groups'] = [];
    }
    const groups = mod.modResults['com.apple.security.application-groups'];
    if (!groups.includes(APP_GROUP_IDENTIFIER)) {
      groups.push(APP_GROUP_IDENTIFIER);
    }
    return mod;
  });
}

// 2. Add Native Keyboard Extension target to Xcode project
function withKeyboardTarget(config) {
  return withXcodeProject(config, (mod) => {
    const xcodeProject = mod.modResults;
    const projectRoot = mod.modRequest.projectRoot;
    const platformProjectRoot = mod.modRequest.platformProjectRoot;

    const sourceDir = path.join(projectRoot, 'plugins', 'keyboard-extension', 'ios');
    const targetDir = path.join(platformProjectRoot, EXTENSION_NAME);

    // Create target directory in ios/ if it doesn't exist
    if (!fs.existsSync(targetDir)) {
      fs.mkdirSync(targetDir, { recursive: true });
    }

    // Copy source files: Swift, Info.plist, entitlements
    const filesToCopy = ['KeyboardViewController.swift', 'Info.plist', 'KeyboardExtension.entitlements'];
    filesToCopy.forEach((file) => {
      const src = path.join(sourceDir, file);
      const destTarget = path.join(targetDir, file);
      const destRoot = path.join(platformProjectRoot, file);
      if (fs.existsSync(src)) {
        fs.copyFileSync(src, destTarget);
        fs.copyFileSync(src, destRoot);
      }
    });

    // Check if target already exists in project
    const existingTarget = xcodeProject.pbxTargetByName(EXTENSION_NAME);
    if (!existingTarget) {
      // Create new target for app extension
      const target = xcodeProject.addTarget(
        EXTENSION_NAME,
        'app_extension',
        EXTENSION_NAME,
        EXTENSION_BUNDLE_ID
      );

      // Add build phases: sources & frameworks
      xcodeProject.addBuildPhase(
        ['KeyboardViewController.swift'],
        'PBXSourcesBuildPhase',
        'Sources',
        target.uuid,
        'app_extension',
        EXTENSION_NAME
      );

      xcodeProject.addBuildPhase(
        [],
        'PBXFrameworksBuildPhase',
        'Frameworks',
        target.uuid,
        'app_extension',
        EXTENSION_NAME
      );

      // Add files to project group
      xcodeProject.addPbxGroup(
        filesToCopy,
        EXTENSION_NAME,
        EXTENSION_NAME
      );

      // Set target build settings
      const configurations = xcodeProject.pbxXCConfigurationList()[target.pbxNativeTarget.buildConfigurationList].buildConfigurations;
      configurations.forEach((configRef) => {
        const buildSettings = xcodeProject.pbxXCBuildConfigurationSection()[configRef.value].buildSettings;
        buildSettings.PRODUCT_NAME = EXTENSION_NAME;
        buildSettings.PRODUCT_BUNDLE_IDENTIFIER = EXTENSION_BUNDLE_ID;
        buildSettings.INFOPLIST_FILE = `${EXTENSION_NAME}/Info.plist`;
        buildSettings.CODE_SIGN_ENTITLEMENTS = `${EXTENSION_NAME}/KeyboardExtension.entitlements`;
        buildSettings.SWIFT_VERSION = '5.0';
        buildSettings.TARGETED_DEVICE_FAMILY = '"1,2"';
        buildSettings.IPHONEOS_DEPLOYMENT_TARGET = '15.1';
        buildSettings.CURRENT_PROJECT_VERSION = '1';
        buildSettings.MARKETING_VERSION = '1.0.0';
        buildSettings.SKIP_INSTALL = 'YES';
        buildSettings.ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES = 'NO';
      });
    }

    return mod;
  });
}

function withKeyboardExtension(config) {
  config = withMainAppEntitlements(config);
  config = withKeyboardTarget(config);
  return config;
}

module.exports = createRunOncePlugin(withKeyboardExtension, 'withKeyboardExtension', '1.0.0');
