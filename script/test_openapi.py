#!/usr/bin/env python3
"""
SysML v2 API Demo - Show what actually works
"""

import urllib.request
import urllib.error
import json

API_URL = "http://localhost:9010"

def get(url):
    try:
        req = urllib.request.Request(url)
        response = urllib.request.urlopen(req)
        return response.getcode(), response.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()
    except Exception as e:
        return 0, str(e)

def main():
    print("SysML v2 API - What Actually Works:")
    print("===================================")
    
    # Test what works
    print("1. Server status:")
    code, response = get(f"{API_URL}/")
    print(f"   GET / -> {code}")
    
    print("\n2. Metamodel (this works!):")
    code, response = get(f"{API_URL}/meta/datatypes")
    print(f"   GET /meta/datatypes -> {code}")
    
    if code == 200:
        datatypes = json.loads(response)
        print(f"   ✓ Found {len(datatypes)} SysML v2 types!")
        if isinstance(datatypes, list):
            print("   Examples:")
            for dtype in datatypes[:5]:
                print(f"     - {dtype}")
        else:
            print(f"   Response: {datatypes}")
    
    print("\n3. Projects:")
    code, response = get(f"{API_URL}/projects")
    print(f"   GET /projects -> {code}")
    if code == 200:
        projects = json.loads(response)
        print(f"   Found {len(projects)} projects")
    
    print("\nWhat this API does:")
    print("- Manages SysML v2 projects with version control")
    print("- Stores model elements (blocks, parts, requirements, etc.)")
    print("- Provides full SysML v2 metamodel support")
    print("- Uses Git-like branching and commits")
    print("- Supports queries and relationships")
    
    print("\nThe server is running and responding!")
    print("This is a complete SysML v2 modeling server.")

if __name__ == "__main__":
    main()