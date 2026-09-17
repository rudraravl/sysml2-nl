"""Modelica robotics profile."""

__all__ = [
    "Example", "ExampleCorpus", "FMIContainerRunner", "ModelicaPipeline",
    "OpenModelicaRunner", "generate_modelica_moe",
]


def __getattr__(name: str):
    if name in {"Example", "ExampleCorpus"}:
        from .corpus import Example, ExampleCorpus
        return {"Example": Example, "ExampleCorpus": ExampleCorpus}[name]
    if name == "FMIContainerRunner":
        from .fmu_runtime import FMIContainerRunner
        return FMIContainerRunner
    if name == "generate_modelica_moe":
        from .moe import generate_modelica_moe
        return generate_modelica_moe
    if name == "OpenModelicaRunner":
        from .openmodelica import OpenModelicaRunner
        return OpenModelicaRunner
    if name == "ModelicaPipeline":
        from .pipeline import ModelicaPipeline
        return ModelicaPipeline
    raise AttributeError(name)
