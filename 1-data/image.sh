#!/usr/bin/env sh
set -eu


mkdir -p image
cd image
curl -fsSL https://get.pharo.org/140+vm | bash
curl -fLO https://files.pharo.org/image/140/Pharo14.0-SNAPSHOT.build.415.sha.359c9be46a.arch.64bit.zip
unzip -o Pharo14.0-SNAPSHOT.build.415.sha.359c9be46a.arch.64bit.zip
./pharo Pharo14.0-SNAPSHOT-64bit-359c9be46a.image eval "2+2"
echo "Done image installation"

./pharo Pharo.image eval --save "
Metacello new
    githubUser: 'omarabedelkader'
    project: 'HeuristicCompletion-Generator'
    commitish: 'main'
    path: 'src';
    baseline: 'HeuristicCompletionGenerator';
    load."
echo "Done Bench installation"


# Load full Roassal version and exporters
echo "Loading Roassal Full and exporters..."
./pharo Pharo.image eval --save "
[
    Metacello new
        baseline: 'Roassal';
        repository: 'github://pharo-graphics/Roassal:Pharo' , SystemVersion current major asString;
        load: 'Full'
]
    on: MCMergeOrLoadWarning
    do: [ :warning | warning load ].
"
echo "Done Roassal installation"

./pharo Pharo.image eval --save "
Metacello new
    baseline: 'Seaside3';
    repository: 'github://SeasideSt/Seaside:master/repository';
    load."
echo "Done Seaside installation"


# Launch the FIM JSONL exporter
echo "Running CooCompletionFineTuningDatasetExporter exportAllFIMJsonl..."
./pharo Pharo.image eval --save "CooCompletionDatasetExporter missingPackages."
./pharo Pharo.image eval --save "CooCompletionFineTuningDatasetExporter exportAllFIMJsonl."
./pharo Pharo.image eval --save "CooCompletionFineTuningDatasetExporter exportAllRerankerJsonl."
echo "Done Export!"