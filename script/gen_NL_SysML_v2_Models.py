#!/usr/bin/env python3
import os, json
from pathlib import Path
from dotenv import load_dotenv
import google.generativeai as genai
from tqdm import tqdm
from concurrent.futures import ThreadPoolExecutor, as_completed

PROMPT = """
Describe the actual system or object that this SysML v2 model represents. Focus on what the real-world system is, what it does, and how its components work together - not on the code or modeling structure.

Good example style:
"This is a forest fire observation drone system designed for aerial surveillance and monitoring. The drone features a modular architecture with a main body that can accommodate different engine configurations, typically using four or six engines for propulsion. The system includes a comprehensive power management system with rechargeable batteries, a flight control unit for autonomous operation, and an extensive sensor suite including GPS for navigation, IMU for orientation, barometer for altitude control, and cameras for visual monitoring. The drone operates through different states including parking for charging, standby for preparation, and active flying for mission execution. It's designed to be reusable and configurable for different mission requirements."

Write in this natural style - describe the actual system, not the code. Focus on what the system is and does in the real world.

SysML v2 Model:
{content}

Description:
"""

PARALLEL = 10

START_ID = 387
END_ID = 1936

def generate_for_id(i):
    id = f"{i:06d}"
    dir = Path(__file__).parent.parent / "dataset" / "data" / id
    if not dir.exists():
        return "missing", id
    
    sysml = dir / f"{id}.sysml"
    txt = dir / f"{id}.txt"
    meta = dir / "meta.json"
    
    # Skip if txt file already exists
    if txt.exists():
        return "skipped", id
    
    with open(sysml) as f:
        content = f.read()
    model = genai.GenerativeModel('gemini-2.5-pro')
    response = model.generate_content(PROMPT.format(content=content))
    
    with open(txt, 'w') as f:
        f.write(response.text)
    
    # Read meta.json to get metadata (but don't modify it)
    with open(meta) as f:
        json.load(f)
    
    return "done", id

def main():
    load_dotenv(Path(__file__).parent.parent / ".env")
    genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
    # model = genai.GenerativeModel('gemini-2.5-flash')
    with ThreadPoolExecutor(max_workers=PARALLEL) as executor:
        futures = [executor.submit(generate_for_id, i) for i in range(START_ID, END_ID)]
        for future in tqdm(as_completed(futures), total=len(futures), desc="Processing"):
            status, id = future.result()
            if status == "skipped":
                print(f"Skipping {id} - txt file already exists")

if __name__ == "__main__":
    main()
