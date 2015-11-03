source 'https://github.com/CocoaPods/Specs.git'

xcodeproj 'CoreXMPP/CoreXMPP.xcodeproj'

target :CoreXMPPiOSTests, :exclusive => true do
    platform :ios, :deployment_target => '8.0'
    pod 'PureXML', :git => 'https://garage.tobias-kraentzer.de/diffusion/PX/purexml.git', :tag => '1.0.beta.2'
end

target :CoreXMPPOSXTests, :exclusive => true do
    platform :osx, :deployment_target => '10.10'
    pod 'PureXML', :git => 'https://garage.tobias-kraentzer.de/diffusion/PX/purexml.git', :tag => '1.0.beta.2'
end
