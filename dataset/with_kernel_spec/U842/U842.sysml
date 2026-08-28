package NVMagnetometer {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    item def ControlParameters {
        attribute laserPower: PowerValue;
        attribute microwaveFrequency: FrequencyValue;
        attribute measurementDuration: TimeValue;
    }
    
    item def ElectricalPower {
        attribute voltage: ElectricPotentialValue;
        attribute current: ElectricCurrentValue;
    }
    
    item def MeasurementData {
        attribute fieldStrength: MagneticFluxDensityValue;
        attribute timestamp: TimeValue;
        attribute confidence: Real;
    }
    
    item def LaserPulse {
        attribute power: PowerValue;
        attribute duration: TimeValue;
    }
    
    item def MicrowavePulse {
        attribute frequency: FrequencyValue;
        attribute duration: TimeValue;
    }
    
    item def FluorescentLight {
        attribute intensity: LuminousIntensityValue;
    }
    
    item def RawSignal {
        attribute voltage: ElectricPotentialValue;
    }
    
    item def CalibrationData {
        attribute conversionFactor: Real;
        attribute baseline: Real;
    }

    port def ControlPort { in controlParams: ControlParameters; }
    port def PowerPort { in power: ElectricalPower; }
    port def DataOutPort { out measurement: MeasurementData; }
    port def CalibrationPort { in calibration: CalibrationData; }
    
    port def LaserEmitPort { out laserPulse: LaserPulse; }
    port def LaserReceivePort { in laserPulse: LaserPulse; }
    port def MwEmitPort { out mwPulse: MicrowavePulse; }
    port def MwReceivePort { in mwPulse: MicrowavePulse; }
    port def LightEmitPort { out light: FluorescentLight; }
    port def LightReceivePort { in light: FluorescentLight; }
    port def SignalEmitPort { out rawSignal: RawSignal; }
    port def SignalReceivePort { in rawSignal: RawSignal; }
    port def ThermalEmitPort { out temperature: ThermodynamicTemperatureValue; }
    port def ThermalReceivePort { in temperature: ThermodynamicTemperatureValue; }

    part def Diamond {
        attribute operatingTemp: ThermodynamicTemperatureValue;
        port laserIn: LaserReceivePort;
        port mwIn: MwReceivePort;
        port lightOut: LightEmitPort;
        port thermalIn: ThermalReceivePort;
    }

    part def LaserSystem {
        port controlIn: ControlPort;
        port laserOut: LaserEmitPort;
    }

    part def MicrowaveGenerator {
        port controlIn: ControlPort;
        port mwOut: MwEmitPort;
    }

    part def PhotonDetector {
        port lightIn: LightReceivePort;
        port signalOut: SignalEmitPort;
    }

    part def SignalProcessor {
        port signalIn: SignalReceivePort;
        port calibrationIn: CalibrationPort;
        port dataOut: DataOutPort;
    }

    part def TemperatureStabilizer {
        port powerIn: PowerPort;
        port thermalOut: ThermalEmitPort;
        attribute targetTemp: ThermodynamicTemperatureValue = 300 [K];
    }

    action def MeasurementCycle {
        in controlParams: ControlParameters;
        in calibration: CalibrationData;
        out measurement: MeasurementData;

        action laserPrep {
            out laserPulse: LaserPulse;
        }
        then action mwManipulate {
            in laserPulse: LaserPulse;
            out mwPulse: MicrowavePulse;
        }
        then action evolve {
            in mwPulse: MicrowavePulse;
        }
        then action laserReadout {
            out light: FluorescentLight;
        }
        then action detect {
            in light: FluorescentLight;
            out rawSignal: RawSignal;
        }
        then action process {
            in rawSignal: RawSignal;
            in calibration: CalibrationData;
            out measurement: MeasurementData;
        }
        
        flow laserPrep.laserPulse to mwManipulate.laserPulse;
        flow mwManipulate.mwPulse to evolve.mwPulse;
        flow laserReadout.light to detect.light;
        flow detect.rawSignal to process.rawSignal;
    }

    state def Lifecycle {
        state initializing;
        state ready;
        state measuring {
            entry action measure: MeasurementCycle {
                in controlParams = controlPort.controlParams;
                in calibration = calibrationPort.calibration;
                out measurement = dataPort.measurement;
            }
        }
        transition initial to initializing;
        transition initializing to ready;
        transition ready to measuring accept controlParams: ControlParameters;
        transition measuring to ready;
    }

    part def NVMagnetometerSystem {
        port controlPort: ControlPort;
        port powerPort: PowerPort;
        port dataPort: DataOutPort;
        port calibrationPort: CalibrationPort;

        part diamond: Diamond;
        part laserSystem: LaserSystem;
        part mwGenerator: MicrowaveGenerator;
        part photonDetector: PhotonDetector;
        part signalProcessor: SignalProcessor;
        part tempStabilizer: TemperatureStabilizer;

        connect laserSystem.laserOut to diamond.laserIn;
        connect mwGenerator.mwOut to diamond.mwIn;
        connect diamond.lightOut to photonDetector.lightIn;
        connect photonDetector.signalOut to signalProcessor.signalIn;
        connect signalProcessor.dataOut to dataPort;
        connect controlPort to laserSystem.controlIn;
        connect controlPort to mwGenerator.controlIn;
        connect powerPort to tempStabilizer.powerIn;
        connect tempStabilizer.thermalOut to diamond.thermalIn;
        connect calibrationPort to signalProcessor.calibrationIn;

        state lifecycle: Lifecycle;
    }
    
    requirement HighSensitivity {
        doc /* The magnetometer shall measure magnetic fields with a precision of at least 1 nT. */
        attribute precision : MagneticFluxDensityValue = 1e-9 [T];
    }
    
    requirement TemperatureStability {
        doc /* The diamond temperature shall be maintained within +/- 0.01 K of the setpoint. */
        attribute stability : ThermodynamicTemperatureValue = 0.01 [K];
    }
    
    satisfy HighSensitivity by NVMagnetometerSystem;
    satisfy TemperatureStability by NVMagnetometerSystem;
}
