# scripts

Various shell scripts to ease OpenShift admin tasks and etc. You may need to run cdmod +x to make the shell script executable.

# createPV.sh

This script creates PV and NFS for OpenShift. Mainly used for demo environment preparation. Run createPV.sh or createPV.sh -h to find out how to use this script.

# configure_nexus3_repo.sh

Script to configure Nexus repos for redhat-ga, jboss, maven-central,maven-releases,maven-snapshots, maven-all-public. It also added a releases repo to store build releases, if you wish to keep your releases in Nexus

# initGogs.sh

Script to download source files from one git and commit the source files into another git. Strictly created to setup demo environment. Run initGogs.sh or initGogs.sh -h to view the usage information.
