"""FMI metadata inspection used by export, contracts, and execution."""

from __future__ import annotations

from pathlib import Path
from xml.etree import ElementTree
from zipfile import BadZipFile, ZipFile

from .models import FMUVariable


class FMUInspectionError(ValueError):
    pass


def inspect_fmu(path: Path) -> dict:
    """Read the FMI 2 model description without loading executable code."""
    try:
        with ZipFile(path) as archive:
            xml = archive.read("modelDescription.xml")
    except (BadZipFile, KeyError, OSError) as exc:
        raise FMUInspectionError(f"invalid FMU archive: {exc}") from exc

    try:
        root = ElementTree.fromstring(xml)
    except ElementTree.ParseError as exc:
        raise FMUInspectionError(f"invalid modelDescription.xml: {exc}") from exc

    version = root.attrib.get("fmiVersion", "")
    co_simulation = root.find("CoSimulation")
    model_exchange = root.find("ModelExchange")
    if co_simulation is not None:
        interface_type = "co_simulation"
        interface = co_simulation
    elif model_exchange is not None:
        interface_type = "model_exchange"
        interface = model_exchange
    else:
        raise FMUInspectionError("model description declares no FMI interface")

    variables = []
    model_variables = root.find("ModelVariables")
    if model_variables is not None:
        for scalar in model_variables.findall("ScalarVariable"):
            scalar_type, type_attributes = _scalar_type(scalar)
            try:
                value_reference = int(scalar.attrib["valueReference"])
            except (KeyError, ValueError) as exc:
                raise FMUInspectionError(
                    "ScalarVariable has an invalid valueReference"
                ) from exc
            variables.append(FMUVariable(
                name=scalar.attrib.get("name", ""),
                value_reference=value_reference,
                scalar_type=scalar_type,
                causality=scalar.attrib.get("causality", "local"),
                variability=scalar.attrib.get("variability", "continuous"),
                initial=scalar.attrib.get("initial"),
                unit=type_attributes.get("unit"),
                start=type_attributes.get("start"),
            ))

    return {
        "fmi_version": version,
        "model_name": root.attrib.get("modelName", ""),
        "guid": root.attrib.get("guid", ""),
        "generation_tool": root.attrib.get("generationTool", ""),
        "interface_type": interface_type,
        "model_identifier": interface.attrib.get("modelIdentifier", ""),
        "variables": variables,
    }


def _scalar_type(scalar: ElementTree.Element) -> tuple[str, dict[str, str]]:
    for name in ("Real", "Integer", "Boolean", "String", "Enumeration"):
        child = scalar.find(name)
        if child is not None:
            return name.lower(), child.attrib
    raise FMUInspectionError(
        f"ScalarVariable {scalar.attrib.get('name', '<unnamed>')!r} has no type"
    )
