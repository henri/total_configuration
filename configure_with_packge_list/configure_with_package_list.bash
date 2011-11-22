#!/bin/bash
	
# This script is licensed under the GNU GPL v3
# http://www.gnu.org/licenses/gpl-3.0.txt
# Copyright Henri Shustak 2011

# This script sets up the desktop systems with packages / executables as required by downloading them from a server.

# Version History : 
# 1.0 : Initial release.
# 1.1 : Added basic support of arbitrary execution of downloads.
# 1.2 : Checks the version of installpkg when dealing with .dmg downlods.
# 1.3 : Basic support for configuration via environment variables.
# 1.4 : Minor bug fixes.
# 1.5 : Added support for installing files which are already accessible from the mounted file system. ( eg : file:// )
# 1.6 : Basic check for installpkg when installing packages. Various other minor improvements and bug fixes.
# 1.7 : Installs InstallPKG if the install package is available within the same directory as the script and it is required.

# script parent directory
parent_directory_path=`dirname "$0"`
cd "${parent_directory_path}"
if [ $? != 0 ] ; then 
	echo "ERROR! : Unable to switch to this scripts parent directory."
	exit -128
fi

# load configuration file if present
configuration_file_default_path="${parent_directory_path}/cwpl.configuration"
if [ -e "${configuration_file_default_path}" ] ; then 
	source ${configuration_file_default_path}
fi

# set modifiable configuration settings defaults (if not already set)
if [ "${package_download_directory}" == "" ] ; then
	package_download_directory="http://example.server.com/setup_data/individual_configuration_packags"
fi
if [ "${download_directory}" == "" ] ; then
	download_directory="/tmp/packages_to_install"
fi
if [ "${execute_unknowen_file_types}" == "" ] ; then
	execute_unknowen_file_types="NO"
fi
if [ "${print_report}" == "" ] ; then
	print_report="YES"
fi

# intenral varibles
num_succesful_packages_downloaded_and_installed=0
num_unsuccesful_packages_downloaded_and_installed=0
num_argumnets=$#
current_package_to_install=""
current_pacakge_to_install_name=""
current_package_download_dest_path=""
currentUser=`whoami`
current_package_to_install_is_already_availible_via_filesystem=""
installpkg_path="`which installpkg`"
installpkg_pacakage_name="InstallPKG.pkg"
installpkg_installation_attempted="NO"

function pre_flight_check {
	# Check we are running as root
    currentUser=`whoami`
    if [ $currentUser != "root" ] ; then
        echo This script must be run with super user privileges
        exit -127
    fi
	
	# Check the number of arguments provided is okay.
    if [ $num_argumnets -lt 1 ] ; then
        echo "ERROR ! : No argument provided. This script will now exit."
        echo "          Usage : configure_with_package_list.bash /path/to/package_install_list.txt"
        exit -127
    fi

}

