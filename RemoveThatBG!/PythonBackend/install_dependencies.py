#!/usr/bin/env python3
"""
Dependency installer for RemoveThatBG
Checks and installs required Python packages using system Python and pip.
"""

import subprocess
import sys
import json
from pathlib import Path

def check_python_version():
    """Ensure Python 3.8+ is available."""
    version = sys.version_info
    if version.major < 3 or (version.major == 3 and version.minor < 8):
        return False, f"Python 3.8+ required, found {version.major}.{version.minor}"
    return True, f"{version.major}.{version.minor}.{version.micro}"

def check_pip_available():
    """Check if pip is available."""
    try:
        result = subprocess.run(
            [sys.executable, "-m", "pip", "--version"],
            capture_output=True,
            text=True,
            timeout=10
        )
        return result.returncode == 0, result.stdout.strip()
    except Exception as e:
        return False, str(e)

def get_installed_packages():
    """Get list of installed packages with versions."""
    try:
        result = subprocess.run(
            [sys.executable, "-m", "pip", "list", "--format=json"],
            capture_output=True,
            text=True,
            timeout=30
        )
        if result.returncode == 0:
            packages = json.loads(result.stdout)
            return {pkg["name"].lower(): pkg["version"] for pkg in packages}
        return {}
    except Exception:
        return {}

def parse_requirements(requirements_file):
    """Parse requirements.txt file."""
    requirements = []
    try:
        with open(requirements_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    requirements.append(line)
    except Exception as e:
        print(f"Error reading requirements.txt: {e}")
    return requirements

def check_dependencies(requirements_file):
    """Check which dependencies are missing or outdated."""
    requirements = parse_requirements(requirements_file)
    installed = get_installed_packages()
    
    missing = []
    for req in requirements:
        # Parse package name (handle ==, >=, etc.)
        package_name = req.split('==')[0].split('>=')[0].split('<=')[0].strip().lower()
        if package_name not in installed:
            missing.append(req)
    
    return missing, len(requirements) - len(missing)

def install_package(package):
    """Install a single package using pip."""
    try:
        result = subprocess.run(
            [sys.executable, "-m", "pip", "install", "--upgrade", package],
            capture_output=True,
            text=True,
            timeout=300  # 5 minutes per package
        )
        return result.returncode == 0, result.stdout + result.stderr
    except subprocess.TimeoutExpired:
        return False, "Installation timeout (5 minutes exceeded)"
    except Exception as e:
        return False, str(e)

def install_dependencies(requirements_file, progress_callback=None):
    """Install all required dependencies."""
    missing, installed_count = check_dependencies(requirements_file)
    
    if not missing:
        return True, f"All dependencies satisfied ({installed_count} packages)"
    
    total = len(missing)
    failed = []
    
    for i, package in enumerate(missing, 1):
        if progress_callback:
            progress_callback(i, total, package)
        
        success, output = install_package(package)
        if not success:
            failed.append((package, output))
    
    if failed:
        error_msg = f"Failed to install {len(failed)} package(s):\n"
        for pkg, output in failed:
            error_msg += f"\n{pkg}:\n{output}\n"
        return False, error_msg
    
    return True, f"Successfully installed {total} package(s)"

def main():
    """Main entry point for CLI usage."""
    print("RemoveThatBG Dependency Installer")
    print("=" * 50)
    
    # Check Python version
    ok, msg = check_python_version()
    print(f"Python version: {msg}")
    if not ok:
        print("ERROR: Python version too old")
        sys.exit(1)
    
    # Check pip
    ok, msg = check_pip_available()
    print(f"pip available: {ok}")
    if not ok:
        print("ERROR: pip not available")
        print("Install pip: python3 -m ensurepip --upgrade")
        sys.exit(1)
    
    # Find requirements.txt
    script_dir = Path(__file__).parent
    requirements_file = script_dir / "requirements.txt"
    
    if not requirements_file.exists():
        print(f"ERROR: {requirements_file} not found")
        sys.exit(1)
    
    print(f"Requirements file: {requirements_file}")
    print()
    
    # Check dependencies
    print("Checking dependencies...")
    missing, installed = check_dependencies(requirements_file)
    print(f"  Already installed: {installed}")
    print(f"  Missing: {len(missing)}")
    
    if not missing:
        print("\n✓ All dependencies satisfied!")
        sys.exit(0)
    
    print(f"\nInstalling {len(missing)} package(s)...")
    print()
    
    def progress(current, total, package):
        print(f"[{current}/{total}] Installing {package}...")
    
    success, msg = install_dependencies(requirements_file, progress)
    print()
    print(msg)
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
