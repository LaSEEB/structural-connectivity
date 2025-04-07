#!/bin/bash
set -e

display_usage() {
	echo ""
	tput bold 
	echo "Description"
	tput sgr0
	echo ""
	echo "This script uses MRTrix and FSL to create the connectivity matrix using a given atlas. It assumes the data is multi-shelled."
	echo ""
	tput bold 
	echo "Usage"
	tput sgr0
	echo ""
	echo "It requires 7 arguments: DWI, bvecs, bvals, T1, ATLAS, WARP_STD2STRUCT, REMOVE_TEMP."
	}

if [ $# -lt 7 ] # if there are less than 7 arguments
then
	display_usage
	exit 1
fi

########################### STEP 1 ###################################
#             		  Prepare data and directories					 #
######################################################################

mkdir -p temp
cd temp

# Full paths of Images in NIFTI form
DWI=$1 # Diffusion image
BVEC=$2
BVAL=$3
ANAT=$4 # Structural Image, e.g. T1-weighted
ATLAS=$5 # Atlas file in standard space
WARP_STD2STRUCT=$6 # warp file of tranformation from stndard space to strucural space
REMOVE_TEMP=$7 # 0 or 1, whether to remove the temporary directory with intermediary files

########################### STEP 2 ###################################
#	      		  Convert data to .mif format		     			 #
######################################################################

# Convert data do mif format
mrconvert $DWI dwi.mif -fslgrad $BVEC $BVAL -force
mrconvert $ANAT anat.mif -force

dwi2mask dwi.mif mask.mif -fslgrad $BVEC $BVAL -force

########################## STEP 3 ###################################
#            Basis function for each tissue type                    #
#####################################################################

# Create a basis function from the subject's DWI data. The "dhollander" function is best used for multi-shell acquisitions; it will estimate different basis functions for each tissue type. For single-shell acquisition, use the "tournier" function instead
dwi2response dhollander dwi.mif wm.txt gm.txt csf.txt -force

# Performs multishell-multitissue constrained spherical deconvolution, using the basis functions estimated above
dwi2fod msmt_csd dwi.mif -mask mask.mif wm.txt wmfod.mif gm.txt gmfod.mif csf.txt csffod.mif -force

# Now normalize the FODs to enable comparison between subjects
mtnormalise wmfod.mif wmfod_norm.mif gmfod.mif gmfod_norm.mif csffod.mif csffod_norm.mif -mask mask.mif -force

########################### STEP 4 ###################################
#            Create a GM/WM boundary for seed analysis               #
######################################################################

# Extract all five tissue categories (1=GM; 2=Subcortical GM; 3=WM; 4=CSF; 5=Pathological tissue)
5ttgen fsl anat.mif 5tt_nocoreg.mif -premasked -nocrop -force

#The following series of commands will take the average of the b0 images (which have the best contrast), convert them and the 5tt image to NIFTI format, and use it for coregistration.
dwiextract dwi.mif - -bzero | mrmath - mean mean_b0_processed.mif -axis 3 -force
mrconvert mean_b0_processed.mif mean_b0_processed.nii.gz -force
mrconvert 5tt_nocoreg.mif 5tt_nocoreg.nii.gz -force

# Uses FSL commands fslroi and flirt to create a transformation matrix for registration between the tissue map and the b0 images
fslroi 5tt_nocoreg.nii.gz 5tt_vol0.nii.gz 0 1 # Extract the first volume of the 5tt dataset (since flirt can only use 3D images, not 4D images)

flirt -in mean_b0_processed.nii.gz -ref 5tt_vol0.nii.gz -interp nearestneighbour -dof 6 -omat diff2struct_fsl.mat
transformconvert diff2struct_fsl.mat mean_b0_processed.nii.gz 5tt_nocoreg.nii.gz flirt_import diff2struct_mrtrix.txt -force
mrtransform 5tt_nocoreg.mif -linear diff2struct_mrtrix.txt -inverse 5tt_coreg.mif -force

#Create a seed region along the GM/WM boundary
5tt2gmwmi 5tt_coreg.mif gmwmSeed_coreg.mif -force

########################## STEP 5 ###################################
#            		  Coregister atlas to the data              	#
#####################################################################

# Coregister atlas to struct space and convert to mrtrix format
applywarp -i $ATLAS -r $ANAT --out=atlas_2struct --warp=$WARP_STD2STRUCT --interp=nn
mrconvert atlas_2struct.nii.gz atlas_2struct.mif -force

# Coregister atlas to diff space
mrtransform atlas_2struct.mif -linear diff2struct_mrtrix.txt -inverse atlas2diff.mif --interp nearest -force

########################### STEP 6 ###################################
#                 Run the streamline analysis                        #
######################################################################

# Create streamlines: maxlength=250mm, 10M seeds
tckgen -act 5tt_coreg.mif -seed_gmwmi gmwmSeed_coreg.mif -maxlength 250 -select 10000000 wmfod_norm.mif tracks.tck -force

# Reduce the number of streamlines with tcksift
tcksift2 -act 5tt_coreg.mif tracks.tck wmfod_norm.mif sift.txt -force

########################### STEP 7 ###################################
#             		  Creating the connectome	             		 #
######################################################################

# Creating the connectome 
tck2connectome -symmetric -zero_diagonal -scale_invnodevol -tck_weights_in sift.txt tracks.tck atlas2diff.mif "../connectivity_matrix.csv" -force

###  Ending
cd ..
# Remove unneeded data from storage because it is not needed anymore
if [ $REMOVE_TEMP -eq 1 ]; then
	rm -rf temp
fi
