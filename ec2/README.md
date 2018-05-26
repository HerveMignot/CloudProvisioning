# Installation scripts for EC2 instances

Author: RV

## Installing R, R Studio Server and Shiny Server on EC2

### install-rstudio-ec2.sh

This is a customization of multiple sources.

The following versions should / can be updated (or provided as script arguments, see below):
* R Studio: RSTUDIO_VERSION="1.1.453"

* Shiny Server: SHINY_SERVER_VERSION="1.5.8.913"

R Studio port can be changed with (or script argument, see below):
* RSTUDIO_PORT="8787"

Changing Shiny Server port (3838) has not been yet implemented.

#### Supported options

The following options are supported as script args:
* `--port <RSTUDIO port>`: change R Studio Server default port (8787)
* `--user <R user>`: change R default user (ruser)
* `--password <R user password>`: change R default user password (ruser)
* `--version <RSTUDIO version>`: download & install this R Studio version
* `--shiny-version <SHINY version>`: download & install this R Studio version
* `--shiny`: make sure Shiny Server is installed
* `--noshiny`: make sure Shiny Server is NOT installed (default)
