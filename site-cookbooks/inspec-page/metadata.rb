name 'inspec-page'
maintainer 'Christoph Hartmann'
maintainer_email 'chris@lollyrock.com'
license 'Apache-2.0'
description 'Installs and configures nginx'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version '0.1.0'

depends "nginx"
depends "openssl"