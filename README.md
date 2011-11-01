# CWPL - Configure With Package List #

This is a simple open source (GNU GPL) installation system. It provides the ability to deploy a number of software or configuration files to a number of
computers.

It will download scripts or Apple Installer Packages (.pkg ; even wrapped in a .dmg) and install these on Mac OS X based systems. The packages / scripts may be located on an http server. Future versions may provide other options

To run this system you will require InstallPKG (provides a wrapper to the 'installer' tool on Mac OS X systems) to be installed on the system(s) which are running the script (clients). When downloading and installing .dmg  InstallPKG is required. InstallPKG is available from github : https://github.com/henri/installpkg

Usage : 

(1) Install InstallPKG on systems where you will be using CWPL.
    You could make a wrapper script which will do this for you.
    
(2) Edit the cwpl.configuration file (you may remove or alter
    the symbolic link to suite your needs, example provided).
    
(3) Upload your .dmg .pkg and executables to the web server.

(4) Generate a installation configuration file. This is simply
    a file with a list of items to install or execute. An example
    file is : ./example_setups_configurations/computer_setup.txt
    
(5) Execute the configure_with_package_list.bash script and pass
    in the installation configuration file as the first argument.
    An example of this is provided below :

    configure_with_package_list.bash /path/to/computer_setup.txt

(6) Items specified within the installation configuration file 
    should now be installed on the system.

Comments and suggestions regarding this project are very welcome.
