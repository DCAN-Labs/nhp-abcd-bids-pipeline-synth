#!/bin/bash 

Subjlist="M126 M128 M129 M131 M132" #Space delimited list of subject IDs
StudyFolder="/media/myelin/brainmappers/Connectome_Project/InVivoMacaques" #Location of Subject folders (named by subjectID)
EnvironmentScript="/media/2TBB/Connectome_Project/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

# Requirements for this script
#  installed versions of: FSL5.0.2 or higher , FreeSurfer (version 5.2 or higher) , gradunwarp (python code from MGH)
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR , PATH (for gradient_unwarp.py)

#Set up pipeline environment variables and software
. ${EnvironmentScript}

# Log the originating call
echo "$@"

#if [ X$SGE_ROOT != X ] ; then
    QUEUE="-q long.q"
#fi

PRINTCOM=""
#PRINTCOM="echo"
#QUEUE="-q veryshort.q"


########################################## INPUTS ########################################## 

#Scripts called by this script do NOT assume anything about the form of the input names or paths.
#This batch script assumes the HCP raw data naming convention, e.g.

#	${StudyFolder}/unprocessed/3T/T1w_MPR1/${Subject}_3T_T1w_MPR1.nii.gz
#	${StudyFolder}/unprocessed/3T/T1w_MPR2/${Subject}_3T_T1w_MPR2.nii.gz

#	${StudyFolder}/unprocessed/3T/T2w_SPC1/${Subject}_3T_T2w_SPC1.nii.gz
#	${StudyFolder}/unprocessed/3T/T2w_SPC2/${Subject}_3T_T2w_SPC2.nii.gz

#	${StudyFolder}/unprocessed/3T/T1w_MPR1/${Subject}_3T_FieldMap_Magnitude.nii.gz
#	${StudyFolder}/unprocessed/3T/T1w_MPR1/${Subject}_3T_FieldMap_Phase.nii.gz

#Change Scan Settings: FieldMap Delta TE, Sample Spacings, and $UnwarpDir to match your images
#These are set to match the HCP Protocol by default

#If using gradient distortion correction, use the coefficents from your scanner
#The HCP gradient distortion coefficents are only available through Siemens
#Gradient distortion in standard scanners like the Trio is much less than for the HCP Skyra.


######################################### DO WORK ##########################################


