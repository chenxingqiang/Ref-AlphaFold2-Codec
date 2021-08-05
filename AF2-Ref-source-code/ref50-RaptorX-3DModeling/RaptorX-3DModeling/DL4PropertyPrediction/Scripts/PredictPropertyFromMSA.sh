#!/bin/sh

## this script predicts properties from an .hhm or .a3m file

if [[ -z "$DL4PropertyPredHome" ]]; then
	echo "ERROR: please set environmental variable DL4PropertyPredHome to the instllation directory of DL4PropertyPrediction"
	exit 1
fi

if [[ -z "$DistFeatureHome" ]]; then
	echo "ERROR: please set environmental variable DistFeatureHome to the instllation directory of BuildFeatures"
	exit 1
fi

DeepModelFile=$DL4PropertyPredHome/params/ModelFile4PropertyPred.txt
ModelName=PhiPsiSet10820Models
GPU=-1
ResultDir=`pwd`

function Usage 
{
        echo $0 "[ -f DeepModelFile | -m ModelName | -d ResultDir | -g gpu ] MSAfile"
	echo "	This script predicts protein local structure properties from a .hhm or .a3m file"
	echo "	MSAfile: a multiple sequence alignment file in .a3m format or an .hhm file generated by hhmake"
	echo " "
        echo "	DeepModelFile: a file containing a set of deep model names, default $DeepModelFile"
        echo "	ModelName: a model name (defined in DeepModelFile) representing a set of deep learning models, default $ModelName"
        echo "	ResultDir: the folder for result saving, default current work directory"
        echo "	gpu: -1 (default), 0-3. If set to -1, automatically select a GPU"
}

while getopts ":f:m:d:g:" opt; do
        case ${opt} in
                f )
                  DeepModelFile=$OPTARG
                  ;;
                m )
                  ModelName=$OPTARG
                  ;;
                d )
                  ResultDir=$OPTARG
                  ;;
                g )
                  GPU=$OPTARG
                  ;;
                \? )
                  echo "Invalid Option: -$OPTARG" 1>&2
                  exit 1
                  ;;
                : )
                  echo "Invalid Option: -$OPTARG requires an argument" 1>&2
                  exit 1
                  ;;
        esac
done
shift $((OPTIND -1))

if [ $# -ne 1 ]; then
        Usage
        exit 1
fi

MSAfile=$1
if [ ! -f $MSAfile ]; then
	echo "ERROR: invalid input file $MSAfile"
	exit 1
fi

if [ ! -f $DeepModelFile ]; then
        echo "ERROR: cannot find the file for deep models: $DeepModelFile"
        exit 1
fi

if [ ! -d $ResultDir ]; then
        mkdir -p $ResultDir
fi

fulnam=`basename $MSAfile`
target=${fulnam%.*}

hhmfile=${ResultDir}/${target}.hhm

if [[ "$fulnam" == *.hhm ]]; then
	hhmfile=$MSAfile
else
	$DistFeatureHome/util/hhmake -i $MSAfile -o $hhmfile
fi

## convert hhmfile to a feature file for property prediction
python $DL4PropertyPredHome/GenPropertyFeaturesFromMultiHHMs.py $target $hhmfile $ResultDir

if [ ! -f $ResultDir/$target.propertyFeatures.pkl ]; then
	echo "ERROR: failed to generate $ResultDir/$target.propertyFeatures.pkl "
	exit 1
fi

$DL4PropertyPredHome/Scripts/PredictPropertyLocal.sh -f $DeepModelFile -m $ModelName -d $ResultDir -g $GPU $ResultDir/$target.propertyFeatures.pkl
if [ ! -f $ResultDir/$target.predictedProperties.pkl ]; then
	echo "ERROR: failed to predict properties for $target from $MSAfile "
	exit 1
fi