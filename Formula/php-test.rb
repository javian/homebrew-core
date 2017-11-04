class PhpTiny < Formula
  desc "General-purpose scripting language"
  homepage "https://php.net/"

  stable do
    url "https://php.net/get/php-7.1.11.tar.gz/from/this/mirror"
    sha256 "de41b2c166bc5ec8ea96a337d4dd675c794f7b115a8a47bb04595c03dbbdf425"

    depends_on "libtool" => :run
    depends_on "mcrypt"
  end

  devel do
    url "https://downloads.php.net/~pollita/php-7.2.0RC5.tar.gz"
    sha256 "eef6cda27b9f9a16ed0f622a3ac43011fd341053b33f16c6620941ab833d4890"

    depends_on "argon2"
    depends_on "libsodium"
  end

  depends_on "openssl"
  depends_on "mcrypt"
  depends_on "tidy-html5"

  needs :cxx11

  def install
    inreplace "configure",
              "APACHE_THREADED_MPM=`$APXS_HTTPD -V | grep 'threaded:.*yes'`",
              "APACHE_THREADED_MPM="

    inreplace "sapi/apache2handler/sapi_apache2.c",
              "You need to recompile PHP.",
              "Homebrew PHP does not support a thread-safe php binary. "\
              "To use the PHP apache sapi please change "\
              "your httpd config to use the prefork MPM"

    ENV.cxx11

    # Fix missing header file during configure for libzip include
    ENV.append_to_cflags "-I#{Formula["libzip"].opt_prefix}/lib/libzip/include"

    config_path = etc/"php/#{php_version}"
    ENV["lt_cv_path_SED"] = "sed"

    args = %W[
      --prefix=#{prefix}
      --localstatedir=#{var}
      --sysconfdir=#{config_path}
      --with-config-file-path=#{config_path}
      --with-config-file-scan-dir=#{config_path}/conf.d
      --mandir=#{man}
      --libexecdir=#{libexec}
      --with-tidy=shared,#{Formula["tidy-html5"].opt_prefix}
    ]

    if MacOS.version < :lion
      args << "--with-curl=#{Formula["curl"].opt_prefix}"
    else
      args << "--with-curl"
    end

    if build.devel?
      args += %W[
        --with-password-argon2=#{Formula["argon2"].opt_prefix}
        --with-sodium=#{Formula["libsodium"].opt_prefix}
      ]
    else
      args << "--with-mcrypt=shared,#{Formula["mcrypt"].opt_prefix}"
    end

    system "./configure", *args

    # inreplace "Makefile" do |s|
    #   # Custom location for php module and remove -a (don't touch httpd.conf)
    #   s.gsub! /^INSTALL_IT = \$\(mkinstalldirs\) '([^']+)' (.+) LIBEXECDIR=([^\s]+) (.+) -a (.+)$/,
    #     "INSTALL_IT = $(mkinstalldirs) '#{lib}/httpd/modules' \\2 LIBEXECDIR='#{lib}/httpd/modules' \\4 \\5"

    #   # Reorder linker flags to put system paths at the end to avoid accidential system linkage
    #   %w[EXTRA_LDFLAGS EXTRA_LDFLAGS_PROGRAM].each do |mk_var|
    #     system_libs = []
    #     other_flags = []
    #     s.get_make_var(mk_var).split.each do |f|
    #       if f[%r{^-L\/(?:Applications|usr\/lib)\/}]
    #         system_libs << f
    #         next
    #       end
    #       other_flags << f
    #     end
    #     s.change_make_var! mk_var, other_flags.concat(system_libs).join(" ")
    #   end
    # end

    # Shared module linker flags come after the sytem flags, prepend to avoid accidential system linkage
    #ENV.prepend "LDFLAGS", "-L#{Formula["tidy-html5"].opt_lib}"

    system "make"
    ENV.deparallelize
    system "make", "install"

    config_path.install "php.ini-development" => "php.ini"
    # (config_path/"php-fpm.d").install "sapi/fpm/www.conf"
    # config_path.install "sapi/fpm/php-fpm.conf"
    # inreplace config_path/"php-fpm.conf", /^;?daemonize\s*=.+$/, "daemonize = no"

    # # patch PEAR so it installs extensions outside of the Cellar
    # Dir.chdir prefix do
    #   pear_patch = Patch.create :p1, <<-EOS.undent
    #     --- a/lib/php/PEAR/Builder.php	2017-09-07 23:46:07.000000000 -0500
    #     +++ b/lib/php/PEAR/Builder.php	2017-09-07 23:47:17.000000000 -0500
    #     @@ -405,7 +405,7 @@
    #              $prefix = exec($this->config->get('php_prefix')
    #                              . "php-config" .
    #                             $this->config->get('php_suffix') . " --prefix");
    #     -        $this->_harvestInstDir($prefix, $inst_dir . DIRECTORY_SEPARATOR . $prefix, $built_files);
    #     +        $this->_harvestInstDir($this->config->get('ext_dir'), $inst_dir . DIRECTORY_SEPARATOR . $prefix, $built_files);
    #              chdir($old_cwd);
    #              return $built_files;
    #          }
    #     --- a/lib/php/PEAR/Command/Install.php	2017-09-07 23:45:56.000000000 -0500
    #     +++ b/lib/php/PEAR/Command/Install.php	2017-09-07 23:42:22.000000000 -0500
    #     @@ -379,7 +379,7 @@
    #                  $newini = array();
    #              }
    #              foreach ($binaries as $binary) {
    #     -            if ($ini['extension_dir']) {
    #     +            if ($ini['extension_dir'] && $ini['extension_dir'] === $this->config->get('ext_dir')) {
    #                      $binary = basename($binary);
    #                  }
    #                  $newini[] = $enable . '="' . $binary . '"' . (OS_UNIX ? "\\n" : "\\r\\n");
    #   EOS
    #   pear_patch.apply
    # end

    # unless File.exist? "#{var}/log/php-fpm.log"
    #   (var/"log").mkpath
    #   touch var/"log/php-fpm.log"
    # end
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
    # chmod 0755, lib/"php/.channels"
    # chmod 0755, lib/"php/.channels/.alias"
    # chmod 0644, (Dir.glob(lib/"php/.channels/**/*", File::FNM_DOTMATCH).reject { |a| a =~ %r{\/\.{1,2}$} || File.directory?(a) })
    # chmod 0644, %W[
    #   #{lib}/php/.depdblock
    #   #{lib}/php/.filemap
    #   #{lib}/php/.depdb
    #   #{lib}/php/.lock
    # ]

    # # custom location for extensions installed via pecl
    # (HOMEBREW_PREFIX/"lib/php/#{php_version}/pecl").mkpath

    # # fix pear config to use opt paths
    # php_lib_path = opt_lib/"php"
    # {
    #   "php_ini" => etc/"php/#{php_version}/php.ini",
    #   "php_dir" => php_lib_path,
    #   "ext_dir" => HOMEBREW_PREFIX/"lib/php/#{php_version}/pecl",
    #   "doc_dir" => php_lib_path/"doc",
    #   "bin_dir" => opt_bin,
    #   "data_dir" => php_lib_path/"data",
    #   "cfg_dir" => php_lib_path/"cfg",
    #   "www_dir" => php_lib_path/"htdocs",
    #   "man_dir" => php_lib_path/"local/man",
    #   "test_dir" => php_lib_path/"test",
    #   "php_bin" => opt_bin/"php",
    # }.each do |key, value|
    #   system bin/"pear", "config-set", key, value, "system"
    # end

    %w[
      tidy
      mcrypt
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
    assert_match "php7_module", shell_output(
      %W[
        #{Formula["httpd"].bin}/httpd -M -C
        'LoadModule php7_module #{HOMEBREW_PREFIX}/lib/httpd/modules/libphp7.so'
      ].join(" "),
    )
  end
end