for Subject in $Subjlist ; do
  echo $Subject
  
  #Input Images
  #Detect Number of T1w Images
  numT1ws=`ls ${StudyFolder}/RawData/${Subject} | grep mpr | wc -l`
  T1wInputImages=""
  i=1
  while [ $i -le $numT1ws ] ; do
    T1wInputImages=`echo "${T1wInputImages}${StudyFolder}/RawData/mpr$(zeropad ${i} 2).nii.gz@"`
    i=$(($i+1))
  done
  
  #Detect Number of T2w Images
  numT2ws=`ls ${StudyFolder}/RawData/${Subject} | grep spc | wc -l`
  T2wInputImages=""
  i=1
  while [ $i -le $numT2ws ] ; do
    T2wInputImages=`echo "${T2wInputImages}${StudyFolder}/RawData/spc$(zeropad ${i} 2)_TE566.nii.gz@"`
    i=$(($i+1))
  done
  MagnitudeInputName="${StudyFolder}/RawData/Magnitude.nii.gz" #Expects 4D magitude volume with two 3D timepoints or "NONE" if not used
  PhaseInputName="${StudyFolder}/RawData/Phase.nii.gz" #Expects 3D phase difference volume or "NONE" if not used

  SpinEchoPhaseEncodeNegative="NONE" #For the spin echo field map volume with a negative phase encoding direction (LR in HCP data), set to NONE if using regular FIELDMAP
  SpinEchoPhaseEncodePositive="NONE" #For the spin echo field map volume with a positive phase encoding direction (RL in HCP data), set to NONE if using regular FIELDMAP

  #Templates
  T1wTemplate="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T1w_0.5mm_grad.nii.gz" #MacaqueYerkes0.5mm template
  T1wTemplateBrain="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T1w_0.5mm_brain.nii.gz" #Brain extracted MacaqueYerkes0.5mm template
  T1wTemplate2mm="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T1w_1.0mm_grad.nii.gz" #MacaqueYerkes1.0mm template
  T2wTemplate="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T2w_0.5mm_grad.nii.gz" #MacaqueYerkes0.5mm T2wTemplate
  T2wTemplateBrain="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T2w_0.5mm_brain.nii.gz" #Brain extracted MacaqueYerkes0.5mm T2wTemplate
  T2wTemplate2mm="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T2w_1.0mm_grad.nii.gz" #MacaqueYerkes1.0mm T2wTemplate
  TemplateMask="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T1w_0.5mm_brain_mask_dil.nii.gz" #Brain mask MacaqueYerkes0.5mm template
  Template2mmMask="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T1w_1.0mm_brain_mask_dil.nii.gz" #MacaqueYerkes1.0mm template
  StudyTemplate="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T1w_0.5mm_grad.nii.gz"
  StudyTemplateBrain="${HCPPIPEDIR_Templates}/MacaqueYerkes19_T1w_0.5mm_brain.nii.gz"

  #Scan Settings
  TE="2.46" #delta TE in ms for field map or "NONE" if not used
  DwellTime="NONE" #Echo Spacing or Dwelltime of SE Field Map image (or "NONE" if not used) = 1/(BandwidthPerPixelPhaseEncode * # of phase encoding samples): DICOM field (0019,1028) = BandwidthPerPixelPhaseEncode, DICOM field (0051,100b) AcquisitionMatrixText first value (# of phase encoding samples)
  SEUnwarpDir="NONE" #x or y (minus or not does not matter) "NONE" if not used 
  T1wSampleSpacing="0.0000150" #DICOM field (0019,1018) in s or "NONE" if not used
  T2wSampleSpacing="0.0000036" #DICOM field (0019,1018) in s or "NONE" if not used
  UnwarpDir="y-" #z appears to be best or "NONE" if not used
  GradientDistortionCoeffs="NONE" #Location of Coeffs file or "NONE" to skip

  #Config Settings
  BrainSize="80" #BrainSize in mm, 150 for humans
  FNIRTConfig="${HCPPIPEDIR_Config}/T1_2_MNI152_2mm.cnf" #FNIRT 2mm T1w Config
  AvgrdcSTRING="FIELDMAP" #Averaging and readout distortion correction methods: "NONE" = average any repeats with no readout correction "FIELDMAP" = average any repeats and use field map for readout correction "TOPUP" = Use Spin Echo FieldMap
  TopupConfig="NONE" #Config for topup or "NONE" if not used
  BiasFieldSmoothingSigma="1.5"
  useAntsReg="false"

  ${FSLDIR}/bin/fsl_sub ${QUEUE} \
     ${HCPPIPEDIR}/PreFreeSurfer/PreFreeSurferPipeline.sh \
      --path="$StudyFolder" \
      --subject="$Subject" \
      --t1="$T1wInputImages" \
      --t2="$T2wInputImages" \
      --t1template="$T1wTemplate" \
      --t1templatebrain="$T1wTemplateBrain" \
      --t1template2mm="$T1wTemplate2mm" \
      --t2template="$T2wTemplate" \
      --t2templatebrain="$T2wTemplateBrain" \
      --t2template2mm="$T2wTemplate2mm" \
      --templatemask="$TemplateMask" \
      --template2mmmask="$Template2mmMask" \
      --brainsize="$BrainSize" \
      --fnirtconfig="$FNIRTConfig" \
      --fmapmag="$MagnitudeInputName" \
      --fmapphase="$PhaseInputName" \
      --echodiff="$TE" \
      --SEPhaseNeg="$SpinEchoPhaseEncodeNegative" \
      --SEPhasePos="$SpinEchoPhaseEncodePositive" \
      --echospacing="$DwellTime" \
      --seunwarpdir="$SEUnwarpDir" \
      --t1samplespacing="$T1wSampleSpacing" \
      --t2samplespacing="$T2wSampleSpacing" \
      --unwarpdir="$UnwarpDir" \
      --gdcoeffs="$GradientDistortionCoeffs" \
      --avgrdcmethod="$AvgrdcSTRING" \
      --topupconfig="$TopupConfig" \
      --bfsigma="$BiasFieldSmoothingSigma" \
      --useAntsReg="${useAntsReg}" \
      --StudyTemplate="${StudyTemplate}" \
      --StudyTemplateBrain="${StudyTemplateBrain}" \
      --printcom=$PRINTCOM
      
  # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

  echo "set -- --path=${StudyFolder} \
      --subject=${Subject} \
      --t1=${T1wInputImages} \
      --t2=${T2wInputImages} \
      --t1template=${T1wTemplate} \
      --t1templatebrain=${T1wTemplateBrain} \
      --t1template2mm=${T1wTemplate2mm} \
      --t2template=${T2wTemplate} \
      --t2templatebrain=${T2wTemplateBrain} \
      --t2template2mm=${T2wTemplate2mm} \
      --templatemask=${TemplateMask} \
      --template2mmmask=${Template2mmMask} \
      --brainsize=${BrainSize} \
      --fnirtconfig=${FNIRTConfig} \
      --fmapmag=${MagnitudeInputName} \
      --fmapphase=${PhaseInputName} \
      --echodiff=${TE} \
      --SEPhaseNeg=${SpinEchoPhaseEncodeNegative} \
      --SEPhasePos=${SpinEchoPhaseEncodePositive} \
      --echospacing=${DwellTime} \
      --seunwarpdir=${SEUnwarpDir} \
      --t1samplespacing=${T1wSampleSpacing} \
      --t2samplespacing=${T2wSampleSpacing} \
      --unwarpdir=${UnwarpDir} \
      --gdcoeffs=${GradientDistortionCoeffs} \
      --avgrdcmethod=${AvgrdcSTRING} \
      --topupconfig=${TopupConfig} \
      --bfsigma=${BiasFieldSmoothingSigma} \
      --useAntsReg=${useAntsReg} \
      --StudyTemplate=${StudyTemplate} \
      --StudyTemplateBrain=${StudyTemplateBrain} \
      --printcom=${PRINTCOM}"

  echo ". ${EnvironmentScript}"

done

