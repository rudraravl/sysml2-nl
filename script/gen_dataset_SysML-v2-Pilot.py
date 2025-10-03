#!/usr/bin/env python3
"""
Dataset Generation Script for SysML v2 Pilot Implementation

This script processes SysML v2 model files from the tmp/SysML-v2-Pilot-Implementation directory
and moves them into the dataset/data structure with proper naming and metadata.

Source: https://github.com/Systems-Modeling/SysML-v2-Pilot-Implementation.git
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
        # Only include actual files, not directories
        if file_path.is_file():
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

def categorize_file(source_file: Path):
    """Categorize the file based on its path to determine domain and difficulty."""
    path_str = str(source_file)
    
    # Determine domain based on path
    if "training" in path_str:
        domain = "training"
        difficulty = "easy"
    elif "examples" in path_str:
        domain = "examples"
        difficulty = "medium"
    elif "validation" in path_str:
        domain = "validation"
        difficulty = "hard"
    elif "library" in path_str:
        domain = "library"
        difficulty = "easy"
    elif "quantities" in path_str or "units" in path_str:
        domain = "quantities"
        difficulty = "easy"
    elif "vehicle" in path_str.lower():
        domain = "automotive"
        difficulty = "medium"
    elif "camera" in path_str.lower():
        domain = "imaging"
        difficulty = "medium"
    elif "analysis" in path_str.lower():
        domain = "analysis"
        difficulty = "hard"
    else:
        domain = "general"
        difficulty = "medium"
    
    # Determine diagram kinds based on filename
    diagram_kinds = []
    filename = source_file.stem.lower()
    
    if "state" in filename or "statemachine" in filename:
        diagram_kinds.append("state_machine")
    if "activity" in filename or "action" in filename:
        diagram_kinds.append("activity")
    if "requirement" in filename:
        diagram_kinds.append("requirement")
    if "analysis" in filename:
        diagram_kinds.append("analysis")
    if "allocation" in filename:
        diagram_kinds.append("allocation")
    if "constraint" in filename:
        diagram_kinds.append("constraint")
    if "use" in filename and "case" in filename:
        diagram_kinds.append("use_case")
    if "sequence" in filename:
        diagram_kinds.append("sequence")
    if "package" in filename:
        diagram_kinds.append("package")
    if "part" in filename:
        diagram_kinds.append("block_definition")
    
    return domain, difficulty, diagram_kinds

def create_meta_json(sample_dir: Path, source_file: Path, sample_id: str):
    """Create metadata JSON file for the sample."""
    domain, difficulty, diagram_kinds = categorize_file(source_file)
    
    # Count lines in the SysML file
    sysml_lines = 0
    try:
        with open(source_file, 'r', encoding='utf-8') as f:
            sysml_lines = len(f.readlines())
    except:
        sysml_lines = 0
    
    meta_data = {
        "id": sample_id,
        "source": {
            "file": str(source_file.relative_to(Path.cwd())),
            "original_name": source_file.stem,
            "directory": str(source_file.parent.relative_to(Path.cwd())),
            "provenance": "SysML-v2-Pilot-Implementation repository",
            "timestamp": datetime.now().isoformat(),
            "version": "1.0"
        },
        "labels": {
            "domain": domain,
            "diagram_kinds": diagram_kinds,
            "difficulty": difficulty,
            "quality_tier": "A",  # Pilot implementation is high quality
            "split": "pilot"
        },
        "license": "CC-BY-4.0",
        "stats": {
            "sysml_lines": sysml_lines,
            "text_tokens": 0,  # Will be updated when text is added
            "language": "en"
        }
    }
    
    meta_file = sample_dir / "meta.json"
    with open(meta_file, 'w', encoding='utf-8') as f:
        json.dump(meta_data, f, indent=2, ensure_ascii=False)
    
    return meta_file

def create_text_file(sample_dir: Path, source_file: Path, sample_id: str):
    """Create a descriptive text file for the sample based on its content and path."""
    text_file = sample_dir / f"{sample_id}.txt"
    
    # Generate description based on file path and content
    path_parts = source_file.parts
    domain, difficulty, diagram_kinds = categorize_file(source_file)
    
    # Read first few lines to understand content
    try:
        with open(source_file, 'r', encoding='utf-8') as f:
            first_lines = [f.readline().strip() for _ in range(5)]
    except:
        first_lines = []
    
    # Generate description
    description_parts = []
    
    # Add context based on path
    if "training" in str(source_file):
        description_parts.append("This is a training example from the SysML v2 Pilot Implementation.")
        description_parts.append("It demonstrates fundamental SysML v2 concepts and syntax.")
    elif "examples" in str(source_file):
        description_parts.append("This is an example model from the SysML v2 Pilot Implementation.")
        description_parts.append("It showcases practical applications of SysML v2 modeling.")
    elif "validation" in str(source_file):
        description_parts.append("This is a validation test case from the SysML v2 Pilot Implementation.")
        description_parts.append("It ensures compliance with the SysML v2 specification.")
    elif "library" in str(source_file):
        description_parts.append("This is a library component from the SysML v2 Pilot Implementation.")
        description_parts.append("It provides reusable SysML v2 constructs and definitions.")
    else:
        description_parts.append("This is a SysML v2 model from the Pilot Implementation repository.")
    
    # Add domain-specific information
    if domain == "automotive":
        description_parts.append("The model focuses on automotive systems and vehicle modeling.")
    elif domain == "imaging":
        description_parts.append("The model deals with imaging systems and camera functionality.")
    elif domain == "analysis":
        description_parts.append("The model demonstrates analysis and simulation capabilities.")
    elif domain == "quantities":
        description_parts.append("The model defines quantities, units, and measurement systems.")
    
    # Add diagram type information
    if diagram_kinds:
        diagram_desc = ", ".join(diagram_kinds).replace("_", " ")
        description_parts.append(f"It includes {diagram_desc} diagrams.")
    
    # Add file structure information
    if len(path_parts) > 3:
        category = path_parts[-2] if len(path_parts) > 1 else "general"
        description_parts.append(f"Category: {category}")
    
    # Add difficulty information
    difficulty_desc = {
        "easy": "suitable for beginners",
        "medium": "intermediate complexity", 
        "hard": "advanced concepts"
    }
    description_parts.append(f"Complexity: {difficulty_desc.get(difficulty, 'unknown')}")
    
    # Add source information
    description_parts.append(f"Source file: {source_file.name}")
    description_parts.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Combine all parts
    description = "\n\n".join(description_parts)
    
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
    
    # Create descriptive text file
    text_file = create_text_file(sample_dir, source_file, sample_id)
    
    print(f"  Created: {sample_dir}")
    print(f"  Files: {target_sysml.name}, {text_file.name}, {meta_file.name}")
    
    return sample_dir

def main():
    """Main function to process all .sysml files."""
    # Define paths
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    source_dir = project_root / "tmp" / "SysML-v2-Pilot-Implementation"
    dataset_dir = project_root / "dataset" / "data"
    
    print(f"Source directory: {source_dir}")
    print(f"Dataset directory: {dataset_dir}")
    
    # Check if source directory exists
    if not source_dir.exists():
        print(f"ERROR: Source directory not found: {source_dir}")
        print("Please ensure the SysML-v2-Pilot-Implementation repository is cloned in tmp/")
        return
    
    # Find all .sysml files
    sysml_files = find_sysml_files(source_dir)
    print(f"Found {len(sysml_files)} .sysml files")
    
    if not sysml_files:
        print("No .sysml files found to process")
        return
    
    # Show file distribution
    print("\nFile distribution by category:")
    categories = {}
    for file_path in sysml_files:
        domain, _, _ = categorize_file(file_path)
        categories[domain] = categories.get(domain, 0) + 1
    
    for domain, count in sorted(categories.items()):
        print(f"  {domain}: {count} files")
    
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
