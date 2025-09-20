#!/usr/bin/env python3
import os, json
from pathlib import Path
from dotenv import load_dotenv
import google.generativeai as genai
from tqdm import tqdm

def main():
    load_dotenv(Path(__file__).parent.parent / ".env")
    genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
    model = genai.GenerativeModel('gemini-1.5-flash')
    
    for i in tqdm(range(1, 37), desc="Processing"):
        id = f"{i:06d}"
        dir = Path(__file__).parent.parent / "dataset" / "data" / id
        if not dir.exists(): continue
        
        sysml = dir / f"{id}.sysml"
        txt = dir / f"{id}.txt"
        meta = dir / "meta.json"
        
        with open(sysml) as f: content = f.read()
        response = model.generate_content(f"Describe this SysML v2 model in natural language:\n\n{content}")
        
        with open(txt, 'w') as f: f.write(response.text)
        
        with open(meta) as f: data = json.load(f)
        data['stats']['text_tokens'] = len(response.text.split())
        with open(meta, 'w') as f: json.dump(data, f, indent=2)

if __name__ == "__main__":
    main()
