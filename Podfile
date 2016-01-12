source 'https://github.com/CocoaPods/Specs.git'

xcodeproj 'CoreXMPP/CoreXMPP.xcodeproj'

## iOS

target :CoreXMPPiOS, :exclusive => true do
    platform :ios, :deployment_target => '8.0'
    pod 'PureXML', :git => 'https://garage.tobias-kraentzer.de/diffusion/PX/purexml.git', :tag => '1.0.beta.5'
    pod 'SocketRocket', '~> 0.4'
end

target :CoreXMPPiOSTests, :exclusive => true do
    platform :ios, :deployment_target => '8.0'
    pod 'OCMockito', '~> 3.0.1'
end

## OSX

target :CoreXMPPOSX, :exclusive => true do
    platform :osx, :deployment_target => '10.10'
    pod 'PureXML', :git => 'https://garage.tobias-kraentzer.de/diffusion/PX/purexml.git', :tag => '1.0.beta.5'
    pod 'SocketRocket', '~> 0.4'
end

target :CoreXMPPOSXTests, :exclusive => true do
    platform :osx, :deployment_target => '10.10'
    pod 'OCMockito', '~> 3.0.1'
end
