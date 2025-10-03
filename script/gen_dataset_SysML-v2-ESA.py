#!/usr/bin/env python3
"""
Simple script to generate dataset from SysML-v2 ESA and ESA_Comet files.
Fixed range: 000377-000386 (10 samples)
"""

import shutil
import json
from pathlib import Path
from datetime import datetime

# Fixed range for ESA samples (after pilot samples)
START_ID = 377
END_ID = 386

def find_sysml_files():
    """Find all .sysml files in the ESA and ESA_Comet directories."""
    esa_dir = Path("tmp/sysmlv2/language/src/test/resources/esa")
    esa_comet_dir = Path("tmp/sysmlv2/language/src/test/resources/esa_comet")
    
    files = []
    
    # Add ESA files
    if esa_dir.exists():
        for file_path in esa_dir.rglob("*.sysml"):
            if file_path.is_file():
                files.append(file_path)
    
    # Add ESA_Comet files
    if esa_comet_dir.exists():
        for file_path in esa_comet_dir.rglob("*.sysml"):
            if file_path.is_file():
                files.append(file_path)
    
    return sorted(files)

def create_sample(sample_id, source_file):
    """Create one sample directory and copy files."""
    sample_dir = Path(f"dataset/data/{sample_id:06d}")
    sample_dir.mkdir(parents=True, exist_ok=True)
    
    # Copy .sysml file
    shutil.copy2(source_file, sample_dir / f"{sample_id:06d}.sysml")
    
    # Create .txt file
    with open(sample_dir / f"{sample_id:06d}.txt", 'w') as f:
        f.write(f"SysML v2 model from ESA/ESA_Comet: {source_file.name}")
    
    # Create meta.json
    meta = {
        "id": f"{sample_id:06d}",
        "provenance": "ESA/ESA_Comet SysML v2 models",
        "split": "esa",
        "quality_tier": "A",
        "labels": {
            "domain": "aerospace",
            "difficulty": "advanced",
            "diagram_kinds": ["textual"]
        },
        "created": datetime.now().isoformat()
    }
    
    with open(sample_dir / "meta.json", 'w') as f:
        json.dump(meta, f, indent=2)
    
    return sample_dir

def main():
    """Main function - simple and stupid."""
    print("Finding .sysml files...")
    files = find_sysml_files()
    print(f"Found {len(files)} files")
    
    if len(files) > (END_ID - START_ID + 1):
        print(f"ERROR: Too many files ({len(files)}) for range {START_ID:06d}-{END_ID:06d}")
        return
    
    print(f"Processing files {START_ID:06d}-{END_ID:06d}...")
    
    for i, source_file in enumerate(files):
        sample_id = START_ID + i
        sample_dir = create_sample(sample_id, source_file)
        print(f"  {source_file.name} -> {sample_id:06d}")
    
    print(f"Done! Created {len(files)} samples")

if __name__ == "__main__":
    main()
