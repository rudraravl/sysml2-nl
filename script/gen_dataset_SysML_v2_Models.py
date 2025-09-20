#!/usr/bin/env python3
"""
Dataset Generation Script for SysML v2 Models

This script processes SysML v2 model files from the tmp/SysML-v2-Models/models directory
and moves them into the dataset/data structure with proper naming and metadata.

Source: https://github.com/GfSE/SysML-v2-Models.git
"""

import os
import shutil
import json
from pathlib import Path
from datetime import datetime

def find_sysml_files(root_dir: Path):
    """Find all .sysml files recursively in the given directory."""
    sysml_files = []
    for file_path in root_dir.rglob("*.sysml"):
        sysml_files.append(file_path)
    return sorted(sysml_files)

def get_next_id(dataset_dir: Path):
    """Get the next available ID starting from 000001, finding the smallest unused ID."""
    if not dataset_dir.exists():
        return "000001"
    
    # Get all existing IDs
    existing_ids = set()
    for item in dataset_dir.iterdir():
        if item.is_dir() and item.name.isdigit() and len(item.name) == 6:
            existing_ids.add(int(item.name))
    
    # Find the smallest available ID starting from 1
    next_id = 1
    while next_id in existing_ids:
        next_id += 1
    
    return f"{next_id:06d}"

def create_sample_directory(dataset_dir: Path, sample_id: str):
    """Create a sample directory with the given ID."""
    sample_dir = dataset_dir / sample_id
    sample_dir.mkdir(parents=True, exist_ok=True)
    return sample_dir

def create_meta_json(sample_dir: Path, source_file: Path, sample_id: str):
    """Create metadata JSON file for the sample."""
    meta_data = {
        "id": sample_id,
        "source": {
            "file": str(source_file.relative_to(Path.cwd())),
            "original_name": source_file.stem,
            "directory": str(source_file.parent.relative_to(Path.cwd())),
            "provenance": "SysML-v2-Models repository",
            "timestamp": datetime.now().isoformat(),
            "version": "1.0"
        },
        "labels": {
            "domain": "unknown",
            "diagram_kinds": [],
            "difficulty": "easy",
            "quality_tier": "B"
        },
        "license": "CC-BY-4.0",
        "stats": {
            "sysml_lines": 0,
            "text_tokens": 0,
            "language": "en"
        }
    }
    
    meta_file = sample_dir / "meta.json"
    with open(meta_file, 'w', encoding='utf-8') as f:
        json.dump(meta_data, f, indent=2, ensure_ascii=False)
    
    return meta_file

def create_text_file(sample_dir: Path, source_file: Path, sample_id: str):
    """Create a placeholder text file for the sample."""
    text_file = sample_dir / f"{sample_id}.txt"
    
    # Create a basic description based on the source file
    description = f"SysML v2 model: {source_file.stem}\n"
    description += f"Source: {source_file.parent.name}\n"
    description += f"Original file: {source_file.name}\n"
    description += f"Generated: {datetime.now().isoformat()}\n\n"
    description += "This is a placeholder text description. "
    description += "The actual natural language description should be added manually."
    
    with open(text_file, 'w', encoding='utf-8') as f:
        f.write(description)
    
    return text_file

def process_sysml_file(source_file: Path, dataset_dir: Path, sample_id: str):
    """Process a single .sysml file and move it to the dataset structure."""
    print(f"Processing: {source_file}")
    
    # Create sample directory
    sample_dir = create_sample_directory(dataset_dir, sample_id)
    
    # Copy the .sysml file
    target_sysml = sample_dir / f"{sample_id}.sysml"
    shutil.copy2(source_file, target_sysml)
    
    # Create metadata file
    meta_file = create_meta_json(sample_dir, source_file, sample_id)
    
    # Create placeholder text file
    text_file = create_text_file(sample_dir, source_file, sample_id)
    
    print(f"  Created: {sample_dir}")
    print(f"  Files: {target_sysml.name}, {text_file.name}, {meta_file.name}")
    
    return sample_dir

def main():
    """Main function to process all .sysml files."""
    # Define paths
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    source_dir = project_root / "tmp" / "SysML-v2-Models" / "models"
    dataset_dir = project_root / "dataset" / "data"
    
    print(f"Source directory: {source_dir}")
    print(f"Dataset directory: {dataset_dir}")
    
    # Check if source directory exists
    if not source_dir.exists():
        print(f"ERROR: Source directory not found: {source_dir}")
        print("Please ensure the SysML-v2-Models repository is cloned in tmp/")
        return
    
    # Find all .sysml files
    sysml_files = find_sysml_files(source_dir)
    print(f"Found {len(sysml_files)} .sysml files")
    
    if not sysml_files:
        print("No .sysml files found to process")
        return
    
    # Process each file
    processed_count = 0
    for source_file in sysml_files:
        sample_id = get_next_id(dataset_dir)
        try:
            process_sysml_file(source_file, dataset_dir, sample_id)
            processed_count += 1
        except Exception as e:
            print(f"ERROR processing {source_file}: {e}")
            continue
    
    print(f"\nProcessing complete!")
    print(f"Processed {processed_count} files")
    print(f"Next available ID: {get_next_id(dataset_dir)}")

if __name__ == "__main__":
    main()
