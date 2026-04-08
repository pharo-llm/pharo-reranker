#!/bin/bash

# Hugging Face Dataset Push Script
# Configure these variables before running

HF_USERNAME="your-username"
REPO_NAME="your-dataset-repo-name"
DATASET_DIR="./00-dataset/baseimage"

# File patterns to track with Git LFS (adjust for your dataset)
LFS_PATTERNS="*.png *.jpg *.jpeg *.webp *.parquet *.arrow *.zip"

REMOTE_URL="ssh://git@huggingface.co/$HF_USERNAME/$REPO_NAME"

# Check if dataset directory exists
if [ ! -d "$DATASET_DIR" ]; then
    echo "Error: Dataset directory '$DATASET_DIR' does not exist"
    exit 1
fi

# Check if git-lfs is installed
if ! command -v git-lfs &> /dev/null; then
    echo "Error: git-lfs is not installed. Install it first:"
    echo "  macOS: brew install git-lfs"
    echo "  Ubuntu: sudo apt-get install git-lfs"
    exit 1
fi

cd "$DATASET_DIR" || exit 1

# Initialize git-lfs if not already done
echo "Initializing Git LFS..."
git lfs install

# Track large file patterns
echo "Configuring Git LFS to track: $LFS_PATTERNS"
for pattern in $LFS_PATTERNS; do
    git lfs track "$pattern"
done

# Check if already a git repo, if not initialize
if [ ! -d ".git" ]; then
    echo "Initializing git repository..."
    git init
fi

# Add all files (LFS files will be tracked automatically)
git add .
git add .gitattributes

# Commit
git commit -m "Update dataset"

# Add or update remote
git remote remove origin 2>/dev/null
git remote add origin "$REMOTE_URL"

# Push to Hugging Face with LFS
echo "Pushing to Hugging Face: $REMOTE_URL"
echo "This may take a while for large datasets..."
git lfs push origin main --all
git push -u origin main

if [ $? -eq 0 ]; then
    echo "✓ Successfully pushed to https://huggingface.co/datasets/$HF_USERNAME/$REPO_NAME"
else
    echo "✗ Push failed. Make sure:"
    echo "  1. You have SSH access to Hugging Face"
    echo "  2. Your SSH key is added to your Hugging Face account"
    echo "  3. The repository exists on Hugging Face"
    exit 1
fi
