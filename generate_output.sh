#!/bin/bash

set -eu

if [ $# -ne 1 ]; then
    echo "Usage: $0 kicad_project_name"
    exit 1
fi

PROJECT_NAME=$1
PROJECT_DIR=$(dirname ${PROJECT_NAME})

if ! [ -r "${PROJECT_NAME}.kicad_pcb" ]; then
    echo "${PROJECT_NAME}.kicad_pcb does not exist!"
    exit 1
fi

CAN_DESCRIBE=1
git -C ${PROJECT_DIR} describe --tags || CAN_DESCRIBE=0

if [ $CAN_DESCRIBE -eq 0 ]; then
    echo "Cannot use git to describe this project. Is there a git repo with a valid tag?"
    exit 1
fi

cd ${PROJECT_DIR}

## cleanup
rm -rf Gerbers/ ${PROJECT_NAME}.zip Fabrication/ Output/

## Gerber files
mkdir Gerbers
cd Gerbers
kicad-cli pcb export gerbers ../${PROJECT_NAME}.kicad_pcb
kicad-cli pcb export drill ../${PROJECT_NAME}.kicad_pcb
cd -
zip -qrD ${PROJECT_NAME} Gerbers

## BOM
mkdir Fabrication
kicad-cli sch export bom ${PROJECT_NAME}.kicad_sch --group-by Value,Footprint --exclude-dnp --fields "Reference,Value,Footprint,\${QUANTITY},LCSC#" --labels "Refs,Value,Footprint,Qty,LCSC#" -o "Fabrication/${PROJECT_NAME}_bom.csv"

## Position file
kicad-cli pcb export pos ${PROJECT_NAME}.kicad_pcb --exclude-dnp --units mm --format csv -o ${PROJECT_NAME}.pos
sed -i "s/Ref/\"Designator\"/g" ${PROJECT_NAME}.pos
sed -i "s/PosX/\"Mid X\"/g" ${PROJECT_NAME}.pos
sed -i "s/PosY/\"Mid Y\"/g" ${PROJECT_NAME}.pos
sed -i "s/Rot/\"Rotation\"/g" ${PROJECT_NAME}.pos
sed -i "s/Side/\"Layer\"/g" ${PROJECT_NAME}.pos
sed -i "s/Val/\"Value\"/g" ${PROJECT_NAME}.pos
$(dirname $0)/fix_rotation -i ${PROJECT_NAME}.pos -o Fabrication/${PROJECT_NAME}_pos.csv
rm ${PROJECT_NAME}.pos



## Schematics
mkdir Output
kicad-cli sch export pdf -D version=`git -C ${PROJECT_DIR} describe --tags` -D date=`git -C ${PROJECT_DIR} show -s --format=%cd --date=format:'%d.%m.%Y'` ${PROJECT_NAME}.kicad_sch -o Output/${PROJECT_NAME}.pdf

## STEP file
kicad-cli pcb export step -D version=`git -C ${PROJECT_DIR} describe --tags` -D date=`git -C ${PROJECT_DIR} show -s --format=%cd --date=format:'%d.%m.%Y'` ${PROJECT_NAME}.kicad_pcb -o Output/${PROJECT_NAME}.step
