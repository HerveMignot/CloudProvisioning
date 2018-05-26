#!/bin/bash

# -x: trace script, similar to -v
# -e: abort at first error
set -x -e

# Based on install-jupyter-ec2.sh
# Based on https://gist.github.com/JohnMount/3694b155d2d184d263e4e34c6ae4a943
# Adaptation by HerveMignot

# Tunnel Mode was used in the original version, see: https://www.r-bloggers.com/setting-up-rstudio-server-quickly-on-amazon-ec2/
# On local machine:
# $1: local path to PEM file
# $2: EC2 hostname / IP for setting up
# pempath="$1"
# ec2target="$2"

# Check OS? (this run on Ubuntu only)
if [ `awk -F= '/^NAME/{print $2}' /etc/os-release` != '"Ubuntu"' ]; then
    echo "Sorry, this does not look like Ubuntu. Aborting."
    exit -1
fi

R_DEFAULT_USER="ruser"
R_PASSWORD=$R_DEFAULT_USER

RSTUDIO_VERSION="1.1.453"
RSTUDIO_PORT="8787"

SHINY=true
SHINY_SERVER_VERSION="1.5.8.913"
SHINY_SERVER_PORT="3838"

# get input parameters
while [ $# -gt 0 ]; do
    case "$1" in
    --version)
      shift
      RSTUDIO_VERSION=$1
      ;;
    # --toree)
    #   TOREE_KERNEL=true
    #   ;;
    # --torch)
    #   TORCH_KERNEL=true
    #   ;;
    # --javascript)
    #   JS_KERNEL=true
    #   ;;
    # --ds-packages)
    #   DS_PACKAGES=true
    #   ;;
    # --ml-packages)
    #   ML_PACKAGES=true
    #   ;;
    # --bigdl)
    #   BIGDL=true
    #   ;;
    # --mxnet)
    #   MXNET=true
    #   ;;
    # --dl4j)
    #   DL4J=true
    #   ;;
    --gpu)
      GPU=true
      CPU_GPU="gpu"
      GPUU="_gpu"
      ;;
    # --run-as-step)
    #   RUN_AS_STEP=true
    #   ;;
    --port)
      shift
      RSTUDIO_PORT=$1
      ;;
    --user)
      shift
      R_DEFAULT_USER=$1
      ;;
    --password)
      shift
      R_PASSWORD=$1
      ;;
    # --copy-samples)
    #   COPY_SAMPLES=true
    #   ;;
    # --ssl)
    #   SSL=true
    #   ;;
    --shiny)
      SHINY=true
      ;;      
    --noshiny)
      SHINY=false
      ;;
    --shiny-version)
      shift
      SHINY_SERVER_VERSION=$1
      ;;
    --spark-opts)
      shift
      USER_SPARK_OPTS=$1
      ;;
    --spark-version)
      shift
      APACHE_SPARK_VERSION=$1
      ;;
    # --s3fs)
    #   #NOTEBOOK_DIR_S3_S3NB=false
    #   NOTEBOOK_DIR_S3_S3CONTENTS=false
    #   ;;
    --tunnel)
      TUNNEL=true
      ;;
    -*)
      # do not exit out, just note failure
      error_msg "unrecognized option: $1"
      ;;
    *)
      break;
      ;;
    esac
    shift
done

sudo apt-get -y update
sudo apt-get -y upgrade
# https://www.digitalocean.com/community/tutorials/how-to-install-r-on-ubuntu-16-04-2

# Add CRAN repo to apt sources
sudo add-apt-repository 'deb [arch=amd64,i386] https://cran.rstudio.com/bin/linux/ubuntu xenial/'
sudo apt-get update

# Install base packages
# Use only gdebi-core?
sudo apt-get -y --allow-unauthenticated install r-base r-base-dev
sudo apt-get -y install default-jre default-jdk
sudo apt-get -y install gdebi postgresql postgresql-contrib pgadmin3 libpq-dev whois imagemagick 
sudo apt-get -y install libmagick++-dev libcurl4-openssl-dev 
sudo apt-get -y install qpdf texlive-latex-base texlive-fonts-recommended texlive-fonts-extra texlive-latex-extra texinfo
sudo apt-get -y install emacs

