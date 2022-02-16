#!/bin/bash

# Read common commands from dss_common.sh
source $(dirname $0)/dss_common.sh

# URL of the DSS middleware server, for exaple http://localhost:8080
DSSURL=${1?}

# The service identifier, which is a 40-character hash code of the given Git commit of the 
# service descriptor repository. In this case, the repository is at
# https://github.com/pyushkevich/alfabis-svc-example
SERVICE_GITHASH=${2?}
SERVICE_GITHASH2=${3?}

# Temp directory -- in a multi-user environment make sure this is a unique path
TMPDIR=/tmp

# Authentication. This authentication code only works when a DSS server is in ridiculously
# insecure 'testing' mode. In real production environment, a user must manually log in once
# using itksnap-wt -dss-auth $DSSURL. Afterwards, the login credentials will be stored in
# the user's ~/.alfabis directory so there is no need to authenticate in the script itself
dss_auth $DSSURL

# Create the service. In production mode, this would be done by an administrator. Here we do
# this before launching the service
dss_admin_service $DSSURL $SERVICE_GITHASH $SERVICE_GITHASH2

# This is the main function that gets executed. Execution is very simple,
#   1. Claim a ticket under our service
#   2. If no ticket claimed, sleep a few seconds, and return to 1
#   3. Extract necessary objects from the ticket
#   4. Run neck extraction script
#   5. Create a workspace with the results and upload it
while [[ true ]]; do

  # Try to claim a ticket under our service. The last two parameters to the command are the
  # provider identifier and the within-provider identifier (in case you are running this script
  # on multiple servers). They can be dummy values.
  itksnap-wt -dssp-services-claim $SERVICE_GITHASH test 01 > $TMPDIR/claim.txt

  # If the return code is non-zero, there was nothing to claim, so we wait and continue
  if [[ $? -ne 0 ]]; then
    itksnap-wt -dssp-services-claim $SERVICE_GITHASH2 test 01 > $TMPDIR/claim.txt
    if [[ $? -ne 0 ]]; then
      sleep 10
      continue
    fi
  fi
 
  SERVICE_SELECTED=$(cat $TMPDIR/claim.txt | sed -e 's/.*services=\(.*\)&provider.*/\1/' | head -n1)

  # The output of the -dssp-services-claim command consists of the service hash code and a ticket
  # number. The service hash code is useful when a provider offers multiple services. In this 
  # example it can be ignored. Ticket ID is what we care about
  TICKET_ID=$(cat $TMPDIR/claim.txt | grep '^1>' | awk '{print $2}')

  if [[ "$SERVICE_SELECTED" == "$SERVICE_GITHASH" ]]; then
    itksnap-wt -dssp-tickets-log $TICKET_ID info "Primer servicio, pa alante"
    echo 'iguales, servicio 1'
    #continue
    source ./serv1.sh
  else
    echo 'no iguales'
    itksnap-wt -dssp-tickets-log $TICKET_ID info "Es el segundo servicio, error de momento"
    continue
  fi 

done
  









