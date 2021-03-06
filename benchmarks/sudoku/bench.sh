#!/bin/bash

procCount=16

programs=(
    "parmonad-sudoku"
    "parrows-sudoku-parmap-eden"
    "parrows-sudoku-parmap-mult"
    "parrows-sudoku-parmap-par"
    "sudoku-seq"
    "multicore-sudoku"
    "eden-sudoku"
)

parameters=(
    "sudoku17.1000.txt"
    "sudoku17.16000.txt"
)

./recompile.sh

# get length of an array
programCount=${#programs[@]}

benchCmds=""

for parameter in "${parameters[@]}"
do
    for (( i=0; i < ${programCount}; i++ ));
    do
        progName=${programs[$i]}
        if [ "${progName}" == "sudoku-seq" ]
        then
            cmd="\"./"${progName}" "${parameter}"\""
            benchCmds=${benchCmds}" "${cmd}
        else
            for (( j=${procCount}; j>=1; j=j/2 ));
            do
                cmd="\"./"${progName}" "${parameter}" +RTS -N"${j}"\""

                benchCmds=${benchCmds}" "${cmd}
            done
        fi
    done
done

echo "running: bench"${benchCmds}" --csv bench.csv"

eval "bench"${benchCmds}" --csv bench.csv"
