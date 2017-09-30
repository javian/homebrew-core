class Php < Formula
  desc "General-purpose scripting language"
  homepage "https://php.net"
  url "https://github.com/php/php-src/archive/php-7.1.8.tar.gz"
  sha256 "f3be4262203fa9db3d126832a1632e9a80e52e313f4230218c392d6a9178c368"

  # javian: not sure about the origin of this so I'll keep it commented for now. Could it have something to do with building extensions ?
  # javian: This has been in the formula for 8+ years but have found no proof that it is needed anymore
  # So PHP extensions don't report missing symbols
  # skip_clean "bin", "sbin"

  option "with-imap-uw", "Build PHP IMAP extension"
  option "with-thread-safety", "Build with thread safety"

  depends_on "autoconf" => :build
  depends_on "bison" => :build
  depends_on "re2c" => :build
  depends_on "imap-uw" => :optional
  depends_on "libtool" => :run # javian: mcrypt requirement
  depends_on "aspell"
  depends_on "argon2"
  depends_on "curl" if MacOS.version < :lion
  depends_on "enchant"
  depends_on "freetds"
  depends_on "freetype"
  depends_on "gettext"
  depends_on "gmp"
  depends_on "homebrew/apache/httpd24"
  depends_on "icu4c"
  depends_on "jpeg"
  depends_on "libpng"
  depends_on "libpq"
  depends_on "mcrypt"
  depends_on "net-snmp"
  depends_on "openssl"
  depends_on "pcre"
  depends_on "tidy-html5"
  depends_on "unixodbc"
  depends_on "webp"

  needs :cxx11

  # Fixes the pear .lock permissions issue that keeps it from operating correctly.
  # Thanks mistym & #machomebrew
  # javian: is this still needed ?
  skip_clean "lib/php/.lock"

  def install
    ENV.cxx11
    config_path = etc/"php/#{version.to_s.split(".")[0..1].join(".")}"
    # Prevent PHP from harcoding sed shim path
    ENV["lt_cv_path_SED"] = "sed"

    args = %W[
      --prefix=#{prefix}
      --localstatedir=#{var}
      --sysconfdir=#{config_path}
      --with-config-file-path=#{config_path}
      --with-config-file-scan-dir=#{config_path}/conf.d
      --mandir=#{man}
      --enable-bcmath
      --enable-calendar
      --enable-dba
      --enable-dtrace
      --enable-exif
      --enable-ftp
      --enable-fpm
      --enable-gd-native-ttf
      --enable-intl
      --enable-mbregex
      --enable-mbstring
      --enable-mysqlnd
      --enable-pcntl
      --enable-phpdbg
      --enable-phpdbg-webhelper
      --enable-shmop
      --enable-soap
      --enable-sockets
      --enable-sysvmsg
      --enable-sysvsem
      --enable-sysvshm
      --enable-wddx
      --enable-zip
      --libexecdir=#{libexec}
      --with-apxs2=#{Formula["httpd24"].opt_prefix}/bin/apxs
      --with-bz2=/usr
      --with-enchant=#{Formula["enchant"].opt_prefix}
      --with-freetype-dir=#{Formula["freetype"].opt_prefix}
      --with-gmp=#{Formula["gmp"].opt_prefix}
      --with-gd
      --with-gettext=#{Formula["gettext"].opt_prefix}
      --with-fpm-user=_www
      --with-fpm-group=_www
      --with-iconv-dir=/usr
      --with-icu-dir=#{Formula["icu4c"].opt_prefix}
      --with-jpeg-dir=#{Formula["jpeg"].opt_prefix}
      --with-kerberos=/usr
      --with-ldap=shared
      --with-ldap-sasl=/usr
      --with-libxml-dir=/usr
      --with-mhash
      --with-mcrypt=shared,#{Formula["mcrypt"].opt_prefix}
      --with-mysql-sock=/tmp/mysql.sock
      --with-mysqli=mysqlnd
      --with-pdo-mysql=mysqlnd
      --with-pdo-odbc=unixODBC,#{Formula["unixodbc"].opt_prefix}
      --with-ndbm=/usr
      --with-openssl=#{Formula["openssl"].opt_prefix}
      --with-password-argon2=#{Formula["argon2"].opt_prefix}
      --with-pdo-dblib=#{Formula["freetds"].opt_prefix}
      --with-pdo-pgsql=#{Formula["libpq"].opt_prefix}
      --with-pgsql=#{Formula["libpq"].opt_prefix}
      --with-png-dir=#{Formula["libpng"].opt_prefix}
      --with-pspell=#{Formula["aspell"].opt_prefix}
      --with-snmp
      --with-tidy=shared,#{Formula["tidy-html5"].opt_prefix}
      --with-unixODBC=#{Formula["unixodbc"].opt_prefix}
      --with-webp-dir=#{Formula["webp"].opt_prefix}
      --with-pic
      --with-xmlrpc
      --with-zlib=/usr
      --with-libedit
      --with-xsl=/usr
    ]

    if MacOS.version < :lion
      args << "--with-curl=#{Formula["curl"].opt_prefix}"
    else
      args << "--with-curl"
    end

    if build.with? "imap-uw"
      args << "--with-imap=#{Formula["imap-uw"].opt_prefix}"
      args << "--with-imap-ssl=#{Formula["openssl"].opt_prefix}"
    end

    args << "--enable-maintainer-zts" if build.with? "thread-safety"

    system "./buildconf", "--force"
    system "./configure", *args

    inreplace "Makefile",
      /^INSTALL_IT = \$\(mkinstalldirs\) '([^']+)' (.+) LIBEXECDIR=([^\s]+) (.+)$/,
      "INSTALL_IT = $(mkinstalldirs) '#{libexec}/apache2' \\2 LIBEXECDIR='#{libexec}/apache2' \\4"

    # https://github.com/phpbrew/phpbrew/commit/18ef766d0e013ee87ac7d86e338ebec89fbeb445
    # Unsure if this is still needed
    inreplace "Makefile" do |s|
      s.change_make_var! "EXTRA_LIBS", "\\1 -lstdc++"
    end

    system "make"
    ENV.deparallelize # parallel install fails on some systems
    system "make", "install"

    # Prefer relative symlink instead of absolute for relocatable bottles
    ln_s "phar.phar", bin+"phar", :force => true

    # Install new php.ini unless one exists
    config_path.install "./php.ini-development" => "php.ini" unless File.exist? config_path+"php.ini"

    chmod 0755, "sapi/fpm/init.d.php-fpm"
    sbin.install "sapi/fpm/init.d.php-fpm" => "php#{version.to_s[0..2].delete(".")}-fpm"

    if File.exist?("sapi/cgi/fpm/php-fpm")
      chmod 0755, "sapi/cgi/fpm/php-fpm"
      sbin.install "sapi/cgi/fpm/php-fpm" => "php#{version.to_s[0..2].delete(".")}-fpm"
    end

    if !File.exist?(config_path+"php-fpm.d/www.conf") && File.exist?(config_path+"php-fpm.d/www.conf.default")
      mv(config_path+"php-fpm.d/www.conf.default", config_path+"php-fpm.d/www.conf")
    end

    unless File.exist?(config_path+"php-fpm.conf")
      if File.exist?("sapi/fpm/php-fpm.conf")
        config_path.install "sapi/fpm/php-fpm.conf"
      end

      if File.exist?("sapi/cgi/fpm/php-fpm.conf")
        config_path.install "sapi/cgi/fpm/php-fpm.conf"
      end

      inreplace config_path+"php-fpm.conf" do |s|
        s.sub!(/^;?daemonize\s*=.+$/, "daemonize = no")
      end
    end
  end

  def caveats
    s = []

    s << <<-EOS.undent
      To enable PHP in Apache add the following to httpd.conf and restart Apache:
          LoadModule php7_module #{HOMEBREW_PREFIX}/opt/php#{version.to_s[0..2].delete(".")}/libexec/apache2/libphp7.so

          <FilesMatch \.php$>
              SetHandler application/x-httpd-php
          </FilesMatch>

      Finally, check DirectoryIndex includes index.php
          DirectoryIndex index.php index.html
    EOS

    s << <<-EOS.undent
      The php.ini file can be found in:
          #{etc}/php/#{version.to_s.split(".")[0..1].join(".")}/php.ini
    EOS

    s.join "\n"
  end

  def post_install
    # Belongs to fpm config
    (prefix/"var/log").mkpath
    touch prefix/"var/log/php-fpm.log"

    # Fix pecl/pear permissions
    chmod 0755, lib/"php/.channels"
    chmod 0644, Dir.glob(lib/"php/.channels/**/*")

    %w[
      php/.depdblock
      php/.filemap
      php/.depdb
    ].each do |f|
      chmod 0644, lib/f
    end

    php_ini = "#{etc}/php/#{version.to_s.split(".")[0..1].join(".")}"
    system bin/"pear", "config-set", "php_ini", php_ini, "system"

    %w[
      ldap
      mcrypt
      tidy
      opcache
    ].each do |e|
      config_path = (etc/"php/#{version.to_s.split(".")[0..1].join(".")}/conf.d/ext-#{e}.ini")
      extension_type = (e == "opcache") ? "zend_extension" : "extension"
      if File.exist? config_path
        inreplace config_path do |s|
          s.gsub /#{extension_type}=.*$/, "#{extension_type}=#{Utils.popen_read("php-config --extension-dir").chomp}/#{e}.so"
        end
      else
        config_path.write <<-EOS.undent
        [#{e}]
        #{extension_type}="#{Utils.popen_read("php-config --extension-dir").chomp}/#{e}.so"
      EOS
      end
    end
  end

  plist_options :startup => true, :manual => "php-fpm --nodaemonize --fpm-config #{HOMEBREW_PREFIX}/etc/php/#{version.to_s.split(".")[0..1].join(".")}/php-fpm.conf"

  def plist; <<-EOPLIST.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>KeepAlive</key>
        <true/>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>ProgramArguments</key>
        <array>
          <string>#{opt_sbin}/php-fpm</string>
          <string>--nodaemonize</string>
          <string>--fpm-config</string>
          <string>#{HOMEBREW_PREFIX}/etc/php/#{version.to_s.split(".")[0..1].join(".")}/php-fpm.conf</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>WorkingDirectory</key>
        <string>#{var}</string>
        <key>StandardErrorPath</key>
        <string>#{opt_prefix}/var/log/php-fpm.log</string>
      </dict>
    </plist>
    EOPLIST
  end

  test do
    system "#{bin}/php", "-i"
    system "#{sbin}/php-fpm", "-y", "#{etc}/php/#{version.to_s.split(".")[0..1].join(".")}/php-fpm.conf", "-t"
  end
end