# Download RStudio Server version
wget https://download2.rstudio.org/rstudio-server-$RSTUDIO_VERSION-amd64.deb
sudo gdebi -n rstudio-server-$RSTUDIO_VERSION-amd64.deb
sudo rm -f rstudio-server-$RSTUDIO_VERSION-amd64.deb

# Configure R Studio Server port
sudo /bin/bash -c "echo 'www-port=$RSTUDIO_PORT' >> /etc/rstudio/rserver.conf"
if [ "$TUNNEL" = true ]; then
    # Preparing for tunnel mode
    sudo /bin/bash -c "echo 'www-address=127.0.0.1' >> /etc/rstudio/rserver.conf"
fi

# Start or restart, that is the question
sudo rstudio-server start
#sudo rstudio-server restart

# Add R user (ruser)
sudo useradd -m -p `mkpasswd -m sha-512 $R_PASSWORD` -s /bin/bash $R_DEFAULT_USER
sudo cp -r ~/.ssh /home/$R_DEFAULT_USER/.ssh
sudo chown -R ${R_DEFAULT_USER}.${R_DEFAULT_USER} /home/$R_DEFAULT_USER/.ssh
sudo -u postgres createuser --superuser ubuntu
sudo -u postgres createdb ubuntu
sudo -u postgres createuser $R_DEFAULT_USER
sudo -u postgres createdb $R_DEFAULT_USER
echo "ALTER USER $R_DEFAULT_USER WITH PASSWORD '$R_PASSWORD';" | sudo -u postgres psql 
sudo R CMD javareconf

# -x: trace script, similar to -v
# cancel stopping at first fail
set -x

# Install additional packages
#R CMD INSTALL pkg1 pkg2 
#R CMD INSTALL -l /path/to/library pkg1 pkg2 

# Install shiny and shiny-server
# For a more sophisticated installation, see https://www.digitalocean.com/community/tutorials/how-to-set-up-shiny-server-on-ubuntu-16-04
# Changing the default port requires editing /etc/shiny-server/shiny-server.conf (to do)
if [ "$SHINY" = true ]; then
    sudo R -e "install.packages('shiny', repos='http://cran.rstudio.com/')"
    wget https://download3.rstudio.org/ubuntu-14.04/x86_64/shiny-server-$SHINY_SERVER_VERSION-amd64.deb
    sudo gdebi -n shiny-server-$SHINY_SERVER_VERSION-amd64.deb
    rm shiny-server-$SHINY_SERVER_VERSION-amd64.deb

    # For yum
    #wget https://download3.rstudio.org/centos5.9/x86_64/shiny-server-1.5.4.869-rh5-x86_64.rpm
    #yum install -y --nogpgcheck shiny-server-1.5.4.869-rh5-x86_64.rpm

    # Deploy the Shiny configuration using ShinyApps subdirectory to store apps (user-dirs)
    sudo mkdir /home/$R_DEFAULT_USER/ShinyApps
    sudo sh -c 'yes | /opt/shiny-server/bin/deploy-example user-dirs'
    sudo cp -R /opt/shiny-server/samples/sample-apps/hello /home/$R_DEFAULT_USER/ShinyApps/hello
fi

# Role Permission example to allow a user to access some bucket
# This user role must be assigned to IAM role for the EC2 instance
# See: https://aws.amazon.com/fr/blogs/big-data/running-r-on-aws/
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Action": ["s3:ListBucket"],
#       "Resource": ["arn:aws:s3:::rstatsdata"]
#     },
#     {
#       "Effect": "Allow",
#       "Action": [
#         "s3:PutObject",
#         "s3:GetObject",
#         "s3:DeleteObject"
#       ],
#       "Resource": ["arn:aws:s3:::rstatsdata/*"]
#     }
#   ]
# }

# Example for reading R data from a public bucket (permission: Everyone)
# > install.packages("RCurl")
# > library("RCurl") 
# > data <- read.table(textConnection(getURL(
#                                                "https://cgiardata.s3-us-west-2.amazonaws.com/ccafs/amzn.csv"
#                          )), sep=",", header=FALSE)
# > head(data)

if [ "$TUNNEL" = true ]; then
    # echo "SWITCHING TO TUNNEL MODE"
    # # on local
    # ssh -i "${pempath}" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -N -L 8787:127.0.0.1:8787 ruser@${ec2target}
    # # visit http://127.0.0.1:8787 user ruser password ruser
fi
