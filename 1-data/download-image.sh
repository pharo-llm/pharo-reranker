#!/bin/bash
set -e

# Create directory and download Pharo image
mkdir -p baseimage && cd baseimage
wget -q -O - https://get.pharo.org/140+vm | bash

# Clone the pharo-dataset repository
echo "Cloning pharo-dataset repository..."
git clone https://github.com/pharo-llm/pharo-dataset.git

# Load the HeuristicCompletionGenerator package into the image
echo "Loading HeuristicCompletionGenerator package..."
./pharo Pharo.image eval --save "
Metacello new
    githubUser: 'omarabedelkader'
    project: 'HeuristicCompletion-Generator'
    commitish: 'main'
    path: 'src';
    baseline: 'HeuristicCompletionGenerator';
    load."

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

lsof -nP -iTCP:8080 -sTCP:LISTEN
kill -9 $(lsof -tiTCP:8080 -sTCP:LISTEN)

# Load full Roassal version and exporters
echo "Loading Seaside Full and exporters..."
./pharo Pharo.image eval --save "
Metacello new
    baseline: 'Seaside3';
    repository: 'github://SeasideSt/Seaside:master/repository';
    load."


# Launch the FIM JSONL exporter
echo "Running CooCompletionFineTuningDatasetExporter exportAllFIMJsonl..."
./pharo Pharo.image eval --save "CooCompletionDatasetExporter missingPackages."
./pharo Pharo.image eval --save "CooCompletionFineTuningDatasetExporter exportAllFIMJsonl."
./pharo Pharo.image eval --save "CooCompletionFineTuningDatasetExporter exportAllRerankerJsonl."

echo "Export completed!"