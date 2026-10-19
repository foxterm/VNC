Pod::Spec.new do |s|
  s.name             = 'VNC'
  s.version          = '0.1.0'
  s.summary          = 'VNC'
  s.description      = "VNC"
  s.homepage         = 'https://github.com/foxterm/VNC'
  s.license          = 'MIT'
  s.author           = { 'foxterm' => 'admin@foxterm.app' }
  s.source           = { :git => 'https://github.com/foxterm/VNC.git', :tag => s.version.to_s }
  s.ios.deployment_target = '17.0'
  s.osx.deployment_target = '14.0'
  s.swift_version = '5.10'
  s.source_files = ['Sources/**/*.{swift,h,c}']
  s.dependency 'libetos'
  s.dependency 'Sync'
  s.dependency 'Proxy'
  s.dependency 'Extension'
  s.dependency 'OpenSSL-Universal'
  s.vendored_frameworks = 'libvncclient.xcframework'
  s.frameworks = 'Security', 'CoreFoundation'
  s.libraries = 'z'
  s.osx.libraries = 'sasl2'
end
