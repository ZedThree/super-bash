#!/bin/bash

#Load colours
COL_FILE="~/BIN/.term_colours"
if [ -e ${COL_FILE} ]
then
    source ${COL_FILE}
else
    BC_BLACK="\033[030m"
    BC_RED="\033[031m"
    BC_GREEN="\033[032m"
    BC_YELLOW="\033[033m"
    BC_BLUE="\033[034m"
    BC_PURPLE="\033[035m"
    BC_CYAN="\033[036m"
    BC_WHITE="\033[037m"
    BC_RESET="\033[039m"
fi

#Settings
N_ARG=1
BLK_TMP="tmp_blk.tmp"
INDEN="_____"

if [ $# -lt ${N_ARG} ] #Give usage message
then
    echo -e ${BC_RED}"ERROR"${BC_RESET}": Usage = "$0" filename(s)"
    exit -1
elif [ $# -gt ${N_ARG} ] #Loop over arguments
then
    for i in `seq 1 $#`
    do
        #Call this script on first arg and then shift args to the left by 1.
	$0 $1
	shift 1
    done
    rm -i ${BLK_TMP}
    exit 0
else
    #Set the file name
    FILE_NM=$1

    #Get a short file name
    FILE_NM_SHORT=`basename ${FILE_NM}`
fi

#Define regular expressions
FUNC_TYPES="ELEMENTAL|REAL|INTEGER|DOUBLE|COMPLEX|PURE"
MODULE_REG="^ *?MODULE +?([a-zA-Z0-9\_]+?) *?(\!.*)?$"
SUBR_REG="^ *?SUBROUTINE +?([a-zA-Z0-9\_]+?) *?(\(.*?\))?(\!.*)?$"
FUNC_REG="^ *?(${FUNC_TYPES})? +?FUNCTION +?([a-zA-Z0-9\_]+?) *?(\(.*?\))?(\!.*)?$"
BLOCK_REG="^ *?(MODULE|SUBROUTINE|(${FUNC_TYPES})? *?FUNCTION) +?([a-zA-Z0-9\_]+?) *?(\(.*?\))?(\!.*)?$"
BLOCK_REG_END="^ *?END *?(MODULE|SUBROUTINE|FUNCTION) +?" #([a-zA-Z0-9\_]+?) *?(\(.*?\))?(\!.*)?$"

#Get all blocks, relatively fast
grep -iEn "${BLOCK_REG}" ${FILE_NM} > ${BLK_TMP}

#Now get number of blocks
NBLK=`wc -l ${BLK_TMP} | awk '{print $1}'`

#Loop over blocks
for i in `seq 1 ${NBLK}`
do
  #Get matching line
  LINE=`head -n ${i} ${BLK_TMP} | tail -n 1`
  
  #Get line number in file
  LN=`echo ${LINE} | awk -F":" '{print $1}'`
  
  #Get text of line, remove all leading blanks
  #and remove all brackets and comments
  TXT=`echo ${LINE} | awk -F":" '{print $2}' | \
       sed -e 's/^[ \t]*//' | sed 's/(.*)//g' | sed 's/!.*//g'`

  #Count words
  NW=`echo ${TXT} | wc -w`

  #Block name is last word
  BN=`echo ${TXT} | awk -v VAR=${NW} '{print $VAR}'`

  #Block type is second last word
  BT=`echo ${TXT} | awk -v VAR=$((${NW}-1)) '{print $VAR}'`

  #Form regular expression
  REG=${BLOCK_REG_END}${BN}" *?(\!.*)? *?$"

  #Get end lines
  TMP1=`grep -iEn "${REG}" ${FILE_NM} | awk -F":" '{print $1}'`

  #Check if multiple matches found
  NMATCH=`echo ${TMP1} | wc | awk '{print $2}'`
  
  #Try a less restrictive match if none found
  if [ ${NMATCH} -eq 0 ]
  then
      REG=${BLOCK_REG_END}" *?(\!.*)? *?$"

      #Get end lines
      TMP1=`grep -iEn "${REG}" ${FILE_NM} | awk -F":" '{print $1}'`

      #Check if multiple matches found
      NMATCH=`echo ${TMP1} | wc | awk '{print $2}'`
  fi

  #Try least restrictive match if none found
  if [ ${NMATCH} -eq 0 ]
  then
      REG="^ *END *?(\!.*)? *?$"
      
      #Get end lines
      TMP1=`grep -iEn "${REG}" ${FILE_NM} | awk -F":" '{print $1}'`

      #Check if multiple matches found
      NMATCH=`echo ${TMP1} | wc | awk '{print $2}'`
  fi

  if [ ${NMATCH} -eq 0 ]
  then
      echo -e ${BC_RED}"WARNING"${BC_RESET}": No end statements found for block "${BN}"."
  fi

  #Loop over matches and use first one greater than LN
  MAT_SET=0
  j=0
  for j in ${TMP1}
  do
    if [ ${j} -gt ${LN} ]
    then
	LE=${j}
	MAT_SET=1
	break
    fi
  done

  if [ ${MAT_SET} -eq 0 ]
  then 
      echo -e ${BC_PURPLE}"WARNING"${BC_RESET}": No end found so skipping."
      continue
  fi

  #//Now get parent

  #Set current block number
  TMP1=$((${i}-1)) #`echo ${i}| awk '{print $1-1}'`

  #Default parent and depth
  PAR="<NONE>"
  PARVAL=0

  #Get blocks which are already known about, have starting line before current blocks and ending line after current blocks
  PAR_AND_DEPTH=`awk -v TMP1=${TMP1} -v LE=${LE} -v LN=${LN} '(NR<=TMP1) && ($4>LE) && ($1<LN) {print $3" "$6+1}' ${BLK_TMP}`

  #Get how many words (this is 2*block depth)
  NWORD=`echo ${PAR_AND_DEPTH} | wc -w`
  if [ ! ${NWORD} -eq 0 ]
  then
      PAR=`echo ${PAR_AND_DEPTH} | awk -v COL=$((${NWORD}-1)) '{print $COL}'`
      PARVAL=`echo ${PAR_AND_DEPTH} | awk -v COL=${NWORD} '{print $COL}'`
  fi
      
  #Update temp file
  #Stores Line of block start, block type, block name, line of end of block, parent and depth
  sed --in-place -e ${i}'s/.*/'"${LN} ${BT} ${BN} ${LE} ${PAR} ${PARVAL}"'/g' ${BLK_TMP}

done
 
#Now use data to draw tree
#Loop over blocks
for i in `seq 1 ${NBLK}`
do
    #Extract block line
    TMP2=`sed -n ${i},${i}'p' ${BLK_TMP}`
    
    #Get block depth
    NIN=`echo ${TMP2} | awk '{print $6}'`

    #Add indentation text
    if [ ${NIN} -gt 0 ]
    then
	yes "${INDEN}" | head -n ${NIN} | tr -d '\n'
    fi

    #Print the block name
    echo ${TMP2} | awk '{print $3}'
done
