class ClangFormat < Formula
  desc "Formatting tools for C, C++, Obj-C, Java, JavaScript, TypeScript"
  homepage "https://clang.llvm.org/docs/ClangFormat.html"
  # The LLVM Project is under the Apache License v2.0 with LLVM Exceptions
  license "Apache-2.0"
  version_scheme 1
  head "https://github.com/llvm/llvm-project.git", branch: "main"

  stable do
    url "https://github.com/llvm/llvm-project/releases/download/llvmorg-18.1.6/llvm-18.1.6.src.tar.xz"
    sha256 "c231d0a5445db2aafab855e052c247bdd9856ff9d7d9bffdd04e9f0bf8d5366f"

    resource "clang" do
      url "https://github.com/llvm/llvm-project/releases/download/llvmorg-18.1.6/clang-18.1.6.src.tar.xz"
      sha256 "54e0817f918b90b5f94684e9729ac2f9d3820fce040d6395d71c1f19ffa3b03c"
    end

    resource "cmake" do
      url "https://github.com/llvm/llvm-project/releases/download/llvmorg-18.1.6/cmake-18.1.6.src.tar.xz"
      sha256 "a643261ed98ff76ab10f1a7039291fa841c292435ba1cfe11e235c2231b95cdb"
    end

    resource "third-party" do
      url "https://github.com/llvm/llvm-project/releases/download/llvmorg-18.1.6/third-party-18.1.6.src.tar.xz"
      sha256 "4ae7b394d341aea6fb7d3d373a4f561ba8e48c0fecded4bb4f1f5f12ba9bd2b6"
    end
  end

  livecheck do
    url :stable
    regex(/llvmorg[._-]v?(\d+(?:\.\d+)+)/i)
    strategy :github_latest
  end

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_sonoma:   "1c5ebe2b7c443690f2f8aa6141e8ac9a7713ee8acc38c7816ef8f6b1be6bc149"
    sha256 cellar: :any_skip_relocation, arm64_ventura:  "ea0691ce3e20c5e941cac6be9143ae995723e6730f9f593db3eac218b8b2eea6"
    sha256 cellar: :any_skip_relocation, arm64_monterey: "8b2ec8282ba600f8d1297cb3709f06c09a59f44f0fa537e365712c13936ea950"
    sha256 cellar: :any_skip_relocation, sonoma:         "f654efb7cb80a9a9521044ad54b4621342c7bd3ada13bc87e750ad572818d928"
    sha256 cellar: :any_skip_relocation, ventura:        "5a0d748bca02a4f62103d735fab12c0540f773fd17205bc81c1a3cdf83a30040"
    sha256 cellar: :any_skip_relocation, monterey:       "b29fb2c057705da5ff1177aa53eb3ca9a881b5a88775843e24ef5e305d541fc2"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "59d620207b789e90efe4ce3e9ba585b25b6ec1e17ef7791b22c3a554f8fca9c0"
  end

  depends_on "cmake" => :build

  uses_from_macos "libxml2"
  uses_from_macos "ncurses"
  uses_from_macos "python", since: :catalina
  uses_from_macos "zlib"

  on_linux do
    keg_only "it conflicts with llvm"
  end

  def install
    odie "clang resource needs to be updated" if build.stable? && version != resource("clang").version
    odie "cmake resource needs to be updated" if build.stable? && version != resource("cmake").version
    odie "third-party resource needs to be updated" if build.stable? && version != resource("third-party").version

    llvmpath = if build.head?
      ln_s buildpath/"clang", buildpath/"llvm/tools/clang"

      buildpath/"llvm"
    else
      (buildpath/"src").install buildpath.children
      (buildpath/"src/tools/clang").install resource("clang")
      (buildpath/"cmake").install resource("cmake")
      (buildpath/"third-party").install resource("third-party")

      buildpath/"src"
    end

    system "cmake", "-S", llvmpath, "-B", "build",
                    "-DLLVM_EXTERNAL_PROJECTS=clang",
                    "-DLLVM_INCLUDE_BENCHMARKS=OFF",
                    *std_cmake_args
    system "cmake", "--build", "build", "--target", "clang-format"

    bin.install "build/bin/clang-format"
    bin.install llvmpath/"tools/clang/tools/clang-format/git-clang-format"
    (share/"clang").install llvmpath.glob("tools/clang/tools/clang-format/clang-format*")
  end

  test do
    system "git", "init"
    system "git", "commit", "--allow-empty", "-m", "initial commit", "--quiet"

    # NB: below C code is messily formatted on purpose.
    (testpath/"test.c").write <<~EOS
      int         main(char *args) { \n   \t printf("hello"); }
    EOS
    system "git", "add", "test.c"

    assert_equal "int main(char *args) { printf(\"hello\"); }\n",
        shell_output("#{bin}/clang-format -style=Google test.c")

    ENV.prepend_path "PATH", bin
    assert_match "test.c", shell_output("git clang-format", 1)
  end
end
