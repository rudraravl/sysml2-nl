import subprocess
import os


def translate_dataset_to_json(dataset_id):
    """Translate a single dataset to JSON format using pysysml2 CLI"""
    dataset_path = f"../dataset/data/{dataset_id:06d}/{dataset_id:06d}.sysml"
    output_dir = f"../dataset/data/{dataset_id:06d}/"
    
    if not os.path.exists(dataset_path):
        print(f"Warning: {dataset_path} not found")
        return False
    
    try:
        # Use pysysml2 CLI to export to JSON
        cmd = [
            "pysysml2", "export", dataset_path,
            "--output-dir", output_dir,
            "--format", "json"
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            print(f"Successfully translated {dataset_id:06d}.sysml to JSON")
            print(result.stdout)
            return True
        else:
            print(f"Error translating {dataset_id:06d}: {result.stderr}")
            return False
            
    except Exception as e:
        print(f"Error translating {dataset_id:06d}: {e}")
        return False


# Translate datasets 1-5
for i in range(1, 6):
    translate_dataset_to_json(i)
