class WpCli < Formula
  desc "Command line interface for WordPress"
  homepage "https://wp-cli.org"
  url "https://github.com/wp-cli/wp-cli/releases/download/v1.5.0/wp-cli-1.5.0.phar"
  sha256 "f615d57957e66a09f57acc844a1fc5402e9fa581dcb387bbe1affc4d155baf9d"
  revision 1

  bottle :unneeded

  def install
    libexec.install "wp-cli-#{version}.phar"

    # We want to prevent the self update functionality in the script and
    # Tools like Ansible, expect the wrapper to be a PHP script.
    # https://github.com/Homebrew/homebrew-php/issues/3590
    (bin/"wp").write <<~EOS
      #!/usr/bin/env php
      <?php
      $arguments = implode(" ", $argv);
      if (preg_match('(cli update)', $arguments) == true ) {
        echo "Homebrew wp-cli does not support selfupdate.\n";
        echo "Please submit a pull request to homebrew-core and have the formula updated\n";
        exit;
      };
      Phar::loadPhar('#{libexec}/wp-cli-#{version}.phar');
      require 'phar://wp-cli.phar/php/boot-phar.php';
    EOS
  end

  test do
    system "#{bin}/wp", "--info"
  end
end
