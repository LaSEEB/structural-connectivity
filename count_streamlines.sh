#!/bin/bash
set -e

display_usage() {
	echo ""
	tput bold 
	echo "Description"
	tput sgr0
	echo ""
	echo "This script uses MRTrix and FSL to count the streamlines that pass through each ROI of a predefined atlas."
	echo ""
	tput bold 
	echo "Usage"
	tput sgr0
	echo ""
	echo "It requires 6 arguments: DWI, ANAT, ATLAS, ANAT2STD_WARP, TRACT_FILE, REMOVE_TEMP."

	}

if [ $# -lt 6 ] # if there is less than 6 arguments
then
	display_usage
	exit 1
fi

DWI=$1
ANAT=$2
ATLAS=$3
ANAT2STD_WARP=$4
TRACT_FILE=$5
REMOVE_TEMP=$6 # 0 or 1, whether to remove the temporary directory with intermediary files

mkdir -p temp
cd temp

########################## STEP 1 ###################################
#            		  Coregister atlas to the data              #
#####################################################################

applywarp -i $ATLAS -r $ANAT --out=atlas_2struct --warp=$ANAT2STD_WARP
mrconvert atlas_2struct.nii.gz atlas_2struct.mif -force
mrtransform atlas_2struct.mif -linear diff2struct_mrtrix.txt -inverse atlas_coreg.mif -force
mrcalc atlas_coreg.mif -round -datatype uint32 atlas.mif -force

########################## STEP 2 ###################################
#   		Create mask files with each ROI of the atlas       	    #
#####################################################################

# Divide ROIs into separate files and set the input directory containing the ROI masks
ATLAS_ROIS_DIRECTORY="./atlas_rois"
rm -rf ${ATLAS_ROIS_DIRECTORY}
mkdir -p ${ATLAS_ROIS_DIRECTORY}

# Create one mask for each ROI of the atlas
N_ROIS=$(mrstats $ATLAS -output max)
for ((i = 1 ; i <= N_ROIS ; i++)); do
	if [ "$i" -lt 10 ]; then
		idx="0${i}"
	else
		idx="${i}"
	fi
	#divide atlas into regions of interest
    mrcalc ${ATLAS} $i -eq "${ATLAS_ROIS_DIRECTORY}/atlas_roi_${idx}.mif" -force # 1 if =i, 0 otherwise
	mrconvert "${ATLAS_ROIS_DIRECTORY}/atlas_roi_${idx}.mif" "${ATLAS_ROIS_DIRECTORY}/atlas_roi_${idx}.nii.gz" -force
	rm -f "${ATLAS_ROIS_DIRECTORY}/atlas_roi_${idx}.mif"
done

# remove the file with the list of the number of streamlines per ROI if it exists
rm -f ../streamlines.txt

########################## STEP 3 ###################################
#         Count streamlines in each ROI by masking tractogram       #
#####################################################################

# Loop through each ROI mask in the input directory and count streamlines that pass through each of them
for roi_mask in $(ls ${ATLAS_ROIS_DIRECTORY}/*.nii.gz); do
    
    # Define the output tract file for the selected tracts
    output_tract_file="selected_tracts.tck"
    
    # Use tckedit to select the streamlines that pass through the ROI mask
    tckedit -mask $roi_mask "${TRACT_FILE}" "${output_tract_file}" -force
    
    # Use tckinfo to count the streamlines in the selected ROI
    info=$(tckinfo "$output_tract_file" -count)
    num_streamlines=$(echo $info | awk '{print $NF}')
    rm -f $output_tract_file
    
    # Print number of streamlines to txt
    printf "${num_streamlines}\n" >> "../streamlines.txt"
done

###  Ending
rm -rf ${ATLAS_ROIS_DIRECTORY}
cd ..
# Remove unneeded data from storage because it is not needed anymore
if [ $REMOVE_TEMP -eq 1 ]; then
	rm -rf temp
fi