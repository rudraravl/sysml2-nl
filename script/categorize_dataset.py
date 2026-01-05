#!/usr/bin/env python3
"""
Script to categorize SysML v2 models using Gemini AI.
Categories: Aerospace, Automotive, Electronics, Industrial, Medical, Energy, Unknown
"""

import os
import json
from pathlib import Path
from typing import Dict
from dotenv import load_dotenv
import google.generativeai as genai
from tqdm import tqdm
from concurrent.futures import ThreadPoolExecutor, as_completed

CATEGORIES: Dict[str, str] = {
    "aerospace":   "Aerospace & Space Systems - ESA models, spacecraft, satellites, mission specifications",
    "automotive":  "Automotive & Transportation - Vehicle models, cars, HSUV, turbojet analysis, geometry, mass roll-up, vehicle decomposition, quadcopter, drones",
    "electronics": "Electronics & Sensors - Camera, flashlight, picture-taking systems, signal processing, sensor interfaces",
    "industrial":  "Industrial & Manufacturing Systems - Arrowhead Framework (industrial IoT), flow connections, control structures, manufacturing components",
    "medical":     "Medical & Healthcare - Medical device failure example, cause and effect modeling in healthcare systems",
    "energy":      "Energy & Power Systems - Fuel economy analysis, power distribution, energy efficiency trade-offs",
    "software":    "Software & Information Systems - E-commerce (shopping cart, product/account), business processes, general IT systems, non-physical domains",
    "unknown":     "Unknown - Cannot be clearly categorized into the above domains",
}

CATEGORY_ALIASES = {
    # robust normalization (LLM sometimes returns pretty names)
    "aerospace & space systems": "aerospace",
    "automotive & transportation": "automotive",
    "electronics & sensors": "electronics",
    "industrial & manufacturing systems": "industrial",
    "medical & healthcare": "medical",
    "energy & power systems": "energy",
    "software & information systems": "software",
    "unk": "unknown",
    "unknown": "unknown",
}

PROMPT_TEMPLATE = """You are a careful, terse classifier.

Analyze this SysML v2 model and categorize it into ONE of these domains:

1. aerospace — Aerospace & Space Systems (ESA models, spacecraft, satellites, mission specifications)
2. automotive — Automotive & Transportation (vehicle models, cars, HSUV, turbojet analysis, geometry, mass roll-up, vehicle decomposition, quadcopter, drones)
3. electronics — Electronics & Sensors (camera, flashlight, picture-taking systems, signal processing, sensor interfaces)
4. industrial — Industrial & Manufacturing Systems (Arrowhead Framework/industrial IoT, flow connections, control structures, manufacturing components)
5. medical — Medical & Healthcare (medical device failure example, cause and effect modeling in healthcare systems)
6. energy — Energy & Power Systems (fuel economy analysis, power distribution, energy efficiency trade-offs)
7. software — Software & Information Systems (e-commerce, shopping cart, product/account, business processes, general IT systems, non-physical domains)
8. unknown — Cannot be clearly categorized into the above domains

Return ONLY the slug: aerospace | automotive | electronics | industrial | medical | energy | software | unknown

SysML v2 model (textual syntax):
{content}"""

PARALLEL = 10
START_ID = 1
END_ID = 1935

def categorize_sample(sample_id: str, dataset_dir: Path):
    sample_dir = dataset_dir / sample_id
    sysml_file = sample_dir / f"{sample_id}.sysml"
    meta_file = sample_dir / "meta.json"
    
    if not sysml_file.exists() or not meta_file.exists():
        return "missing", sample_id, None
    
    # Check current category
    try:
        with open(meta_file, 'r', encoding='utf-8') as f:
            meta_data = json.load(f)
        current_category = meta_data.get('category', 'not processed')
    except Exception:
        meta_data = {}
        current_category = 'not processed'
    
    # Only process if category is not processed or unknown or empty
    if current_category not in ['not processed', 'unknown', '']:
        return "skipped", sample_id, current_category
    
    # Read SysML content
    with open(sysml_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Get AI categorization
    model = genai.GenerativeModel('gemini-2.5-pro')
    response = model.generate_content(PROMPT_TEMPLATE.format(content=content))
    category = response.text.strip().lower()
    
    # Normalize category using aliases
    category = CATEGORY_ALIASES.get(category, category)
    
    # Validate category
    if category not in CATEGORIES:
        category = "unknown"
    
    # Update meta.json
    meta_data['category'] = category
    with open(meta_file, 'w', encoding='utf-8') as f:
        json.dump(meta_data, f, indent=2)
    
    return "done", sample_id, category

def main():
    load_dotenv(Path(__file__).parent.parent / ".env")
    genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
    
    dataset_dir = Path(__file__).parent.parent / "dataset" / "data"
    
    print(f"Processing samples {START_ID} to {END_ID}")
    
    categorized = 0
    errors = 0
    
    futures = []
    with ThreadPoolExecutor(max_workers=PARALLEL) as executor:
        for i in range(START_ID, END_ID + 1):
            sample_id = f"{i:06d}"
            futures.append(executor.submit(categorize_sample, sample_id, dataset_dir))
        
        for future in tqdm(as_completed(futures), total=len(futures), desc="Categorizing"):
            try:
                status, sample_id, category = future.result()
                if status == "done":
                    print(f"Sample {sample_id}: {category}")
                    categorized += 1
                elif status == "skipped":
                    print(f"Skipping {sample_id} - already categorized as '{category}'")
                elif status == "missing":
                    print(f"Warning: Missing files for sample {sample_id}")
            except Exception as e:
                print(f"Error processing sample: {e}")
                errors += 1
    
    print(f"\nCategorization complete!")
    print(f"Successfully categorized: {categorized}")
    print(f"Errors: {errors}")
    
    # Show category distribution
    print(f"\nCategory distribution:")
    category_counts = {}
    for i in range(START_ID, END_ID + 1):
        sample_id = f"{i:06d}"
        meta_file = dataset_dir / sample_id / "meta.json"
        if meta_file.exists():
            with open(meta_file, 'r', encoding='utf-8') as f:
                meta_data = json.load(f)
            cat = meta_data.get('category', 'unknown')
            category_counts[cat] = category_counts.get(cat, 0) + 1
    
    for cat, count in sorted(category_counts.items()):
        print(f"  {cat}: {count}")

if __name__ == "__main__":
    main()
