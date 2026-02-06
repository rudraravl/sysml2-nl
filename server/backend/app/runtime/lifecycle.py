"""Lifecycle management: background tasks for idle reaper."""

import asyncio
from fastapi import FastAPI

from app.runtime.resources import model_manager
from app.core.logging import get_logger

log = get_logger(__name__)

REAPER_INTERVAL = 30  # seconds


async def idle_reaper():
    """Background task that periodically unloads idle models."""
    log.info("Idle reaper started")
    while True:
        try:
            await asyncio.sleep(REAPER_INTERVAL)
            unloaded = await model_manager.unload_if_idle()
            if unloaded:
                log.info(f"Idle reaper unloaded: {unloaded}")
        except asyncio.CancelledError:
            log.info("Idle reaper cancelled")
            break
        except Exception as e:
            log.error(f"Idle reaper error: {e}")


async def start_background_tasks(app: FastAPI):
    """Start background tasks on app startup."""
    task = asyncio.create_task(idle_reaper())
    app.state.idle_reaper_task = task
    log.info("Background tasks started")


async def stop_background_tasks(app: FastAPI):
    """Stop background tasks on app shutdown."""
    if hasattr(app.state, "idle_reaper_task"):
        app.state.idle_reaper_task.cancel()
        try:
            await app.state.idle_reaper_task
        except asyncio.CancelledError:
            pass
    await model_manager.unload_all()
    log.info("Background tasks stopped, models unloaded")
