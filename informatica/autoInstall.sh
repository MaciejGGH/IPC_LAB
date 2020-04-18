#!/bin/bash

declare -a answers=()
# Do you want to cointinue? (Y/N)
answers+=("Y")

# # 1) Install Informatica
# # 2) Upgrade Informatica
# # 3) Install or upgrade Data Transformation Engine Only
# # Enter the choice (1 or 2 or 3)
answers+=(1)

# # 1) Run the Pre-Installation (i10PreInstallChecker) System Check Tool
# # 2) Run the Informatica Kerberos SPN Format Generator
# # 3) Run the Informatica services installation 
answers+=(3)

# # I agree to the terms and conditions
# # 1) No
# # 2) Yes
answers+=(2)

# # Select one of the following options to install Informatica 10.2.0 services or Informatica Enterprise Information Catalog version 10.2.0:
# # 1) Install Informatica Services.
# # 2) Install Informatica Enterprise Information Catalog.
answers+=(1)

# # Enable Kerberos network authentication for the Informatica domain.
# # 1) No
# # 2) Yes
answers+=(1)

# # Press <Enter> to continue ...
answers+=(" ")

# # Enter the license key file: (default :- /root/license.key)
answers+=("${SOFTWARE_DIR}/license.key")

# # Enter the installation directory: (default:- /root/Informatica/10.2.0)
answers+=("/opt/Informatica")

# # Press <Enter> to continue ...
answers+=("")

# #[ Type 'back' to go to the previous panel or 'help' to check the help contents for this panel or 'quit' to cancel the installation at any time. ]
# # 1) Create a domain
# # 2) Join a domain
answers+=("quit")

#dummy
answers+=("")

function concat_ { local IFS=$'\n'; echo -e "$*"; }
cd ${SOFTWARE_DIR}
concat_ "${answers[@]}" | ./install.sh