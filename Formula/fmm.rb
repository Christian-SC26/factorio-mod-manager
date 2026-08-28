class Fmm < Formula
  desc "Fast mod and modpack manager for Factorio"
  homepage "https://github.com/USERNAME/factorio-mod-manager"
  head "https://github.com/USERNAME/factorio-mod-manager.git", branch: "main"
  license "MIT"

  depends_on "python@3.10" => :optional

  def install
    libexec.install Dir["*"]
    bin.install_symlink libexec/"fmm.py" => "fmm"
  end

  test do
    assert_match "Factorio Mod Manager", shell_output("#{bin}/fmm --help")
  end
end
