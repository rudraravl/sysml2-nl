from __future__ import annotations
from pydantic import BaseModel, Field
from typing import List, Optional, Dict

class Package(BaseModel):
    id: str
    name: str
    parent: Optional[str] = None

class PartProperty(BaseModel):
    name: str
    type: str
    aggregation: Optional[str] = "none"  # "composite" for composition

class ValueProperty(BaseModel):
    name: str
    type: str
    constraints: List[str] = Field(default_factory=list)

class Port(BaseModel):
    name: str
    kind: str = "proxy"  # proxy/full
    interface: Optional[str] = None
    direction: Optional[str] = None  # In<>, Out<>, InOut<>

class Connector(BaseModel):
    from_: str = Field(..., alias="from")
    to: str
    items: List[str] = Field(default_factory=list)

class Requirement(BaseModel):
    id: str
    name: str
    text: str = ""
    parent: Optional[str] = None

class Activity(BaseModel):
    name: str
    actions: List[Dict] = Field(default_factory=list)
    flows: List[Dict] = Field(default_factory=list)

class Interaction(BaseModel):
    name: str
    lifelines: List[str] = Field(default_factory=list)
    messages: List[Dict] = Field(default_factory=list)

class Stereotype(BaseModel):
    name: str
    appliesTo: List[str]
    props: Dict[str, str] = Field(default_factory=dict)

class Block(BaseModel):
    id: str
    name: str
    parts: List[PartProperty] = Field(default_factory=list)
    valueProperties: List[ValueProperty] = Field(default_factory=list)
    ports: List[Port] = Field(default_factory=list)

class IR(BaseModel):
    packages: List[Package] = Field(default_factory=list)
    blocks: List[Block] = Field(default_factory=list)
    connectors: List[Connector] = Field(default_factory=list)
    requirements: List[Requirement] = Field(default_factory=list)
    activities: List[Activity] = Field(default_factory=list)
    interactions: List[Interaction] = Field(default_factory=list)
    stereotypes: List[Stereotype] = Field(default_factory=list)
