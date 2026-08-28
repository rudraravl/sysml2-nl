package NetRadiometerSystem {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;

    unit Volt;
    unit Kelvin;
    unit WattPerSquareMeter;
    unit Second;

    attribute def Voltage :> Real { unit = Volt; }
    attribute def Temperature :> Real { unit = Kelvin; }
    attribute def Irradiance :> Real { unit = WattPerSquareMeter; }
    attribute def TimeStamp :> Real { unit = Second; }

    item def RawSignal {
        attribute voltage : Voltage;
        attribute temp : Temperature;
    }

    item def ProcessedData {
        attribute downwardIrradiance : Irradiance;
        attribute upwardIrradiance : Irradiance;
        attribute netRadiation : Irradiance;
        attribute sensorTemp : Temperature;
        attribute timestamp : TimeStamp;
    }

    port def RawSignalOutPort {
        out rawSignal : RawSignal;
    }

    port def RawSignalInPort {
        in rawSignal : RawSignal;
    }

    port def ProcessedDataOutPort {
        out data : ProcessedData;
    }

    port def ProcessedDataInPort {
        in data : ProcessedData;
    }

    port def PowerInPort {
        in power : Voltage;
    }

    port def PowerOutPort {
        out power : Voltage;
    }

    part def Pyrgeometer {
        attribute calibrationFactor : Real;
        port rawOut : RawSignalOutPort;
        port pwrIn : PowerInPort;
    }

    part def SignalProcessor {
        attribute downwardCalFactor : Real;
        attribute upwardCalFactor : Real;
        
        port downwardIn : RawSignalInPort;
        port upwardIn : RawSignalInPort;
        port dataOut : ProcessedDataOutPort;
        port pwrIn : PowerInPort;

        calc convertToIrradiance {
            in raw : RawSignal;
            in calFactor : Real;
            return irradiance : Irradiance;
        }
        
        calc computeNet {
            in down : Irradiance;
            in up : Irradiance;
            return net : Irradiance = down - up;
        }
    }

    part def DataLogger {
        attribute samplingInterval : Real = 60 { unit = Second; }
        port dataIn : ProcessedDataInPort;
        port pwrIn : PowerInPort;
        action storeData { in data : ProcessedData; }
    }

    part def PowerSupply {
        attribute outputVoltage : Voltage = 12;
        port pwrOut : PowerOutPort;
    }

    part def NetRadiometer {
        attribute measurementError : Irradiance;
        attribute responseTime : Real { unit = Second; }
        attribute measuredNetRadiation : Irradiance;

        part upwardPyrgeometer : Pyrgeometer;
        part downwardPyrgeometer : Pyrgeometer;
        part signalProcessor : SignalProcessor;
        part dataLogger : DataLogger;
        part powerSupply : PowerSupply;

        connect powerSupply.pwrOut to signalProcessor.pwrIn;
        connect powerSupply.pwrOut to upwardPyrgeometer.pwrIn;
        connect powerSupply.pwrOut to downwardPyrgeometer.pwrIn;
        connect powerSupply.pwrOut to dataLogger.pwrIn;

        connect upwardPyrgeometer.rawOut to signalProcessor.upwardIn;
        connect downwardPyrgeometer.rawOut to signalProcessor.downwardIn;
        connect signalProcessor.dataOut to dataLogger.dataIn;
    }

    attribute def StartSignal;
    attribute def StopSignal;

    action def AcquireSignals { in r : NetRadiometer; }
    action def ConvertSignals { in r : NetRadiometer; }
    action def ComputeNet { in r : NetRadiometer; }
    action def ValidateData { in r : NetRadiometer; }
    action def StoreData { in r : NetRadiometer; }

    state def OperationalStates {
        in radiometer : NetRadiometer;
        entry; then idle;
        state idle;
        accept StartSignal then measuring;
        state measuring {
            entry; then acquiring;
            state acquiring {
                entry AcquireSignals { in r = radiometer; }
                then converting;
            }
            state converting {
                entry ConvertSignals { in r = radiometer; }
                then computing;
            }
            state computing {
                entry ComputeNet { in r = radiometer; }
                then validating;
            }
            state validating {
                entry ValidateData { in r = radiometer; }
                then storing;
            }
            state storing {
                entry StoreData { in r = radiometer; }
                then acquiring;
            }
        }
        accept StopSignal then idle;
    }

    requirement def AccuracyRequirement {
        doc /* The system must be highly accurate within ±10 W/m^2 */
        attribute maxError : Irradiance = 10;
        subject radiometerSystem : NetRadiometer;
        constraint { radiometerSystem.measurementError <= maxError }
    }

    requirement def ResponseTimeRequirement {
        doc /* The system must achieve 95% of its reading in under 10 seconds */
        attribute maxResponseTime : Real = 10 { unit = Second; }
        subject radiometerSystem : NetRadiometer;
        constraint { radiometerSystem.responseTime <= maxResponseTime }
    }

    requirement def MeasurementRangeRequirement {
        doc /* The system must be capable of measuring a wide range of radiation conditions */
        attribute minRange : Irradiance = -300;
        attribute maxRange : Irradiance = 1000;
        subject radiometerSystem : NetRadiometer;
        constraint { radiometerSystem.measuredNetRadiation >= minRange and radiometerSystem.measuredNetRadiation <= maxRange }
    }
}
