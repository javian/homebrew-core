class Php < Formula
  desc "General-purpose scripting language"
  homepage "https://php.net/"

  stable do
    version "7.1.10"
    url "http://fi2.php.net/get/php-7.1.10.tar.gz/from/a/mirror"
    sha256 "edc6a7c3fe89419525ce51969c5f48610e53613235bbef255c3a4db33b458083"

    depends_on "libtool" => :run
    depends_on "mcrypt"
  end

  devel do
    url "https://downloads.php.net/~remi/php-7.2.0RC3.tar.gz"
    sha256 "076491818dd80d723c9232bd4553a95eb30374f3c602d5ca67b95f2ac5e1655a"

    depends_on "argon2"
    depends_on "libsodium"
  end

  option "with-thread-safety", "Build with thread safety"

  depends_on "aspell"
  depends_on "curl" if MacOS.version < :lion
  depends_on "enchant"
  depends_on "freetds"
  depends_on "freetype"
  depends_on "gettext"
  depends_on "gmp"
  depends_on "httpd"
  depends_on "icu4c"
  depends_on "imap-uw"
  depends_on "jpeg"
  depends_on "libpng"
  depends_on "libpq"
  depends_on "libzip"
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
      --with-apxs2=#{Formula["httpd"].opt_bin}/apxs
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
      --with-libzip=#{Formula["libzip"].opt_prefix}
      --with-mhash
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
    else
      args << "--with-mcrypt=shared,#{Formula["mcrypt"].opt_prefix}"
    end

    # Fix configure error can't libzip include (possible libzip bug)
    ENV.append_to_cflags "-I#{Formula["libzip"].opt_prefix}/lib/libzip/include"

    system "./configure", *args

    inreplace "Makefile" do |s|
      # Custom location for php module and remove -a (don't touch httpd.conf)
      s.gsub! /^INSTALL_IT = \$\(mkinstalldirs\) '([^']+)' (.+) LIBEXECDIR=([^\s]+) (.+) -a (.+)$/,
        "INSTALL_IT = $(mkinstalldirs) '#{lib}/httpd/modules' \\2 LIBEXECDIR='#{lib}/httpd/modules' \\4 \\5"

      # Reorder linker flags to put system paths at the end to avoid accidential system linkage
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

    # Shared module linker flags come after the sytem flags, prepend to avoid accidential system linkage
    ENV.prepend "LDFLAGS", "-L#{Formula["tidy-html5"].opt_lib}"

    system "make"
    ENV.deparallelize
    system "make", "install"

    bin.install_symlink "phar.phar" => "phar"

    config_path.install "php.ini-development" => "php.ini"
    (config_path/"php-fpm.d").install "sapi/fpm/www.conf"
    config_path.install "sapi/fpm/php-fpm.conf"
    inreplace config_path/"php-fpm.conf", /^;?daemonize\s*=.+$/, "daemonize = no"

    # patch PEAR so it installs extensions outside of the Cellar
    Dir.chdir prefix do
      pear_patch = Patch.create :p1, <<-EOS.undent
        --- a/lib/php/PEAR/Builder.php	2017-09-07 23:46:07.000000000 -0500
        +++ b/lib/php/PEAR/Builder.php	2017-09-07 23:47:17.000000000 -0500
        @@ -405,7 +405,7 @@
                 $prefix = exec($this->config->get('php_prefix')
                                 . "php-config" .
                                $this->config->get('php_suffix') . " --prefix");
        -        $this->_harvestInstDir($prefix, $inst_dir . DIRECTORY_SEPARATOR . $prefix, $built_files);
        +        $this->_harvestInstDir($this->config->get('ext_dir'), $inst_dir . DIRECTORY_SEPARATOR . $prefix, $built_files);
                 chdir($old_cwd);
                 return $built_files;
             }
        --- a/lib/php/PEAR/Command/Install.php	2017-09-07 23:45:56.000000000 -0500
        +++ b/lib/php/PEAR/Command/Install.php	2017-09-07 23:42:22.000000000 -0500
        @@ -379,7 +379,7 @@
                     $newini = array();
                 }
                 foreach ($binaries as $binary) {
        -            if ($ini['extension_dir']) {
        +            if ($ini['extension_dir'] && $ini['extension_dir'] === $this->config->get('ext_dir')) {
                         $binary = basename($binary);
                     }
                     $newini[] = $enable . '="' . $binary . '"' . (OS_UNIX ? "\\n" : "\\r\\n");
      EOS
      pear_patch.apply
    end
  end

  def caveats
    s = []

    s << <<-EOS.undent
      To enable PHP in Apache add the following to httpd.conf and restart Apache:
          LoadModule php7_module #{HOMEBREW_PREFIX}/lib/httpd/modules/libphp7.so

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

    # custom location for extensions installed via pecl
    pecl_path = HOMEBREW_PREFIX/"lib/php/#{php_version}/pecl"
    pecl_path.mkpath

    # fix pear config to use opt paths
    php_lib_path = opt_lib/"php"
    {
      "php_ini" => etc/"php/#{php_version}/php.ini",
      "php_dir" => php_lib_path,
      "ext_dir" => pecl_path,
      "doc_dir" => php_lib_path/"doc",
      "bin_dir" => opt_bin,
      "data_dir" => php_lib_path/"data",
      "cfg_dir" => php_lib_path/"cfg",
      "www_dir" => php_lib_path/"htdocs",
      "man_dir" => php_lib_path/"local/man",
      "test_dir" => php_lib_path/"test",
      "php_bin" => opt_bin/"php",
    }.each do |key, value|
      system bin/"pear", "config-set", key, value, "system"
    end

    %w[
      ldap
      mcrypt
      tidy
      imap
      opcache
    ].each do |e|
      next if build.devel? && (e == "mcrypt")
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
        <string>#{var}/log/php-fpm.log</string>
      </dict>
    </plist>
    EOPLIST
  end

  test do
    system "#{bin}/php", "-i"
    system "#{sbin}/php-fpm", "-t"
    system "#{bin}/phpdbg", "-V"
    system "#{bin}/php-cgi", "-m"
    assert_match "php7_module", shell_output("#{Formula["httpd"].bin}/httpd -M -C 'LoadModule php7_module #{HOMEBREW_PREFIX}/lib/httpd/modules/libphp7.so'")
  end
end
