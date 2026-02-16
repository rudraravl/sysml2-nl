"""Logging configuration for SysML-NL backend."""

import logging
import sys

# Configure logging format
LOG_FORMAT = "%(asctime)s [%(levelname)s] %(name)s: %(message)s"
DATE_FORMAT = "%Y-%m-%d %H:%M:%S"

# Set up root logger
logging.basicConfig(
    level=logging.INFO,
    format=LOG_FORMAT,
    datefmt=DATE_FORMAT,
    stream=sys.stdout,
)


def get_logger(name: str) -> logging.Logger:
    """Get a logger instance with the specified name."""
    logger = logging.getLogger(name)
    return logger
