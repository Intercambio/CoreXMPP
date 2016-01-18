# coding: utf-8
Pod::Spec.new do |s|
  s.name                = "CoreXMPP"
  s.version             = "1.0.beta.1"
  s.summary             = "XMPP Framework"
  
  s.authors             = { "Tobias Kräntzer" => "info@tobias-kraentzer.de" }
  s.license             = { :type => 'BSD', :file => 'LICENSE.md' }
  
  s.homepage            = "https://garage.tobias-kraentzer.de/diffusion/XMPP/"
  s.social_media_url 	= 'https://twitter.com/anagrom_ataf'

  s.source              = { :git => "https://garage.tobias-kraentzer.de/diffusion/XMPP/corexmpp.git", :tag => "#{s.version}" }
                            
  s.requires_arc          = true
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'

  s.source_files        = 'CoreXMPP/CoreXMPP/**/*.{h,m,c}'
  
  s.dependency  'PureXML', '~> 1.0.beta.5'
  s.dependency  'SocketRocket', '~> 0.4'
  s.dependency  'CocoaLumberjack', '~> 2.2.0'
end
