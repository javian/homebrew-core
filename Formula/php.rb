class Php < Formula
  desc "General-purpose scripting language"
  homepage "https://php.net/"
  url "https://github.com/php/php-src/archive/php-7.1.9.tar.gz"
  sha256 "4bb7acacee5034705673004010789d6313e7d7f490a270308ec75d3391c4afea"

  devel do
    url "https://github.com/php/php-src/archive/php-7.2.0RC2.tar.gz"
    sha256 "a40e0aceb0f389b88883297a5b180a84f345756431057496c7d697f7a0c08013"

    depends_on "libsodium"
    depends_on "argon2"
  end

  option "with-thread-safety", "Build with thread safety"

  depends_on "autoconf" => :build
  depends_on "bison" => :build
  depends_on "re2c" => :build
  depends_on "libtool" => :run
  depends_on "aspell"
  depends_on "curl" if MacOS.version < :lion
  depends_on "enchant"
  depends_on "freetds"
  depends_on "freetype"
  depends_on "gettext"
  depends_on "gmp"
  depends_on "httpd"
  depends_on "imap-uw"
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

  def install
    ENV.cxx11
    config_path = etc/"php/#{php_version}"
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
      --with-apxs2=#{Formula["httpd24"].opt_bin}/apxs
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
      --with-imap=shared,#{Formula["imap-uw"].opt_prefix}
      --with-imap-ssl=#{Formula["openssl"].opt_prefix}
      --with-mhash
      --with-mcrypt=shared,#{Formula["mcrypt"].opt_prefix}
      --with-mysql-sock=/tmp/mysql.sock
      --with-mysqli=mysqlnd
      --with-pdo-mysql=mysqlnd
      --with-pdo-odbc=unixODBC,#{Formula["unixodbc"].opt_prefix}
      --with-ndbm=/usr
      --with-openssl=#{Formula["openssl"].opt_prefix}
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

    args << "--enable-maintainer-zts" if build.with? "thread-safety"

    if build.devel?
      args += %W[
        --with-password-argon2=#{Formula["argon2"].opt_prefix}
        --with-sodium=#{Formula["libsodium"].opt_prefix}
      ]
    end

    system "./buildconf", "--force"
    system "./configure", *args

    inreplace "Makefile" do |s|
      s.gsub! /^INSTALL_IT = \$\(mkinstalldirs\) '([^']+)' (.+) LIBEXECDIR=([^\s]+) (.+) -a (.+)$/,
        "INSTALL_IT = $(mkinstalldirs) '#{libexec}/apache2' \\2 LIBEXECDIR='#{libexec}/apache2' \\4 \\5"

      %w[EXTRA_LDFLAGS EXTRA_LDFLAGS_PROGRAM].each do |mk_var|
        system_libs = []
        other_flags = []
        s.get_make_var(mk_var).split.each do |f|
          if f[%r{^-L\/(?:Applications|usr\/lib)\/}]
            system_libs << f
            next
          end
          other_flags << f
        end
        s.change_make_var! mk_var, other_flags.concat(system_libs).join(" ")
      end
    end

    ENV.prepend "LDFLAGS", "-L#{Formula["tidy-html5"].opt_lib}"

    system "make"
    ENV.deparallelize
    system "make", "install"

    bin.install_symlink "phar.phar" => "phar"

    config_path.install "./php.ini-development" => "php.ini"
    (config_path/"php-fpm.d").install "sapi/fpm/www.conf"
    config_path.install "sapi/fpm/php-fpm.conf"
    inreplace config_path/"php-fpm.conf", /^;?daemonize\s*=.+$/, "daemonize = no"
  end

  def caveats
    s = []

    s << <<-EOS.undent
      To enable PHP in Apache add the following to httpd.conf and restart Apache:
          LoadModule php7_module #{opt_libexec}/apache2/libphp7.so

          <FilesMatch \.php$>
              SetHandler application/x-httpd-php
          </FilesMatch>

      Finally, check DirectoryIndex includes index.php
          DirectoryIndex index.php index.html
    EOS

    s << <<-EOS.undent
      The php.ini and php-fpm.ini file can be found in:
          #{etc}/php/#{php_version}/
    EOS

    s.join "\n"
  end

  def post_install
    (var/"log").mkpath
    touch var/"log/php-fpm.log"

    chmod 0755, lib/"php/.channels"
    chmod 0755, lib/"php/.channels/.alias"
    chmod 0644, (Dir.glob(lib/"php/.channels/**/*", File::FNM_DOTMATCH).reject { |a| a =~ %r{\/\.{1,2}$} || File.directory?(a) })

    %w[
      php/.depdblock
      php/.filemap
      php/.depdb
      php/.lock
    ].each do |f|
      chmod 0644, lib/f
    end

    system bin/"pear", "config-set", "php_ini", "#{etc}/php/#{php_version}/php.ini", "system"

    %w[
      ldap
      mcrypt
      tidy
      imap
      opcache
    ].each do |e|
      config_path = (etc/"php/#{php_version}/conf.d/ext-#{e}.ini")
      extension_type = (e == "opcache") ? "zend_extension" : "extension"
      if config_path.exist?
        inreplace config_path, /#{extension_type}=.*$/, "#{extension_type}=#{e}.so"
      else
        config_path.write <<-EOS.undent
          [#{e}]
          #{extension_type}="#{e}.so"
        EOS
      end
    end
  end

  def php_version
    version.to_s.split(".")[0..1].join(".")
  end

  plist_options :startup => true, :manual => "php-fpm"

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
    system "#{sbin}/php-fpm", "-t"
    system "#{bin}/phpdbg", "-V"
    system "#{bin}/php-cgi", "-m"
    system "#{Formula['httpd24'].bin}/httpd", "-M", "-C", "LoadModule php7_module #{opt_libexec}/httpd/libphp7.so"
  end
end