function install_package {
	
	# Ensure that the default is to download a file each time this funion is called (this is paranoid).
	current_package_to_install_is_already_availible_via_filesystem="NO"

	# Calculate the name of the pacakge to install
	current_pacakge_to_install_name=`basename "${current_package_to_install}"`
	if [ "$current_pacakge_to_install_name" == "" ] ; then
		return -1
	fi
	
	# Check if this package listed has a specific download url provided or a specific file system path provided
	first_seven_charcters="`echo "${current_package_to_install}" | cut -c 1-7`"
	if [ "${first_seven_charcters}" != "http://" ] && [ "${first_seven_charcters}" != "file://" ] ; then
		download_url=$package_download_directory/${current_package_to_install}
	else
		if [ "${first_seven_charcters}" == "http://" ] ; then
			download_url="${current_package_to_install}"
		fi
		if [ "${first_seven_charcters}" == "file://" ] ; then
			current_package_to_install_is_already_availible_via_filesystem="YES"
			download_url="`echo \"${current_package_to_install}\" | cut -c 8-`"
		fi
	fi

	# Either download the file or check it is locally available
	if [ "${current_package_to_install_is_already_availible_via_filesystem}" == "NO" ] ; then
		
		# Set download location 
		current_package_download_dest_path="${download_directory}/${current_pacakge_to_install_name}"
		
		# Download the package
		#echo "downloading : ${download_url}"
		curl "${download_url}" -o "${current_package_download_dest_path}" 2> /dev/null	
		# Check the download was succesful
		if [ $? != 0 ] ; then 
			echo ""
			echo "ERROR! Unable to download package : ${download_url}"
			echo ""
			((num_unsuccesful_packages_downloaded_and_installed+1))
			rm -r "${current_package_download_dest_path}"
			return -1
		fi
	else
		# Check it exists
		if [ -e "${download_url}" ] ; then
				current_package_download_dest_path="${download_url}"
		else
				echo ""
				echo "ERROR! Unable to locate this local package : ${download_url}"
				echo ""
				((num_unsuccesful_packages_downloaded_and_installed+1))
				return -1
		fi
	fi
	
	# Determine the download files .extension (suffix)
	download_suffix=`echo "${current_package_download_dest_path##*.}"`
	
	# If download is .pkg, .mpkg or .dmg then install using installpkg
	if [ ".${download_suffix}" == ".dmg" ] || [ ".${download_suffix}" == ".pkg" ] || [ ".${download_suffix}" == ".mpkg" ] ; then 
		
		# Install installpkg if required, installer is available in the same directory as the script and an installation attempt has not been attempted on this execution of the script.
		if [ "${installpkg_path}" == "" ] &&  [ "${installpkg_installation_attempted}" == "NO" ] && [ -e "${parent_directory_path}/${installpkg_pacakage_name}" ] ; then
			echo "Installing InstallPKG onto this system…"
			installer -pkg "${parent_directory_path}/${installpkg_pacakage_name}" -target / > /dev/null
			installpkg_installation_return_code=$?
			installpkg_installation_attempted="YES"
			installpkg_path="`which installpkg`"
			if [ "${installpkg_path}" != "" ] && [ $installpkg_installation_return_code == 0 ] ; then
				echo "    InstallPKG was installed successfully."
			else
				echo "    ERRROR! : During InstallPKG automatic installation."
				echo "              Manual installation of InstallPKG onto this system is recommended."
			fi
		fi

		# check that installpkg is installed
		if [ "${installpkg_path}" == "" ] ; then
			echo "ERROR! : InstallPKG is not installed on this system."
			echo "         Unable to install : ${download_url}"
			num_unsuccesful_packages_downloaded_and_installed=$((num_unsuccesful_packages_downloaded_and_installed+1))
			return -1
		fi

		# Check the installed version of installpkg will support installation of .dmg wrapped packages.
		if [ ".${download_suffix}" == ".dmg" ] ; then
			instaled_pkg_first_version=`grep "# Version " "${installpkg_path}" | awk '{print $3}' | awk -F "." '{print $1}'`
			instaled_pkg_second_version=`grep "# Version " "${installpkg_path}" | awk '{print $3}' | awk -F "." '{print $2}'`
			instaled_pkg_third_version=`grep "# Version " "${installpkg_path}" | awk '{print $3}' | awk -F "." '{print $3}'`
			if [ $instaled_pkg_first_version -le 0 ] ; then
				if [ $instaled_pkg_second_version -le 0 ] ; then 
					if [ $instaled_pkg_third_version -le 7 ] ; then 
						echo "ERROR! This version of installpkg will not support the installation of .dmg files"
						num_unsuccesful_packages_downloaded_and_installed=$((num_unsuccesful_packages_downloaded_and_installed+1))
						return -1
					fi
				fi
			fi
		fi

		# install the package		
		if [ ".${download_suffix}" == ".dmg" ] ; then
			# install the dmg wrapped package
			installpkg -i "${current_package_download_dest_path}" >/dev/null
			package_installation_result=$?
		else
			# directly install the package or meta-package
			installpkg "${current_package_download_dest_path}" >/dev/null
			package_installation_result=$?
		fi

		# Check the install went okay
		if [ $package_installation_result != 0 ] ; then
			echo "ERROR! Installing package : ${download_url}"
			num_unsuccesful_packages_downloaded_and_installed=$((num_unsuccesful_packages_downloaded_and_installed+1))
			return -1
		fi
		
		# Remove the installer - provided it was downloaded
		if [ "${current_package_to_install_is_already_availible_via_filesystem}" == "NO" ] ; then
			rm -r "${current_package_download_dest_path}"
		fi
		
		return 0
	fi
	
	
	# If download is any other kind of file assume it is executable script or binary and run... carful (you could restrict this to only some kinds of file types).
	if [ "${execute_unknowen_file_types}" == "YES" ] ; then 
		# change permissions of this download (make executable)
		chmod 700 "${current_package_download_dest_path}" >/dev/null
		if [ $? != 0 ] ; then
			echo "ERROR! setting the executability of the downloaded script : ${download_url}"
			exit -1
		fi
		
		# execute this downloaded file (as we are in bash if there is no magic (eg. txt file) then it will execute as BASH).
		$current_package_download_dest_path
		
		# Check the execution was succesful
		if [ $? != 0 ] ; then
			echo "ERROR! during execution of script : ${download_url}"
			num_unsuccesful_packages_downloaded_and_installed=$((num_unsuccesful_packages_downloaded_and_installed+1))
			return -1
		fi
		
		# Remove the installer - provided it was downloaded
		if [ "${current_package_to_install_is_already_availible_via_filesystem}" == "NO" ] ; then
			rm -r "${current_package_download_dest_path}"
		fi
		
		return 0
	fi
	
	echo "ERROR! Not able to handle this filetype : ${download_url}"
	return -1
	
}

pre_flight_check

# create the working directory
mkdir -p $download_directory


# load all the packages to install from the input file into an array and install them as we go. 
# maybe there is no need to store them in the array? It could be handy in a later version of the script?
index=0
while read line ; do
    
	# remove comments (ugly but works) - this will process comments containing a hash
    processed_line=`echo "${line}" | sed -e 's/^[ \t]*//' | sed 's:#.*::' | sed 's/[ \t]*$//'`
	
    if [ "$processed_line" != "" ] ; then
		packages_to_install[$index]="$processed_line"
		current_package_to_install=${packages_to_install[${index}]}
		index=$(($index+1))
		install_package 
		if [ $? == 0 ] ; then
			num_succesful_packages_downloaded_and_installed=$(($num_succesful_packages_downloaded_and_installed+1))
		fi
	fi
	
done < "${1}"

# Report results if requested
if [ "${print_report}" = "YES" ] ; then 
	if [ $num_succesful_packages_downloaded_and_installed -gt 0 ] ; then
		echo "Successfully installed [${num_succesful_packages_downloaded_and_installed}] packages"
	fi
	if [ $num_unsuccesful_packages_downloaded_and_installed -gt 0 ] ; then
		echo "WARNING! : Problems were encountered with [${num_unsuccesful_packages_downloaded_and_installed}] packages"
		exit -1
	fi
fi


exit 0




