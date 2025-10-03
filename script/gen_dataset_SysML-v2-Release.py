#!/usr/bin/env python3
"""
Generate dataset entries from SysML-v2-Release repository.

This script processes .sysml files from the SysML-v2-Release repository
and creates corresponding dataset entries with metadata.
"""

import os
import json
import shutil
from pathlib import Path
from datetime import datetime
from typing import List, Tuple, Dict, Any

# Configuration
SOURCE_DIR = Path("/Users/creatix/Documents/sysml2-nl/tmp/SysML-v2-Release/sysml")
DATASET_DIR = Path("/Users/creatix/Documents/sysml2-nl/dataset/data")
START_ID = 1  # Start from 000001 since these are the most important

def find_sysml_files() -> List[Path]:
    """Find all .sysml files in the source directory (excluding sysml.library)."""
    sysml_files = []
    
    # Only process the sysml/src directory, not sysml.library
    src_dir = SOURCE_DIR / "src"
    if src_dir.exists():
        for file_path in src_dir.rglob("*.sysml"):
            sysml_files.append(file_path)
    
    return sorted(sysml_files)

def infer_domain_and_difficulty(file_path: Path) -> Tuple[str, str, List[str]]:
    """Infer domain, difficulty, and diagram kinds from file path."""
    path_str = str(file_path.relative_to(SOURCE_DIR / "src"))
    
    # Infer domain based on directory structure
    if "examples" in path_str:
        if "Analysis" in path_str:
            domain = "analysis"
        elif "Vehicle" in path_str or "Car" in path_str:
            domain = "automotive"
        elif "Camera" in path_str or "Flashlight" in path_str:
            domain = "consumer_electronics"
        elif "Room" in path_str:
            domain = "building_systems"
        elif "Packet" in path_str or "Server" in path_str:
            domain = "software_systems"
        elif "Medical" in path_str:
            domain = "medical_devices"
        elif "Arrowhead" in path_str:
            domain = "industrial_iot"
        else:
            domain = "general_systems"
    elif "training" in path_str:
        domain = "education"
    elif "validation" in path_str:
        domain = "testing"
    else:
        domain = "general_systems"
    
    # Infer difficulty based on directory structure
    if "training" in path_str:
        difficulty = "beginner"
    elif "validation" in path_str:
        difficulty = "advanced"
    elif "examples" in path_str:
        if "Simple" in path_str or "Basic" in path_str:
            difficulty = "beginner"
        elif "Complex" in path_str or "Advanced" in path_str:
            difficulty = "advanced"
        else:
            difficulty = "intermediate"
    else:
        difficulty = "intermediate"
    
    # Infer diagram kinds based on file content and path
    diagram_kinds = []
    
    # Read a portion of the file to infer diagram types
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read(2000)  # Read first 2000 characters
        
        if "part def" in content or "block def" in content:
            diagram_kinds.append("bdd")
        if "state def" in content or "state" in content:
            diagram_kinds.append("stm")
        if "action def" in content or "perform" in content:
            diagram_kinds.append("act")
        if "ibd" in content or "internal" in content:
            diagram_kinds.append("ibd")
        if "req def" in content or "requirement" in content:
            diagram_kinds.append("req")
        if "use case" in content or "usecase" in content:
            diagram_kinds.append("uc")
        if "analysis" in content.lower():
            diagram_kinds.append("analysis")
        if "verification" in content.lower():
            diagram_kinds.append("verification")
    except Exception:
        pass
    
    # If no diagram kinds inferred, add default
    if not diagram_kinds:
        diagram_kinds = ["bdd"]  # Default to block definition diagram
    
    return domain, difficulty, diagram_kinds

def create_sample_directory(sample_id: str) -> Path:
    """Create directory for a sample."""
    sample_dir = DATASET_DIR / sample_id
    sample_dir.mkdir(parents=True, exist_ok=True)
    return sample_dir

def copy_sysml_file(source_file: Path, sample_dir: Path, sample_id: str) -> Path:
    """Copy .sysml file to sample directory."""
    dest_file = sample_dir / f"{sample_id}.sysml"
    shutil.copy2(source_file, dest_file)
    return dest_file

