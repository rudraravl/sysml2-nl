FROM python:3.11-slim

RUN python3 -m pip install --no-cache-dir usd-core==26.8

COPY validate_stage.py /opt/nl2robotics/validate_stage.py
COPY author_playback.py /opt/nl2robotics/author_playback.py
COPY inspect_playback.py /opt/nl2robotics/inspect_playback.py
