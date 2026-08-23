FROM openmodelica/openmodelica:v1.27.0-ompython

RUN python3 -m pip install --no-cache-dir FMPy==0.3.29

COPY simulate_fmu.py /opt/nl2robotics/simulate_fmu.py
COPY controller_fmu.py /opt/nl2robotics/controller_fmu.py
