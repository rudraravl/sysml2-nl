#!/usr/bin/env python3
import os, json
from pathlib import Path
from dotenv import load_dotenv
import google.generativeai as genai
from tqdm import tqdm

PROMPT = """
Describe the actual system or object that this SysML v2 model represents. Focus on what the real-world system is, what it does, and how its components work together - not on the code or modeling structure.

Good example style:
"This is a forest fire observation drone system designed for aerial surveillance and monitoring. The drone features a modular architecture with a main body that can accommodate different engine configurations, typically using four or six engines for propulsion. The system includes a comprehensive power management system with rechargeable batteries, a flight control unit for autonomous operation, and an extensive sensor suite including GPS for navigation, IMU for orientation, barometer for altitude control, and cameras for visual monitoring. The drone operates through different states including parking for charging, standby for preparation, and active flying for mission execution. It's designed to be reusable and configurable for different mission requirements."

Write in this natural style - describe the actual system, not the code. Focus on what the system is and does in the real world.

SysML v2 Model:
{content}

Description:
"""

def main():
    load_dotenv(Path(__file__).parent.parent / ".env")
    genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
    # model = genai.GenerativeModel('gemini-2.5-flash')
    model = genai.GenerativeModel('gemini-2.5-pro')
    
    for i in tqdm(range(1, 10), desc="Processing"):
        id = f"{i:06d}"
        dir = Path(__file__).parent.parent / "dataset" / "data" / id
        if not dir.exists(): 
            continue
        
        sysml = dir / f"{id}.sysml"
        txt = dir / f"{id}.txt"
        meta = dir / "meta.json"
        
        with open(sysml) as f: 
            content = f.read()
        response = model.generate_content(PROMPT.format(content=content))
        
        with open(txt, 'w') as f: 
            f.write(response.text)
        
        # Read meta.json to get metadata (but don't modify it)
        with open(meta) as f: 
            data = json.load(f)

        # TODO: Modify the data['category']

if __name__ == "__main__":
    main()
