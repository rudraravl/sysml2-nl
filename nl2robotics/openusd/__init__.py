"""Portable OpenUSD/UsdPhysics robotics profile."""

__all__ = [
    "OpenUSDExample", "OpenUSDExampleCorpus", "OpenUSDValidation",
    "OpenUSDPipeline", "OpenUSDValidator",
]


def __getattr__(name: str):
    if name in {"OpenUSDExample", "OpenUSDExampleCorpus"}:
        from .corpus import OpenUSDExample, OpenUSDExampleCorpus
        return {
            "OpenUSDExample": OpenUSDExample,
            "OpenUSDExampleCorpus": OpenUSDExampleCorpus,
        }[name]
    if name == "OpenUSDPipeline":
        from .pipeline import OpenUSDPipeline
        return OpenUSDPipeline
    if name in {"OpenUSDValidation", "OpenUSDValidator"}:
        from .validator import OpenUSDValidation, OpenUSDValidator
        return {
            "OpenUSDValidation": OpenUSDValidation,
            "OpenUSDValidator": OpenUSDValidator,
        }[name]
    raise AttributeError(name)
