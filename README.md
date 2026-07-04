# The Ultimate Guide to Running MATLAB on Arch Linux (Wayland/CachyOS)

Running modern versions of MATLAB (R2024a, R2026a, etc.) on Arch Linux or its derivatives (like CachyOS) can be an incredibly frustrating experience. Because Arch relies on bleeding-edge system libraries and MATLAB ships with deeply embedded legacy libraries, they tend to crash into each other silently.

> **💡 Automated Fix Script Available!**
> Don't want to run all these commands manually? Just download and run the `fix_matlab_arch.sh` script included in this repository. 
> 
> **To run the automated script:**
> ```bash
> # 1. Clone this repository
> git clone https://github.com/goatnath/MATLAB-Installation-guide.git
> cd MATLAB-Installation-guide
> 
> # 2. Make the script executable
> chmod +x fix_matlab_arch.sh
> 
> # 3. Run it! (It will prompt for your sudo password to move the graphics libraries)
> ./fix_matlab_arch.sh
> ```

This guide walks you through fixing the three most notorious MATLAB bosses on Arch Linux:
1. **The MathWorksServiceHost Crash (`lc_init` symbol collision)**
2. **The Silent Wayland GUI Crash (Bundled library conflicts)**
3. **The Invisible Activation Window (Wayland fallback)**

---

## 1. The `lc_init` Cryptography Collision (ServiceHost Crash)

**The Symptoms:**
- You launch MATLAB, it reaches the splash screen, and silently dies. 
- If you check the logs in `~/.MathWorks/ServiceHost/goattop/logs/`, you see a fatal error complaining about `lc_init` or `MathWorksServiceHost` suddenly stopping.
- You get a "MathWorks communication error" when trying to run a script.

**The Cause:**
Modern Arch/CachyOS relies on a system package called `nettle` (or `libleancrypto`) for network cryptography (used by `gnutls`). Both the system's `libleancrypto` and MATLAB's internal licensing library (`libmwlmgrimpl.so`) globally export a C function literally just named `lc_init`. When `MathWorksServiceHost` tries to start, it loads the system's networking libraries alongside MATLAB's licensing libraries. The names collide, causing an immediate segfault.

**The Fix:**
You must provide `MathWorksServiceHost` with versions of `gnutls`, `nettle`, and `hogweed` that **do not** depend on `libleancrypto`. The easiest way is to drop the standard Arch packages directly into the ServiceHost folder so it uses them natively.

1. Download the standard Arch packages to a temporary folder:
```bash
wget https://archive.archlinux.org/packages/g/gnutls/gnutls-3.8.8-1-x86_64.pkg.tar.zst -O /tmp/gnutls.pkg.tar.zst
wget https://archive.archlinux.org/packages/n/nettle/nettle-3.10-1-x86_64.pkg.tar.zst -O /tmp/nettle.pkg.tar.zst
```

2. Extract the libraries:
```bash
mkdir -p /tmp/gnutls-pkg /tmp/nettle-pkg
tar -xf /tmp/gnutls.pkg.tar.zst -C /tmp/gnutls-pkg
tar -xf /tmp/nettle.pkg.tar.zst -C /tmp/nettle-pkg
```

3. Copy the isolated libraries directly into the ServiceHost directory (Replace `v2026.7.0.6` with your specific version found in that directory):
```bash
# Find your version folder first:
ls ~/.MathWorks/ServiceHost/-mw_shared_installs/

# Copy the libraries in:
cp -P /tmp/gnutls-pkg/usr/lib/libgnutls* ~/.MathWorks/ServiceHost/-mw_shared_installs/<YOUR_VERSION>/bin/glnxa64/
cp -P /tmp/nettle-pkg/usr/lib/libnettle* ~/.MathWorks/ServiceHost/-mw_shared_installs/<YOUR_VERSION>/bin/glnxa64/
cp -P /tmp/nettle-pkg/usr/lib/libhogweed* ~/.MathWorks/ServiceHost/-mw_shared_installs/<YOUR_VERSION>/bin/glnxa64/
```
*Note: Make sure all hanging `MathWorksServiceHost` processes are killed after doing this using `pkill -9 -f MathWorksServiceHost`.*

---

## 2. The Silent Wayland UI Crash (Font/GLib Conflicts)

**The Symptoms:**
MATLAB initializes but crashes before the main window is rendered, usually providing absolutely no terminal output.

**The Cause:**
MATLAB bundles horribly outdated versions of `freetype`, `glib`, and `harfbuzz`. When its Chromium-based UI tries to render through Wayland on modern Arch Linux, these ancient libraries clash with your system's modern font rendering stack.

**The Fix:**
Force MATLAB to use your system's rendering libraries by hiding the bundled ones inside an `exclude` folder.

```bash
# Assuming MATLAB is installed at /opt/MATLAB/R2026a (change as needed)
cd /opt/MATLAB/R2026a/bin/glnxa64/
sudo mkdir -p exclude

# Move the culprits out of the way so MATLAB falls back to your system libraries
sudo mv libfreetype.so* exclude/ 2>/dev/null
sudo mv libglib-2.0.so* exclude/ 2>/dev/null
sudo mv libgio-2.0.so* exclude/ 2>/dev/null
sudo mv libharfbuzz.so* exclude/ 2>/dev/null
sudo mv libfontconfig.so* exclude/ 2>/dev/null
```

---

## 3. The Invisible Activation Window (Wayland Fallback)

**The Symptoms:**
You run MATLAB for the very first time. It prints nothing, nothing opens, and it eventually closes. 

**The Cause:**
If your license needs activation, MATLAB spawns a background executable (`MathWorksProductAuthorizer`). Because Wayland support for Java/Qt apps is notoriously flaky, this window can spawn completely invisibly. Because you can't click "Activate", the main MATLAB app gives up and exits.

**The Fix:**
You must forcefully launch the Authorizer executable with XWayland compatibility enabled.

```bash
env QT_QPA_PLATFORM=xcb /opt/MATLAB/R2026a/bin/glnxa64/MathWorksProductAuthorizer
```
Complete the activation in the window that pops up, and close it.

---

## 4. The Final Boss: Launching MATLAB

Because MATLAB still heavily relies on older Qt versions, it is highly recommended to *always* launch it using XWayland compatibility to prevent GUI freezes.

Launch it via the terminal:
```bash
env QT_QPA_PLATFORM=xcb /usr/bin/matlab
```

### Making it Permanent
Nobody wants to type that every time. Create a persistent wrapper depending on your shell:

**For `fish` users:**
```fish
function matlab
    env QT_QPA_PLATFORM=xcb /usr/bin/matlab $argv
end
funcsave matlab
```

**For `bash` / `zsh` users:**
Add this to your `~/.bashrc` or `~/.zshrc`:
```bash
alias matlab="env QT_QPA_PLATFORM=xcb /usr/bin/matlab"
```

### Bonus Note: The `free(): chunks in smallbin corrupted` Warning
When quitting MATLAB, you may see a memory corruption error printed to the terminal. You can safely ignore this! It's simply MATLAB's bundled libraries failing to cleanly hand memory back to your modern `glibc` during the teardown sequence. It only happens *after* your files are saved and MATLAB has already exited.
