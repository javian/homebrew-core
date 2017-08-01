class Php < Formula
  desc "General-purpose scripting language"
  homepage "https://php.net"
  url "https://github.com/php/php-src/archive/php-7.1.7.tar.gz"
  sha256 "fc57fde1df31e34fc6d58ea4ec477429d3663187391e2b307444b532dc18550d"

  # javian: not sure about the origin of this so I'll keep it commented for now. Could it have something to do with building extensions ?
  # So PHP extensions don't report missing symbols
  # skip_clean "bin", "sbin"

  # TODO
  # Opcache default config file is included in extension formula, is it needed ?
  # ldap extension: I have a vague recollection that this caused some issues that were resolved with exluding it. needs to be checked.
  # According to php docs enchant requires aspell as a dep, should not be an issue since aspell is required.
  # Need to add tests for all supported SAPIs
  # Should we remove --with-pdo-dblib from formula ? (mssql support is long gone and as far as I can tell this is the
  #  only purpose and would also exclude a dep, freetds)
  # How should the Formula handle the apache module ? Sierra (have not checked high sierra) can't support building it for the OS
  #   (without manually fiddling with link in the file system) with the bundles tools

  option "with-imap-uw", "Build PHP IMAP extension"
  option "with-thread-safety", "Build with thread safety"

  # javian: Not yet checked these options
  option "with-pdo-oci", "Include Oracle databases (requries ORACLE_HOME to be set)"
  option "without-ldap", "Build without LDAP support"
  option "without-unixodbc", "Build without unixODBC support"

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
  depends_on "mcrypt"
  depends_on "net-snmp"
  depends_on "openssl"
  depends_on "pcre"
  depends_on "tidy-html5"
  depends_on "unixodbc"
  depends_on "webp"

  resource "libpq" do
    url "https://ftp.postgresql.org/pub/source/v9.6.3/postgresql-9.6.3.tar.bz2"
    sha256 "1645b3736901f6d854e695a937389e68ff2066ce0cde9d73919d6ab7c995b9c6"
  end

  # Fixes the pear .lock permissions issue that keeps it from operating correctly.
  # Thanks mistym & #machomebrew
  # javian: is this still needed ?
  skip_clean "lib/php/.lock"

  def config_path
    etc+"php"+php_version
  end

  def php_version
    version.to_s[0..2]
  end

  def php_version_path
    version.to_s[0..2].delete(".")
  end

  def home_path
    File.expand_path("~")
  end

  def install
    # Not removing all pear.conf and .pearrc files from PHP path results in
    # the PHP configure not properly setting the pear binary to be installed
    config_pear = "#{config_path}/pear.conf"
    user_pear = "#{home_path}/pear.conf"
    config_pearrc = "#{config_path}/.pearrc"
    user_pearrc = "#{home_path}/.pearrc"
    if File.exist?(config_pear) || File.exist?(user_pear) || File.exist?(config_pearrc) || File.exist?(user_pearrc)
      opoo "Backing up all known pear.conf and .pearrc files"
      opoo <<-INFO
        If you have a pre-existing pear install outside
        of homebrew-php, or you are using a non-standard
        pear.conf location, installation may fail.
