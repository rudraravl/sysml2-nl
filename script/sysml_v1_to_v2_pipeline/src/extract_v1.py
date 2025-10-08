from __future__ import annotations
import os, zipfile, io
from lxml import etree
from typing import Optional, List, Dict, Set
from .ir_schema import IR, Block, PartProperty, ValueProperty, Port, Package, Connector, Requirement, Activity

NAMESPACES = {
    "xmi": "http://www.omg.org/spec/XMI/20131001",
    "uml": "http://www.omg.org/spec/UML/20131001",
    "sysml": "http://www.omg.org/spec/SysML/20150709/SysML",
}

def _load_xml(path: str) -> etree._ElementTree:
    if path.endswith(".mdzip"):
        with zipfile.ZipFile(path) as z:
            # Heuristic: pick the biggest .xml inside as the model file
            xml_names = [n for n in z.namelist() if n.lower().endswith(".xml")]
            assert xml_names, "No XML inside mdzip"
            main = max(xml_names, key=lambda n: z.getinfo(n).file_size)
            with z.open(main) as f:
                return etree.parse(io.BytesIO(f.read()))
    else:
        return etree.parse(path)

def extract_to_ir(input_path: str) -> IR:
    """Extract SysML v1 from MagicDraw XMI export to IR.
    Handles the specific format where sysml:Block references uml:Class via base_Class."""
    tree = _load_xml(input_path)
    root = tree.getroot()

    # Build index of all elements by ID
    all_elements: Dict[str, etree._Element] = {}
    for elem in root.iter():
        elem_id = elem.get("{http://www.omg.org/spec/XMI/20131001}id")
        if elem_id:
            all_elements[elem_id] = elem

    # Find all sysml:Block stereotypes and get their base_Class references
    block_class_ids: Set[str] = set()
    for block_elem in root.findall(".//sysml:Block", namespaces=NAMESPACES):
        base_class = block_elem.get("base_Class")
        if base_class:
            block_class_ids.add(base_class)

    print(f"Found {len(block_class_ids)} blocks with sysml:Block stereotype")

    # --- Extract Blocks ---
    blocks: List[Block] = []
    for class_id in block_class_ids:
        if class_id not in all_elements:
            continue
        cls = all_elements[class_id]
        name = cls.get("name") or "Unnamed"
        bid = class_id
        
        # Extract parts (ownedAttribute with type)
        parts: List[PartProperty] = []
        for attr in cls.findall("ownedAttribute", namespaces=NAMESPACES):
            attr_name = attr.get("name")
            attr_type_id = attr.get("type")
            if attr_name and attr_type_id:
                # Resolve type name
                type_name = "Unknown"
                if attr_type_id in all_elements:
                    type_elem = all_elements[attr_type_id]
                    type_name = type_elem.get("name") or attr_type_id
                
                # Check aggregation
                aggregation = attr.get("aggregation", "none")
                parts.append(PartProperty(name=attr_name, type=type_name, aggregation=aggregation))
        
        # Extract value properties (attributes without type or with primitive types)
        value_props: List[ValueProperty] = []
        
        # Extract ports (ownedAttribute with sysml:FlowPort or sysml:ProxyPort stereotype)
        ports: List[Port] = []
        
        blocks.append(Block(id=bid, name=name, parts=parts, valueProperties=value_props, ports=ports))

    print(f"Extracted {len(blocks)} blocks with {sum(len(b.parts) for b in blocks)} total parts")

    # --- Extract Requirements ---
    requirements: List[Requirement] = []
    # Look for sysml:Requirement stereotypes
    for req_elem in root.findall(".//sysml:Requirement", namespaces=NAMESPACES):
        base_class = req_elem.get("base_Class")
        if base_class and base_class in all_elements:
            cls = all_elements[base_class]
            name = cls.get("name") or "Unnamed"
            req_id = req_elem.get("{http://www.omg.org/spec/XMI/20131001}id") or base_class
            
            # Try to find requirement text
            text = ""
            for comment in cls.findall(".//ownedComment", namespaces=NAMESPACES):
                body = comment.get("body")
                if body:
                    text = body
                    break
            
            requirements.append(Requirement(id=req_id, name=name, text=text))

    print(f"Extracted {len(requirements)} requirements")

    # --- Extract Activities ---
    activities: List[Activity] = []
    for activity_elem in root.findall(".//uml:Activity", namespaces=NAMESPACES):
        name = activity_elem.get("name") or "Unnamed"
        activities.append(Activity(name=name, actions=[], flows=[]))

    print(f"Extracted {len(activities)} activities")

    # --- Connectors (placeholder for now) ---
    connectors: List[Connector] = []

    # --- Packages ---
    packages: List[Package] = []
    for pkg in root.findall(".//uml:Package", namespaces=NAMESPACES):
        pkg_id = pkg.get("{http://www.omg.org/spec/XMI/20131001}id")
        pkg_name = pkg.get("name")
        if pkg_id and pkg_name:
            packages.append(Package(id=pkg_id, name=pkg_name))

    print(f"Extracted {len(packages)} packages")

    return IR(
        packages=packages,
        blocks=blocks,
        connectors=connectors,
        requirements=requirements,
        activities=activities,
        interactions=[],
        stereotypes=[]
    )