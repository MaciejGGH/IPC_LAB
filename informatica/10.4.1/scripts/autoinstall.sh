#!/bin/bash

declare -a answers=()
# Do you want to cointinue? (Y/N)
answers+=("Y")

# # 1) Install and configure Informatica version 10.4.1 products.
# # 2) Upgrade Informatica products to version 10.4.1.
# # 3) Configure the Enterprise Data Catalog or Enterprise Data Preparation version 10.4.1
# # 4) Install or upgrade Data Transformation Engine
# # 5) Apply hotfix to Informatica 10.4.0 or roll back the hotfix
# # Enter the choice (1 or 2 or 3 or 4 or 5)
answers+=(1)

# # 1) Run the Pre-Installation System Check Tool (i10Pi)
# # 2) Run the Informatica Kerberos SPN Format Generator
# # 3) Run the installer
answers+=(3)

# # I agree to the terms and conditions
# # 1) No
# # 2) Yes
answers+=(2)

# # Select one of the following installation options for version 10.4.1:
# # 1) Install and configure Informatica domain services.
# # 2) Install and configure Enterprise Data Catalog.
# # 3) Install and configure Enterprise Data Preparation.
# # 4) Install and configure Data Privacy Management.
answers+=(1)

# # Do you want to enable Kerberos network authentication for the Informatica domain?
# # 1) No
# # 2) Yes
answers+=(1)

# # Press <Enter> to continue ...
answers+=(" ")

# # If you are installing Data Engineering products or Enterprise Data Catalog, the installer can tune the application services for better performance based on the deployment type in your environment. If you do not tune services during installation, you can tune the services later through infacmd.
# #
# # The installer cannot tune the PowerCenter services. If you are installing PowerCenter, press 1 to continue without tuning.
# # Do you want the installer to tune the services?
# # 1) No
# # 2) Yes
answers+=(1)

# # Enter the installation directory (default:- /home/informatica/Informatica/10.4.1)
answers+=("/opt/Informatica")

# # Enter the path to the license key file (default:- /home/informatica/license.key)
answers+=("/tmp/software/license.key")

# # Installation environment:
# #   * 1->Sandbox
# #     2->Development
# #     3->Test
# #     4->Production
answers+=(4)

# # Press <Enter> to continue ...
answers+=("")

# #[ Type 'back' to go to the previous panel or 'help' to check the help contents for this panel or 'quit' to cancel the installation at any time. ]
# # 1) Create a domain
# # 2) Join a domain
answers+=("quit")

#dummy
answers+=("")

function concat_ { local IFS=$'\n'; echo -e "$*"; }
cd "/tmp/software" || exit 1
concat_ "${answers[@]}" | ./install.sh