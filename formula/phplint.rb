class Phplint < Formula
  desc "Validator and documentator for PHP 5 and 7 programs"
  homepage "http://www.icosaedro.it/phplint/"
  url "http://www.icosaedro.it/phplint/phplint-3.0_20160307.tar.gz"
  version "3.0-20160307"
  sha256 "7a361166d1a6de707e6728828a6002a6de69be886501853344601ab1da922e7b"

  bottle :unneeded

  depends_on "php@7.1"

  def install
    inreplace "php", "/opt/php/bin/php", "#{Formula["php@7.1"].opt_bin}/php"
    inreplace "phpl", "$__DIR__/", "$__DIR__/../"
    inreplace "phplint.tcl", "\"MISSING_PHP_CLI_EXECUTABLE\"", "#{opt_bin}/php"
    inreplace "phplint.tcl", "set opts(phplint_dir) [pwd]", "set opts(phplint_dir) #{opt_prefix}"

    prefix.install "modules", "stdlib", "utils", "php"

    bin.install "phpl", "phplint.tcl"
  end

  test do
    (testpath/"Email.php").write <<~EOS
      <?php
        declare(strict_types=1);

        final class Email
        {
            private $email;

            private function __construct(string $email)
            {
                $this->ensureIsValidEmail($email);

                $this->email = $email;
            }

            public static function fromString(string $email): self
            {
                return new self($email);
            }

            public function __toString(): string
            {
                return $this->email;
            }

            private function ensureIsValidEmail(string $email): void
            {
                if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
                    throw new InvalidArgumentException(
                        sprintf(
                            '"%s" is not a valid email address',
                            $email
                        )
                    );
                }
            }
        }
    EOS
    assert_match /Overall test results: 20 errors, 0 warnings./, shell_output("#{bin}/phpl Email.php", 1)
  end
end
