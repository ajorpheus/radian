#!/bin/bash

# Description:
# Ensure that an executable is installed, optionally requiring a minimum
# version. If the executable is not installed, use a package manager to
# install it. Try to avoid re-installing the executable if the only
# problem is broken symlinks. Allowable package managers are brew, gem,
# assert (which will cause the script to exit non-zero if the executable
# is not installed), or any other command (which will be called with no
# arguments).

# Arguments:
# $1 = name of executable that should be installed
# $2 = subcommand to get version (defaults to --version)
# $3 = command name in version command output (defaults to executable name)
# $4 = minimum version (defaults to any-version)
# $5 = package manager (brew, gem, assert, or other script; defaults to brew)
# $6 = name of package for package manager (defaults to executable name)
# $7 = optional flag
#
# If the optional flag is --require, then the executable is required
# to be installed via the provided package manager. Pre-existing
# installations via other methods are not allowable. Currently this
# only works if the package manager is brew.

# Preconditions:
# - The package manager must be available on the $PATH.

# Postconditions:
# - An appropriate version of the executable will be available on the $PATH.

# Exit code:
# - zero if no errors occurred;
# - non-zero if an error occurred.

### Setup ###

set -e
set -o pipefail

### Parse arguments ###

executable="$1"
if [[ -z $executable ]]; then
    echo "[ensure-installed] Fatal error: executable name not provided."
    exit 1
fi
version_subcommand="${2:---version}"
version_command_name="${3:-$executable}"
min_version="${4:-any-version}"
if [[ $min_version != any-version ]] && ! (echo "$min_version" | egrep -q "^[0-9]+(\.[0-9]+)*$"); then
    echo "[ensure-installed] Fatal error: the minimum version string is malformed."
    exit 1
fi
package_manager="${5:-brew}"
package_name="${6:-$executable}"
if [[ $package_manager == brew ]]; then
    install_command="brew install $package_name"
elif [[ $package_manager == gem ]]; then
    install_command="sudo gem install $package_name"
elif [[ $package_manager == assert ]]; then
    install_command="exit 1"
else
    install_command="$package_manager"
fi
optional_flag="$7"

### Report task ###

if [[ $package_manager != assert ]]; then
    echo -n "[ensure-installed] Ensuring that "
else
    echo -n "[ensure-installed] Checking if "
fi
if [[ $min_version != any-version ]]; then
    echo -n "version $min_version or more recent of "
fi
echo "$executable is installed."
if [[ $min_version != any-version ]]; then
    echo "[ensure-installed] Will check the version using '$executable $version_subcommand'."
    echo "[ensure-installed] Expecting the output to look something like '$version_command_name $min_version'."
fi
if [[ $package_manager != assert ]]; then
    echo "[ensure-installed] If necessary, will install via '$install_command'."
fi

### Utility functions ###

# Returns zero if a minimum version is required, non-zero otherwise.
requires_version() {
    [[ $min_version != any-version ]]
}

# Returns zero if the installation is required to be through the
# provided package manager, non-zero otherwise.
requires_package_manager() {
    [[ $optional_flag == --require ]]
}

