#!/bin/bash

usage() {
cat << EOF
Usage: qmrimaps [-h] [-m model_file] DATA_DIR OUTPUT_DIR
Process MRI in DATA_DIR and put results into OUTPUT_DIR.

optional arguments:
	-h|--help		show this usage
	-m|--model		Use given trained model
	-t|--t1			T1 for anatomy segmentation (default: anat/T1.nii.gz) 
	-r|--ref		Reference MRI to register to (default: perf/tMIP.nii.gz)
	
EOF
	exit 0
}

invalid() {
	echo "ERROR: Invalid argument $1"
	usage 1
}

die() {
	echo "ERROR: $1"
	exit 1
}

# defaults
MODEL_ARGS=""
T1_FILE=anat/T1.nii.gz
REF_FILE=perf/tMIP.nii.gz

# Parse arguments
POSITIONAL=()
while [[ $# -gt 0 ]]; do
	case "${1}" in
		-h|--help)	usage 0;;
		-m|--model)	shift; MODEL_ARGS="--model $1" ;;
		-t|--t1)	shift; T1_FILE="$1" ;;
		-r|--ref)	shift; REF_FILE="$1" ;;
		-*)		invalid "$1" ;;
		*)		POSITIONAL+=("$1") ;;
	esac
	shift
done

# Restore positional parameters
set -- "${POSITIONAL[@]}"

if [ $# -lt 2 ] ; then
	usage 1
fi

SRC=$1
DST=$2
SCRIPT_DIR=`dirname $0`/src

# check prerequisites
#[[ -f ${T1} ]] || die "Invalid input volume: ${T1} not found"
[[ "`which dl+direct`X" != "X" ]] || die "dl+direct not found. Install it from https://github.com/SCAN-NRAD/DL-DiReCT"
[[ "`which flirt`X" != "X" ]] || die "FSL flirt not found. Install it from https://fsl.fmrib.ox.ac.uk/fsl/fslwiki"
[[ "`which Rscript`X" != "X" ]] || die "Rscript not found. Install R"

mkdir -p ${DST} || die "Could not create target directory ${DST}"

echo
echo "If you are using qMriMaps in your research, please cite:"
cat ${SCRIPT_DIR}/../doc/cite.md
echo


# run DL+DiReCT
for SUBJ in `ls ${SRC}` ; do
	dl+direct --subject ${SUBJ} --bet --no-cth ${MODEL_ARGS} ${SRC}/${SUBJ}/${T1_FILE} ${DST}/subjects/${SUBJ} || die "running DL+DiReCT"
done

# register
for SUBJ in `ls ${DST}/subjects` ; do
	DST_DIR=${DST}/subjects/${SUBJ}	
	flirt -in ${SRC}/${SUBJ}/${REF_FILE} -ref ${DST_DIR}/T1w_norm.nii.gz -out ${DST_DIR}/tmpregvol.nii -omat ${DST_DIR}/invol2refvol.mat -dof 6 -cost mutualinfo -verbose 2

	# invert transformation matrix
	convert_xfm -omat ${DST_DIR}/inverted.mat -inverse ${DST_DIR}/invol2refvol.mat

	# transform t1 and labels into maps space
	flirt -in ${DST_DIR}/T1w_norm.nii.gz -ref ${SRC}/${SUBJ}/${REF_FILE} -out ${DST_DIR}/t1-registered.nii.gz -init ${DST_DIR}/inverted.mat -applyxfm
	flirt -in ${DST_DIR}/T1w_norm_seg.nii.gz -ref ${DST_DIR}/t1-registered.nii.gz -out ${DST_DIR}/label-registered.nii.gz -interp nearestneighbour -init ${DST_DIR}/inverted.mat -applyxfm
done

# calculate ROI stats
python ${SCRIPT_DIR}/extract_stats.py ${SRC} ${DST}

# generate maps
Rscript --vanilla ${SCRIPT_DIR}/maps.R ${DST} `cat ${DST}/maps.txt`