def create_text_file(sample_dir: Path, sample_id: str, source_file: Path) -> Path:
    """Create placeholder text file."""
    text_file = sample_dir / f"{sample_id}.txt"
    
    # Generate a basic description based on the file name and path
    file_name = source_file.stem
    relative_path = source_file.relative_to(SOURCE_DIR / "src")
    
    description = f"SysML v2 model: {file_name}\n"
    description += f"Source: {relative_path}\n"
    description += f"Category: Official SysML v2 Release Examples\n\n"
    description += "This is a SysML v2 textual model from the official OMG SysML v2 Release repository. "
    description += "The model demonstrates various SysML v2 language features and capabilities.\n\n"
    description += "TODO: Add detailed natural language description of this model."
    
    with open(text_file, 'w', encoding='utf-8') as f:
        f.write(description)
    
    return text_file

def create_meta_json(sample_dir: Path, source_file: Path, sample_id: str, sysml_lines: int, domain: str, difficulty: str, diagram_kinds: list):
    """Create metadata JSON file for the sample."""
    meta_data = {
        "id": sample_id,
        "source": {
            "file": str(source_file.relative_to(Path.cwd())),
            "original_name": source_file.stem,
            "directory": str(source_file.parent.relative_to(Path.cwd())),
            "provenance": "OMG SysML v2 Official Release",
            "timestamp": datetime.now().isoformat(),
            "version": "1.0"
        },
        "labels": {
            "domain": domain,
            "diagram_kinds": diagram_kinds,
            "difficulty": difficulty,
            "quality_tier": "A+",  # Official release is highest quality
            "split": "official"
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

def process_sysml_file(source_file: Path, sample_id: str) -> Dict[str, Any]:
    """Process a single .sysml file and create dataset entry."""
    print(f"Processing {source_file.name} -> {sample_id}")
    
    # Count lines in source file
    with open(source_file, 'r', encoding='utf-8') as f:
        sysml_lines = sum(1 for _ in f)
    
    # Infer metadata
    domain, difficulty, diagram_kinds = infer_domain_and_difficulty(source_file)
    
    # Create sample directory
    sample_dir = create_sample_directory(sample_id)
    
    # Copy .sysml file
    dest_sysml = copy_sysml_file(source_file, sample_dir, sample_id)
    
    # Create text file
    text_file = create_text_file(sample_dir, sample_id, source_file)
    
    # Create metadata
    meta_file = create_meta_json(sample_dir, source_file, sample_id, sysml_lines, domain, difficulty, diagram_kinds)
    
    return {
        "sample_id": sample_id,
        "source_file": source_file,
        "sysml_lines": sysml_lines,
        "domain": domain,
        "difficulty": difficulty,
        "diagram_kinds": diagram_kinds
    }

def main():
    """Main function to process all .sysml files."""
    print("SysML-v2-Release Dataset Generator")
    print("=" * 50)
    
    # Check if source directory exists
    if not SOURCE_DIR.exists():
        print(f"Error: Source directory not found: {SOURCE_DIR}")
        return
    
    # Find all .sysml files
    sysml_files = find_sysml_files()
    print(f"Found {len(sysml_files)} .sysml files")
    
    if not sysml_files:
        print("No .sysml files found!")
        return
    
    # Process each file
    results = []
    for i, source_file in enumerate(sysml_files):
        sample_id = f"{START_ID + i:06d}"
        try:
            result = process_sysml_file(source_file, sample_id)
            results.append(result)
        except Exception as e:
            print(f"Error processing {source_file}: {e}")
            continue
    
    # Print summary
    print("\n" + "=" * 50)
    print("PROCESSING COMPLETE")
    print("=" * 50)
    print(f"Successfully processed: {len(results)} files")
    
    # Print domain distribution
    domain_counts = {}
    difficulty_counts = {}
    for result in results:
        domain = result["domain"]
        difficulty = result["difficulty"]
        domain_counts[domain] = domain_counts.get(domain, 0) + 1
        difficulty_counts[difficulty] = difficulty_counts.get(difficulty, 0) + 1
    
    print(f"\nDomain distribution:")
    for domain, count in sorted(domain_counts.items()):
        print(f"  {domain}: {count}")
    
    print(f"\nDifficulty distribution:")
    for difficulty, count in sorted(difficulty_counts.items()):
        print(f"  {difficulty}: {count}")
    
    print(f"\nSample IDs: {START_ID:06d} - {START_ID + len(results) - 1:06d}")

if __name__ == "__main__":
    main()
