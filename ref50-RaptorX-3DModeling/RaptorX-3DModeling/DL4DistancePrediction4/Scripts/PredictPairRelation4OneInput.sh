#!/bin/sh

if [[ -z "${DL4DistancePredHome}" ]]; then
        echo "ERROR: please set environmental variable DL4DistancePredHome to the install folder of DL4DistancePrediction4"
        exit 1
fi

DeepModelFile=$DL4DistancePredHome/params/ModelFile4PairwisePred.txt
#ModelName=EC47C31C16CL99LargerS35V2020CbCbTwoRModels
#DeepModelFile=/mnt/data/RaptorXCommon/TrainTestData/Distance_Contact_TrainData/Jinbo_Folder/result4HBBeta/DistanceV3ModelFiles.txt
#ModelName=EC47C37C19CL99S35V2020MidModels
GPU=-1
ResultDir=`pwd`

DefaultModel4FM=EC47C37C19CL99S35V2020MidModels
DefaultModel4HHP=HHEC47C37C19CL99S35PDB70Models
DefaultModel4NDT=NDTEC47C37C19CL99S35BC40Models
ModelName=""

alignmentType=0

function Usage 
{
	echo $0 "[ -f DeepModelFile | -m ModelName | -d ResultDir | -g gpu | -T alignmenType ] inputFeature_PKL"
	echo Or $0 "[ -f DeepModelFile | -m ModelName | -d ResultDir | -g gpu | -T alignmenType ] inputFeature_PKL aliFile/aliFolder tplFile/tplFolder"
	echo "	This script predicts distance/orientation from one set of input features for a single protein, and optionally seq-template alignment information"
	echo "	inputFeature_PKL: a feature file XXX.inputFeatures.pkl where XXX is protein name. The other two feature files XXX.extraCCM.pkl and XXX.a2m shall be in the same folder"
	echo "		These feature files may be generated from an MSA by BuildFeatures/GenDistFeaturesFromA3M.sh"
	echo "	aliFile/aliFolder: optional, a pairwise seq-template alignment file in FASTA format or one/multiple folders for alignment files"
	echo "		an alignment file shall have name like queryProteinName-*.fasta. If multple folders are provided, they shall be separated by ;"
	echo "		Two different alignment files shall have differnt names even if they are in different folders"
	echo "	tplFile/tplFolder: optional, a template file in PKL format generated by Common/MSA2TPL.sh or a folder for multiple template files"
	echo "		When one or multiple alignment folders are provided, a template folder instead of a template file shall be provided"
	echo "		a template file shall have name templateName.tpl.pkl"
	echo "	-T: indicate how sequence-template alignments are generated: 1 for alignments generated by HHpred and 2 for alignments generated by RaptorX threading"
	echo "		This option will be used only if both aliFile/aliFolder and tplFile/tplFolder are present"
	echo " "
	echo "	-f: a file containing path info for deep learning models, default $DeepModelFile"
	echo "	-m: a model name defined in DeepModelFile representing a set of deep learning models. Below is the default setting:"
        echo "		When aliFile/aliFolders are not used, $DefaultModel4FM will be used."
        echo "		When aliFile/aliFolders are used, if alignmentType=2, $DefaultModel4NDT will be used; otherwise $DefaultModel4HHP will be used"
	echo "	-d: the folder for result saving, default current work directory"
	echo "	-g: -1 (select a GPU automatically), 0-3, default $GPU"
	echo "		Users shall make sure that at least one GPU has enough memory for the prediction job. Otherwise it may crash itself or other jobs"
}

while getopts ":f:m:d:g:T:" opt; do
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
		T )
		  alignmentType=$OPTARG
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

if [ $# -ne 1 -a $# -ne 3 ]; then
        Usage
        exit 1
fi

inputFeature=$1
if [ ! -f $inputFeature ]; then
	echo "ERROR: invalid input feature file: $inputFeature"
	exit 1
fi
proteinName=`basename $inputFeature .inputFeatures.pkl`

if [ $# -eq 3 ]; then
	aliStr=$2
	tplStr=$3
fi

program=$DL4DistancePredHome/RunPairwisePredictor.py
if [ ! -f $program ]; then
	echo ERROR: invalid program $program
	exit 1
fi

if [ ! -f $DeepModelFile ]; then
        echo "ERROR: invalid file for deep model path information: $DeepModelFile"
        exit 1
fi

## load model file names
. $DeepModelFile

if [ $# -eq 3 ]; then
	 if [ -z "$ModelName" ]; then
                if [ $alignmentType -eq 2 ]; then
                        ModelName=$DefaultModel4NDT
                else
                        ModelName=$DefaultModel4HHP
                fi
        fi
else
	if [ -z "$ModelName" ]; then
                ModelName=$DefaultModel4FM
        fi

fi

ModelFiles=`eval echo '$'${ModelName}`
#echo ModelFiles=$ModelFiles
if [ $ModelFiles == "" ]; then
	echo "ERROR: ModelFiles for $ModelName is empty"
	exit 1
fi

if [ ! -d $ResultDir ]; then
	mkdir -p $ResultDir
fi

command=" python $program -m $ModelFiles -p $inputFeature -d $ResultDir "
if [ $# -eq 3 ]; then
	command=$command" -a $aliStr -t $tplStr "
fi

if [[ -z "${CUDA_ROOT}" ]]; then
        echo "ERROR: please set environmental variable CUDA_ROOT"
        exit 1
fi
if [ $GPU == "-1" ]; then
        ## here we assume 2G is sufficient, although usually not
        neededRAM=2147483648
        GPU=`$ModelingHome/Utils/FindOneGPUByMemory.sh $neededRAM 40`
fi

if [ $GPU == "-1" ]; then
        echo "WARNING: cannot find an appropriate GPU to run $0 for $proteinName"
        exit 1
else
        GPU=cuda$GPU
fi

THEANO_FLAGS=blas.ldflags=,device=$GPU,floatX=float32,dnn.include_path=${CUDA_ROOT}/include,dnn.library_path=${CUDA_ROOT}/lib64 $command
if [ $? -ne 0 ]; then
        echo "ERROR: failed to run $command"
        exit 1
fi
