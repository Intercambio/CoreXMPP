source 'https://github.com/CocoaPods/Specs.git'

xcodeproj 'CoreXMPP/CoreXMPP.xcodeproj'

## iOS

target :CoreXMPPiOS do
    platform :ios, :deployment_target => '8.0'
    pod 'PureXML', :git => 'https://garage.tobias-kraentzer.de/diffusion/PX/purexml.git', :tag => '1.0.beta.5'
    pod 'SocketRocket', '~> 0.4'
    pod 'CocoaLumberjack', '~> 2.2.0'
end

target :CoreXMPPiOSTests do
    platform :ios, :deployment_target => '8.0'
    pod 'OCMockito', '~> 3.0.1'
end

## OSX

target :CoreXMPPOSX do
    platform :osx, :deployment_target => '10.10'
    pod 'PureXML', :git => 'https://garage.tobias-kraentzer.de/diffusion/PX/purexml.git', :tag => '1.0.beta.5'
    pod 'SocketRocket', '~> 0.4'
    pod 'CocoaLumberjack', '~> 2.2.0'
end

target :CoreXMPPOSXTests do
    platform :osx, :deployment_target => '10.10'
    pod 'OCMockito', '~> 3.0.1'
end
