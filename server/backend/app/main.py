"""
SysML-NL Converter Backend - FastAPI Application
MVP: Returns fixed "hello-sysml" for nl2llm endpoint
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

app = FastAPI(
    title="SysML-NL Converter API",
    description="Convert natural language to SysML",
    version="0.1.0",
)

# CORS middleware (mainly for local development)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class NL2LLMRequest(BaseModel):
    """Request model for nl2llm endpoint"""
    text: str = Field(..., min_length=1, description="Natural language input text")


class NL2LLMResponse(BaseModel):
    """Response model for nl2llm endpoint"""
    result: str = Field(..., description="Converted result")


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}


@app.post("/api/nl2llm", response_model=NL2LLMResponse)
async def nl2llm(request: NL2LLMRequest):
    """
    Convert natural language to LLM format.
    
    MVP: Returns fixed "hello-sysml" for any input.
    """
    if not request.text or not request.text.strip():
        raise HTTPException(status_code=400, detail="Text cannot be empty")
    
    # MVP: Fixed return value
    # TODO: Replace with actual pipeline (Qwen3-Embedding + Qwen3-Instruct / Qwen3-VL)
    return NL2LLMResponse(result="hello-sysml")


@app.get("/api/version")
async def get_version():
    """Get API version information"""
    return {
        "version": "0.1.0",
        "stage": "MVP",
        "description": "SysML-NL Converter"
    }
