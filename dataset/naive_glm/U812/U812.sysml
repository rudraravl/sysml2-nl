package PIDSystemModel {
    import ScalarValues::*;

    // --- Value Types ---
    value type ConcentrationValue :> Real {
        attribute unit : String = "ppm";
    }
    value type VoltageValue :> Real {
        attribute unit : String = "V";
    }
    value type CurrentValue :> Real {
        attribute unit : String = "nA";
    }
    value type EnergyValue :> Real {
        attribute unit : String = "eV";
    }
    value type FlowRateValue :> Real {
        attribute unit : String = "ml/min";
    }

    // --- Items ---
    item def Air;
    item def VOCMolecule;
    item def AirSample {
        item air : Air;
        item vocs : VOCMolecule[*];
    }
    item def IonizedVOC;
    item def ElectricPower;

    // --- Occurrences (Events) ---
    occurrence def PowerOnEvent;
    occurrence def WarmupCompleteEvent;
    occurrence def StartMeasurementEvent;
    occurrence def StopMeasurementEvent;
    occurrence def FaultDetectedEvent;
    occurrence def ResetEvent;

    // --- Port Definitions ---
    port def AirInPort {
        in air : AirSample;
    }
    port def AirOutPort {
        out air : AirSample;
    }
    port def IonOutPort {
        out ions : IonizedVOC;
    }
    port def IonInPort {
        in ions : IonizedVOC;
    }
    port def CurrentOutPort {
        out current : CurrentValue;
    }
    port def CurrentInPort {
        in current : CurrentValue;
    }
    port def VoltageOutPort {
        out voltage : VoltageValue;
    }
    port def VoltageInPort {
        in voltage : VoltageValue;
    }
    port def ConcentrationOutPort {
        out concentration : ConcentrationValue;
    }
    port def ConcentrationInPort {
        in concentration : ConcentrationValue;
    }
    port def PowerInPort {
        in power : ElectricPower;
    }
    port def PowerOutPort {
        out power : ElectricPower;
    }

    // --- Part Definitions ---
    part def Environment {
        port airOut : AirOutPort;
    }

    part def SamplePump {
        port airIn : AirInPort;
        port airOut : AirOutPort;
        port powerIn : PowerInPort;
        attribute flowRate : FlowRateValue = 200;
        action drawSample {
            in air : AirSample;
            out air : AirSample;
        }
    }

    part def UVLamp {
        port powerIn : PowerInPort;
        attribute photonEnergy : EnergyValue = 10.6;
        attribute isStable : Boolean = false;
        action emitPhotons {
            out photonEnergy : EnergyValue;
        }
    }

    part def IonizationChamber {
        port airIn : AirInPort;
        port ionOut : IonOutPort;
        part uvLamp : UVLamp;
        action ionizeVOCs {
            in air : AirSample;
            in photonEnergy : EnergyValue;
            out ions : IonizedVOC;
        }
    }

    part def CollectorElectrodes {
        port ionIn : IonInPort;
        port currentOut : CurrentOutPort;
        port powerIn : PowerInPort;
        attribute biasVoltage : VoltageValue = 100;
        action collectIons {
            in ions : IonizedVOC;
            out current : CurrentValue;
        }
    }

    part def CurrentAmplifier {
        port currentIn : CurrentInPort;
        port voltageOut : VoltageOutPort;
        port powerIn : PowerInPort;
        attribute gain : Real = 1000000;
        action amplifyCurrent {
            in current : CurrentValue;
            out voltage : VoltageValue;
        }
    }

    part def SignalProcessor {
        port voltageIn : VoltageInPort;
        port concentrationOut : ConcentrationOutPort;
        port powerIn : PowerInPort;
        attribute calibrationCurveLoaded : Boolean = true;
        action processSignal {
            in voltage : VoltageValue;
            out concentration : ConcentrationValue;
        }
    }

    part def OutputInterface {
        port concentrationIn : ConcentrationInPort;
        attribute dataReady : Boolean = true;
        action sendData {
            in concentration : ConcentrationValue;
        }
    }

    part def AlarmSystem {
        port concentrationIn : ConcentrationInPort;
        port powerIn : PowerInPort;
        attribute threshold : ConcentrationValue = 100;
        attribute alarmTriggered : Boolean = false;
        action monitorConcentration {
            in concentration : ConcentrationValue;
        }
    }

    part def PowerSupply {
        port powerOut : PowerOutPort;
        attribute mainVoltage : VoltageValue = 12;
        action distributePower {
            out power : ElectricPower;
        }
    }

    // --- System Assembly ---
    part def PIDSystem {
        attribute measuredConcentration : ConcentrationValue = 0;
        attribute systemFaulted : Boolean = false;

        port externalConcentrationOut : ConcentrationOutPort;

        part environment : Environment;
        part pump : SamplePump;
        part chamber : IonizationChamber;
        part electrodes : CollectorElectrodes;
        part amplifier : CurrentAmplifier;
        part processor : SignalProcessor;
        part output : OutputInterface;
        part alarm : AlarmSystem;
        part powerSupply : PowerSupply;

        // Air and Signal Flow Connections
        connect environment.airOut to pump.airIn;
        connect pump.airOut to chamber.airIn;
        connect chamber.ionOut to electrodes.ionIn;
        connect electrodes.currentOut to amplifier.currentIn;
        connect amplifier.voltageOut to processor.voltageIn;
        connect processor.concentrationOut to output.concentrationIn;
        connect processor.concentrationOut to alarm.concentrationIn;
        connect processor.concentrationOut to externalConcentrationOut;

        // Power Distribution Connections
        connect powerSupply.powerOut to pump.powerIn;
        connect powerSupply.powerOut to chamber.uvLamp.powerIn;
        connect powerSupply.powerOut to electrodes.powerIn;
        connect powerSupply.powerOut to amplifier.powerIn;
        connect powerSupply.powerOut to processor.powerIn;
        connect powerSupply.powerOut to alarm.powerIn;

        // --- State Machine ---
        state machine PIDStateMachine {
            state poweredOff;
            state initializationWarmup {
                entry { chamber.uvLamp.isStable = false; }
            }
            state ready {
                entry { chamber.uvLamp.isStable = true; }
            }
            state activeMeasuring;
            state alarmState;
            state faultState;

            transition from poweredOff to initializationWarmup accept PowerOnEvent;
            transition from initializationWarmup to ready accept WarmupCompleteEvent;
            transition from ready to activeMeasuring accept StartMeasurementEvent;
            transition from activeMeasuring to ready accept StopMeasurementEvent;
            transition from activeMeasuring to alarmState when measuredConcentration > alarm.threshold;
            transition from alarmState to activeMeasuring when measuredConcentration <= alarm.threshold;
            transition from poweredOff to faultState accept FaultDetectedEvent;
            transition from initializationWarmup to faultState accept FaultDetectedEvent;
            transition from ready to faultState accept FaultDetectedEvent;
            transition from activeMeasuring to faultState accept FaultDetectedEvent;
            transition from alarmState to faultState accept FaultDetectedEvent;
            transition from faultState to poweredOff accept ResetEvent;
        }
    }
}
