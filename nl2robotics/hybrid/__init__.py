"""Portable and simulator-backed robotics hybrid execution."""

__all__ = ["ClosedLoopMaster", "OpenUSDPlaybackRunner", "PortableHybridPipeline"]


def __getattr__(name: str):
    if name == "ClosedLoopMaster":
        from .closed_loop import ClosedLoopMaster
        return ClosedLoopMaster
    if name == "OpenUSDPlaybackRunner":
        from .playback import OpenUSDPlaybackRunner
        return OpenUSDPlaybackRunner
    if name == "PortableHybridPipeline":
        from .portable import PortableHybridPipeline
        return PortableHybridPipeline
    raise AttributeError(name)
