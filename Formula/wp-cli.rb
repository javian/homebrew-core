class WpCli < Formula
  desc "Dependency Manager for PHP"
  homepage "https://getcomposer.org"
  url "https://github.com/wp-cli/wp-cli/releases/download/v1.5.0/wp-cli-1.5.0.phar"
  sha256 "f615d57957e66a09f57acc844a1fc5402e9fa581dcb387bbe1affc4d155baf9d"
  revision 1

  bottle :unneeded

  def install
    libexec.install "wp-cli-1.5.0.phar"

    # This script is required to set 2 necessary runtime PHP options
    # automatically every time composer is run. Tools like Ansible, expect the
    # composer executable to be a PHP script.
    # https://github.com/Homebrew/homebrew-php/issues/3590
    (bin/"wp").write <<~EOS
      #!/usr/bin/env php
      <?php
      $arguments = implode(" ", $argv);
      if (preg_match('(cli update)', $arguments) == true ) {
        print <<<'EOT'
          Homebrew wp-cli does not support selfupdate.
          Please submit a pull request to homebrew-core and have the formula updated
 
      EOT;
        exit;
      };
      Phar::loadPhar('#{libexec}/wp-cli-1.5.0.phar');
      require 'phar://wp-cli-1.5.0.phar/bin/wp';
    EOS
  end

  test do
    system "#{bin}/wp", "--info"
  end
end
