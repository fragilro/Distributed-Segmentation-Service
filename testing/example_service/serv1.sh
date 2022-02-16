#!/bin/bash

  # Set the work directory for this ticket and create it
  WORKDIR=work/$(printf ticket_%08d $TICKET_ID)
  mkdir -p $WORKDIR

  # Download the ticket to workdir. File downlaod.txt contains the list of all files that
  # have been downloaded
  itksnap-wt -P -dssp-tickets-download $TICKET_ID $WORKDIR > $TMPDIR/download.txt

  # If the download failed we mark the ticket as failed
  if [[ $? -ne 0 ]]; then
    itksnap-wt -dssp-tickets-fail $TICKET_ID "Failed to download the ticket"
    continue
  fi

  # Get the workspace filename 
  WSFILE=$(cat $TMPDIR/download.txt | grep "\.itksnap$") 

  # If the ticket did not contain a workspace file (weird but possible) return an error
  if [[ ! -f $WSFILE ]]; then
    itksnap-wt -dssp-tickets-fail $TICKET_ID "Workspace file missing in downloaded ticket"
    continue
  fi

  # Extract the T1-weighted image from the workspace
  T1_NII=$(itksnap-wt -P -i $WSFILE -llf T1-MRI)

  # If the image did not extract, send error
  if [[ $(echo $T1_NII | wc -w) -ne 1 || ! -f $T1_NII ]]; then
    itksnap-wt -dssp-tickets-fail $TICKET_ID "Missing tag 'T1-MRI' in ticket workspace"
    exit -1
  fi

  # Send a progress message
  itksnap-wt -dssp-tickets-set-progress $TICKET_ID 0.0 1.0 0.2 
  itksnap-wt -dssp-tickets-log $TICKET_ID info "Downloaded ticket successfully"

  # Run the actual neck cutting script
  /bin/bash trim_neck_rf.sh -d -w $WORKDIR/tmpfiles -m $WORKDIR/mask.nii.gz $T1_NII $WORKDIR/trim.nii.gz \
    > $WORKDIR/output.txt 2&>1

  # If script failed then fail and send log files as the attachment
  if [[ $? -ne 0 ]]; then
    itksnap-wt -dssp-tickets-attach $TICKET_ID "Script Output" $WORKDIR/output.txt
    itksnap-wt -dssp-tickets-fail $TICKET_ID "Neck cutting script failed."
    exit -1
  fi

  # Indicate that the actual job has completed
  itksnap-wt -dssp-tickets-set-progress $TICKET_ID 0.0 1.0 0.8 
  itksnap-wt -dssp-tickets-log $TICKET_ID info "Neck cutting script finished"

  # Create an ITK-SNAP label file for the segmentation
  LABELFILE=$WORKDIR/seglabel.txt
  echo '# ITK-SnAP Label Description File' > $LABELFILE
  echo '0 0 0 0 0 0 0 "Clear Label"' >>  $LABELFILE
  echo '1 255 0 0 1 1 1 "Label 1"' >> $LABELFILE

  # Create a workspace to hold the results
  WSRESULT=$WORKDIR/$(printf ticket_%08d_result.itksnap $TICKET_ID)
  itksnap-wt -i $WSFILE \
    -layers-add-seg $WORKDIR/mask.nii.gz -props-set-nickname "Head/Neck Segmentation" \
    -layers-add-anat $WORKDIR/trim.nii.gz -props-set-nickname "Trimmed MRI" \
    -labels-set $LABELFILE \
    -layers-list \
    -o $WSRESULT

  # Upload the result workspace
  itksnap-wt -i $WSRESULT -dssp-tickets-upload $TICKET_ID 

  # If the download failed we mark the ticket as failed
  if [[ $? -ne 0 ]]; then
    itksnap-wt -dssp-tickets-fail $TICKET_ID "Failed to upload the ticket"
    continue
  fi

  # Mark the ticket as success
  itksnap-wt -dssp-tickets-success $TICKET_ID

  









