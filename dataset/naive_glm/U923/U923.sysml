package CryogenicDetectorSystem {
    import ScalarValues::*;

    value type Temperature :> Real;
    value type Energy :> Real;
    value type Resistance :> Real;
    value type Current :> Real;
    value type Voltage :> Real;
    value type Power :> Real;
    value type TimeValue :> Real;

    item def Photon {
        attribute energy : Energy;
    }

    item def Pulse {
        attribute peakVoltage : Voltage;
        attribute width : TimeValue;
        attribute integral : Real;
    }

    item def CalibData {
        attribute energyScale : Real;
        attribute offset : Energy;
    }

    item def Measurement {
        attribute photonEnergy : Energy;
        attribute timestamp : TimeValue;
    }

    interface def OpticalInterface {
        item photon : Photon;
    }
    port def OpticalPort :> OpticalInterface;

    interface def ThermalInterface {
        attribute heatFlow : Power;
        attribute temperature : Temperature;
    }
    port def ThermalPort :> ThermalInterface;

    interface def ElectricalInterface {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    port def ElecPort :> ElectricalInterface;

    interface def DataInterface {
        item pulse : Pulse;
    }
    port def DataPort :> DataInterface;

    interface def ResultInterface {
        item result : Measurement;
    }
    port def ResultPort :> ResultInterface;

    part def Cryostat {
        attribute setPoint : Temperature = 0.1 [K];
        attribute coolingCapacity : Power = 1e-6 [W];
        port coolingOut : ThermalPort;
        action maintainTemp {
            coolingOut.heatFlow = -coolingCapacity;
            coolingOut.temperature = setPoint;
        }
    }

    part def BiasCircuit {
        attribute biasCurrent : Current = 1e-5 [A];
        port biasOut : ElecPort;
        action supplyCurrent {
            biasOut.current = biasCurrent;
        }
    }

    part def TransitionEdgeSensor {
        attribute criticalTemp : Temperature = 0.1 [K];
        attribute normalResistance : Resistance = 1.0 [Ohm];
        attribute heatCapacity : Real = 1e-15;
        
        attribute currentTemp : Temperature;
        attribute currentRes : Resistance;
        
        port opticalIn : OpticalPort;
        port thermalIn : ThermalPort;
        port biasIn : ElecPort;
        port signalOut : ElecPort;
        
        state machine TESStateMachine {
            state ready {
                entry {
                    currentRes = 0.0;
                    currentTemp = criticalTemp;
                    signalOut.voltage = 0.0;
                }
            }
            
            state absorbing {
                entry {
                    currentTemp = currentTemp + (opticalIn.photon.energy / heatCapacity);
                }
            }
            
            state thermalizing {
                entry {
                    currentRes = normalResistance;
                    signalOut.voltage = currentRes * biasIn.current;
                }
            }
            
            state recovering {
                entry {
                    currentTemp = criticalTemp;
                    currentRes = 0.0;
                    signalOut.voltage = 0.0;
                }
            }
            
            transition from ready to absorbing when opticalIn.photon.energy > 0;
            transition from absorbing to thermalizing when currentTemp > criticalTemp;
            transition from thermalizing to recovering when signalOut.voltage > 0;
            transition from recovering to ready when currentTemp <= criticalTemp;
        }
    }

    part def SQUIDAmplifier {
        attribute gain : Real = 1000.0;
        port signalIn : ElecPort;
        port amplifiedOut : DataPort;
        
        action amplify {
            amplifiedOut.pulse.peakVoltage = signalIn.voltage * gain;
            amplifiedOut.pulse.width = 1e-6 [s];
            amplifiedOut.pulse.integral = amplifiedOut.pulse.peakVoltage * amplifiedOut.pulse.width;
        }
    }

    part def SignalProcessor {
        attribute calib : CalibData;
        port dataIn : DataPort;
        port resultOut : ResultPort;
        
        action processPulse {
            resultOut.result.photonEnergy = (dataIn.pulse.peakVoltage * calib.energyScale) + calib.offset;
            resultOut.result.timestamp = 0.0;
        }
    }

    part def TransitionEdgeSensingUnit {
        part tes : TransitionEdgeSensor;
        part cryo : Cryostat;
        part bias : BiasCircuit;
        part squid : SQUIDAmplifier;
        part proc : SignalProcessor;
        
        connect cryo.coolingOut to tes.thermalIn;
        connect bias.biasOut to tes.biasIn;
        connect tes.signalOut to squid.signalIn;
        connect squid.amplifiedOut to proc.dataIn;
    }

    requirement CryogenicOperation {
        doc /* The TES must be maintained at an ultra-low operating temperature around 0.1 K. */
        subject detector : TransitionEdgeSensingUnit;
        constraint { detector.tes.currentTemp <= 0.1 [K]; }
    }

    requirement SinglePhotonDetection {
        doc /* The system must detect single photons and transition states accordingly. */
        subject detector : TransitionEdgeSensingUnit;
        constraint { detector.tes.currentRes > 0 when detector.tes.opticalIn.photon.energy > 0; }
    }

    requirement EnergyMeasurement {
        doc /* The system must output a precise measurement of the photon energy. */
        subject detector : TransitionEdgeSensingUnit;
        constraint { detector.proc.resultOut.result.photonEnergy > 0; }
    }
}
