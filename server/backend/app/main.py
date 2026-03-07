"""
SysML-NL Converter Backend - FastAPI Application
Supports multiple pipelines: kalm, qwen, llama
With load-on-demand model management and idle unload.
"""

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import router
from app.api.sysml_composer_routes import router as sysml_composer_router
from app.runtime.lifecycle import start_background_tasks, stop_background_tasks
from app.core.logging import get_logger

log = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage startup and shutdown."""
    log.info("Starting SysML-NL backend")
    await start_background_tasks(app)
    yield
    log.info("Shutting down SysML-NL backend")
    await stop_background_tasks(app)


app = FastAPI(
    title="SysML-NL Converter API",
    description="Convert natural language to SysML v2",
    version="0.2.0",
    lifespan=lifespan,
)

# CORS middleware (for local development, Nginx handles same-origin in prod)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routes
app.include_router(router)
app.include_router(sysml_composer_router)
