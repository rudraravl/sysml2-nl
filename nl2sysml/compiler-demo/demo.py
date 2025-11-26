import requests
import os

COMPILER_API_URL = "http://localhost:9000/api/validate" 

def compile(file_path: str) -> str:
    if not os.path.exists(file_path):
        return f"Error: File not found at {file_path}"

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            source_code = f.read()
        payload = {"code": source_code}
        response = requests.post(COMPILER_API_URL, json=payload)
        return response.text

    except Exception as e:
        return f"System Error: {str(e)}"

if __name__ == "__main__":
    test_file = "test.sysml"
    raw_output = compile(test_file)
    print(raw_output)