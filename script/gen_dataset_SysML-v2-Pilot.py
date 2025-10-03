#!/usr/bin/env python3
"""
Simple script to generate dataset from SysML-v2-Pilot-Implementation.
Fixed range: 000287-000685 (399 samples)
"""

import shutil
import json
from pathlib import Path
from datetime import datetime

# Fixed range for pilot samples (corrected - excluding duplicates)
START_ID = 287
END_ID = 376

def find_sysml_files():
    """Find all .sysml files in the pilot repo, excluding duplicates and directories."""
    source_dir = Path("tmp/SysML-v2-Pilot-Implementation")
    files = []
    for file_path in source_dir.rglob("*.sysml"):
        if file_path.is_file() and not file_path.is_dir():
            # Exclude duplicate folders that are already in official release
            path_str = str(file_path)
            if "sysml/src" in path_str or "sysml.library" in path_str:
                continue
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
        f.write(f"SysML v2 model from pilot implementation (unique content): {source_file.name}")
    
    # Create meta.json
    meta = {
        "id": f"{sample_id:06d}",
        "source_path": str(source_file),
        "split": "pilot",
        "quality": "A",
        "category": "not processed",
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