# Returns zero if version $2 is at least as recent as version $1, two
# if version $2 is malformed, and one otherwise. The versions should
# be dot-separated strings of integers. Version $2 is allowed some
# flexibility; strings such as "-alpha" are trimmed from the end.
# Version $1 is not normalized or checked.
version_as_recent() {

    # Parse arguments.
    old_version="$1"
    new_version="$2"

    # Normalize $new_version (this is the version that was taken from
    # the output of $executable $version_subcommand).
    new_version="${new_version%%-*}"
    new_version="${new_version%%_*}"
    new_version="${new_version%%.}"
    new_version="${new_version%%,}"

    # Check that $new_version is formatted correctly.
    if ! (echo "$new_version" | egrep -q '^[0-9]+(\.[0-9]+)*$'); then
        return 2
    fi

    # Split versions into components.
    IFS=. read -ra old_components <<< "$old_version"
    IFS=. read -ra new_components <<< "$new_version"

    # Compare the components in parallel.
    for i in "${!old_components[@]}"; do
        # The first check makes version_as_recent 2.7.3 2.7 return false.
        # The second check makes version_as_recent 2.7.3 2.6.5 return false.
        if [[ (( $i -ge ${#new_components[@]} )) || (( ${new_components[$i]} < ${old_components[$i]} )) ]]; then
            return 1
        fi
        # This check makes version_as_recent 2.7.3 2.8.1 return true.
        if (( ${new_components[$i]} > ${old_components[$i]} )); then
            return 0;
        fi
    done

    # If we get here, either the versions are identical or we are in a
    # situation like version_as_recent 2.7 2.7.3, where the "new"
    # version is longer than the "old" version but the shared components
    # are identical.
    return 0

}

### Main functions ###

# Returns zero if the executable is installed correctly, including
# being of a recent enough version (if this was specified), and
# non-zero otherwise.
is_installed_correctly() {
    echo "[ensure-installed] Checking if $executable is available on the \$PATH."
    if command -v "$executable" &>/dev/null; then
        echo "[ensure-installed] $executable appears to be available on the \$PATH."
        if requires_version; then
            echo "[ensure-installed] Checking the version of $executable using '$executable $version_subcommand'."
            version_output="$("$executable" $version_subcommand 2>&1)"
            echo "$version_output"
            version_line="$(echo "$version_output" | egrep -m 1 "^$version_command_name")" || true
            if [[ $version_line ]]; then
                version_and_rest="${version_line#$version_command_name}"
                version_and_rest="${version_and_rest# }"
                version="${version_and_rest%% *}"
                echo "[ensure-installed] The version appears to be $version."
                exit_code=0 && version_as_recent "$min_version" "$version" || exit_code=$?
                if [[ $exit_code == 0 ]]; then
                    echo "[ensure-installed] This is at least as recent as the minimum version, $min_version."
                    if requires_package_manager; then
                        echo "[ensure-installed] Checking that $executable has been installed via $package_manager."
                        if [[ $package_manager == brew ]]; then
                            brew_prefix=$(brew config | egrep "^HOMEBREW_CELLAR: ")
                            brew_prefix=${brew_prefix#HOMEBREW_CELLAR: }
                            echo "[ensure-installed] The Homebrew prefix is '$brew_prefix'."
                            executable_path=$(grealpath "$(which "$executable")")
                            echo "[ensure-installed] The $executable executable in '$(which "$executable")' points to '$executable_path'."
                            if [[ $executable_path == $brew_prefix* ]]; then
                                echo "[ensure-installed] It looks like $executable has been installed via $package_manager."
                            else
                                echo "[ensure-installed] It looks like $executable has not been installed via $package_manager."
                                return 1
                            fi
                        else
                            echo "[ensure-installed] Fatal error: I don't know how to --require for '$package_manager'!"
                            exit 1
                        fi
                    fi
                    echo "[ensure-installed] The installation appears to be OK, exiting."
                    return 0
                elif [[ $exit_code == 1 ]]; then
                    echo "[ensure-installed] This is not as recent as the minimum version, $min_version."
                    return 1
                elif [[ $exit_code == 2 ]]; then
                    echo "[ensure-installed] The version appears to be malformed."
                    echo "[ensure-installed] Assuming that the version is incorrect."
                    return 1
                else
                    echo "[ensure-installed] Fatal error: unexpected exit code."
                    exit 1
                fi
            else
                echo "[ensure-installed] The version string appears to be malformed or empty."
                echo "[ensure-installed] It should have contained a line starting with '$version_command_name'."
                echo "[ensure-installed] Assuming that the version is incorrect."
                return 1
            fi
        else
            echo "[ensure-installed] The installation appears to be OK, exiting."
            return 0
        fi
    else
        echo "[ensure-installed] $executable does not appear to be available on the \$PATH."
        return 1
    fi
}

# Uses the package manager to install the executable. Always returns
# zero, unless an unexpected error occurs.
install() {
    if [[ $package_manager == brew ]]; then
        echo "[ensure-installed] Checking if $package_name has been installed via Homebrew using 'brew list --versions $package_name'."
        # Usually, if the package is not installed, 'brew list --versions'
        # will just return without outputting anything. However, if you
        # haven't yet installed *anything* via Homebrew, it will print
        # an error message and return with a non-zero exit code. So we need
        # to check for that case separately.
        if version_line="$(brew list --versions "$package_name")" && [[ $version_line ]]; then
            echo "$version_line"
            prefix="$package_name "
            version_list="${version_line#$prefix}"
            IFS=" " read -ra versions <<< "$version_list"
            echo "[ensure-installed] The available versions appear to be: ${versions[@]}."
            for version in "${versions[@]}"; do
                if requires_version; then
                    if version_as_recent "$min_version" "$version"; then
                        echo "[ensure-installed] The version $version is at least as recent as the minimum version, $min_version."
                        echo "[ensure-installed] Recreating symlinks using 'brew switch $package_name $version'."
                        brew switch "$package_name" "$version"
                        return 0
                    fi
                else
                    echo "[ensure-installed] Recreating symlinks using 'brew switch $package_name $version'."
                    brew switch "$package_name" "$version"
                    return 0
                fi
            done
            echo "[ensure-installed] None of the installed versions are sufficiently recent."
        else
            echo "[ensure-installed] No versions appear to be installed via Homebrew."
        fi
    fi
    if [[ $package_manager != assert ]]; then
        echo "[ensure-installed] Installing the most recent version of $executable using '$install_command'."
    fi
    $install_command
}

### Main logic ###

if ! is_installed_correctly; then
    install
    echo "[ensure-installed] Making sure that the installation went OK."
    if ! is_installed_correctly; then
        echo "[ensure-installed] Fatal error: $executable should be installed by this point."
        exit 1
    fi
fi