INFO
      mv(config_pear, "#{config_pear}-backup") if File.exist? config_pear
      mv(user_pear, "#{user_pear}-backup") if File.exist? user_pear
      mv(config_pearrc, "#{config_pearrc}-backup") if File.exist? config_pearrc
      mv(user_pearrc, "#{user_pearrc}-backup") if File.exist? user_pearrc
    end

    begin
      # Prevent PHP from harcoding sed shim path
      ENV["lt_cv_path_SED"] = "sed"

      resource("libpq").stage do
        system "./configure", "--disable-debug",
                              "--prefix=#{libexec}/libpq",
                              "--with-openssl"
        system "make"
        system "make", "-C", "src/bin", "install"
        system "make", "-C", "src/include", "install"
        system "make", "-C", "src/interfaces", "install"
      end

      args = %W[
        --prefix=#{prefix}
        --localstatedir=#{var}
        --sysconfdir=#{config_path}
        --with-config-file-path=#{config_path}
        --with-config-file-scan-dir=#{config_path}/conf.d
        --mandir=#{man}
        --enable-bcmath
        --enable-cgi
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
        --with-ldap
        --with-ldap-sasl=/usr
        --with-libxml-dir=/usr
        --with-mhash
        --with-mcrypt=#{Formula["mcrypt"].opt_prefix}
        --with-mysql-sock=/tmp/mysql.sock
        --with-mysqli=mysqlnd
        --with-pdo-mysql=mysqlnd
        --with-pdo-odbc=unixODBC,#{Formula["unixodbc"].opt_prefix}
        --with-ndbm=/usr
        --with-openssl=#{Formula["openssl"].opt_prefix}
        --with-password-argon2=#{Formula["argon2"].opt_prefix}
        --with-pdo-dblib=#{Formula["freetds"].opt_prefix}
        --with-pdo-pgsql=#{libexec}/libpq
        --with-pgsql=#{libexec}/libpq
        --with-png-dir=#{Formula["libpng"].opt_prefix}
        --with-pspell=#{Formula["aspell"].opt_prefix}
        --with-snmp
        --with-tidy=shared,#{Formula["tidy-html5"].opt_prefix}
        --with-unixODBC=#{Formula["unixodbc"].opt_prefix}
        --with-webp-dir=#{Formula["webp"].opt_prefix}
        --with-xmlrpc
        --with-zlib=/usr
        --with-libedit
        --with-xsl=/usr
        --without-gmp
      ]

      # Belongs to fpm config
      (prefix+"var/log").mkpath
      touch prefix+"var/log/php-fpm.log"
      plist_path.write plist
      plist_path.chmod 0644

      if MacOS.version < :lion
        args << "--with-curl=#{Formula["curl"].opt_prefix}"
      else
        args << "--with-curl"
      end

      if build.with? "imap-uw"
        args << "--with-imap=#{Formula["imap-uw"].opt_prefix}"
        args << "--with-imap-ssl=#{Formula["openssl"].opt_prefix}"
      end

      if build.with? "pdo-oci"
        if ENV.key?("ORACLE_HOME")
          args << "--with-pdo-oci=#{ENV["ORACLE_HOME"]}"
        else
          raise "Environmental variable ORACLE_HOME must be set to use --with-pdo-oci option."
        end
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
      ln_s "phar.phar", bin+"phar", :force => true if File.exist? bin+"phar.phar"

      # Install new php.ini unless one exists
      config_path.install "./php.ini-development" => "php.ini" unless File.exist? config_path+"php.ini"

      chmod_R 0775, lib+"php"

      system bin+"pear", "config-set", "php_ini", config_path+"php.ini", "system"

      if File.exist?("sapi/fpm/init.d.php-fpm")
        chmod 0755, "sapi/fpm/init.d.php-fpm"
        sbin.install "sapi/fpm/init.d.php-fpm" => "php#{php_version_path}-fpm"
      end

      if File.exist?("sapi/cgi/fpm/php-fpm")
        chmod 0755, "sapi/cgi/fpm/php-fpm"
        sbin.install "sapi/cgi/fpm/php-fpm" => "php#{php_version_path}-fpm"
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

      rm_f("#{config_pear}-backup") if File.exist? "#{config_pear}-backup"
      rm_f("#{user_pear}-backup") if File.exist? "#{user_pear}-backup"
      rm_f("#{config_pearrc}-backup") if File.exist? "#{config_pearrc}-backup"
      rm_f("#{user_pearrc}-backup") if File.exist? "#{user_pearrc}-backup"
    rescue StandardError
      mv("#{config_pear}-backup", config_pear) if File.exist? "#{config_pear}-backup"
      mv("#{user_pear}-backup", user_pear) if File.exist? "#{user_pear}-backup"
      mv("#{config_pearrc}-backup", config_pearrc) if File.exist? "#{config_pearrc}-backup"
      mv("#{user_pearrc}-backup", user_pearrc) if File.exist? "#{user_pearrc}-backup"
      raise
    end
  end

  def caveats
    s = []

    s << <<-EOS.undent
      To enable PHP in Apache add the following to httpd.conf and restart Apache:
          LoadModule php7_module #{HOMEBREW_PREFIX}/opt/php#{php_version_path}/libexec/apache2/libphp7.so

          <FilesMatch \.php$>
              SetHandler application/x-httpd-php
          </FilesMatch>

      Finally, check DirectoryIndex includes index.php
          DirectoryIndex index.php index.html
    EOS

    s << <<-EOS.undent
      The php.ini file can be found in:
          #{config_path}/php.ini
    EOS

    if build.with? "pear"
      s << <<-EOS.undent
        ✩✩✩✩ PEAR ✩✩✩✩

        If PEAR complains about permissions, 'fix' the default PEAR permissions and config:

            chmod -R ug+w #{lib}/php
            pear config-set php_ini #{etc}/php/#{php_version}/php.ini system
      EOS
    end

    s << <<-EOS.undent
      ✩✩✩✩ Extensions ✩✩✩✩

      If you are having issues with custom extension compiling, ensure that you are using the brew version, by placing #{HOMEBREW_PREFIX}/bin before /usr/sbin in your PATH:

            PATH="#{HOMEBREW_PREFIX}/bin:$PATH"

      PHP#{php_version_path} Extensions will always be compiled against this PHP. Please install them using --without-homebrew-php to enable compiling against system PHP.
    EOS

    s.join "\n"
  end

  plist_options :manual => "php-fpm --nodaemonize --fpm-config #{HOMEBREW_PREFIX}/etc/php/#{version.to_s[0..2]}/php-fpm.conf"

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
          <string>#{config_path}/php-fpm.conf</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>LaunchOnlyOnce</key>
        <true/>
        <key>UserName</key>
        <string>#{`whoami`.chomp}</string>
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
    system "#{sbin}/php-fpm", "-y", "#{config_path}/php-fpm.conf", "-t"
  end
end
