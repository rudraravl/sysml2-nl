package CryogenicParticleDetectorSystem {
    private import ScalarValues::*;
    private import SI::*;
    private import Time::*;

    attribute def ParticleEnergy :> Real;
    attribute def AbsorberTemperature :> Real;
    attribute def SensorResistance :> Real;
    attribute def SignalVoltage :> Real;
    attribute def PressureValue :> Real;

    item def DarkMatterParticle;
    item def Neutrino;
    item def ExoticParticle;
    item def CosmicRay;
    item def AmbientRadiation;

    item def ThermalEnergyFlow {
        attribute energy : ParticleEnergy;
        attribute temp : AbsorberTemperature;
    }
    item def AnalogSignal {
        attribute amplitude : SignalVoltage;
        attribute duration : Real;
    }
    item def DetectorEvent {
        attribute energy : ParticleEnergy;
        attribute timestamp : Time::DateTime;
        attribute pulseShape : String;
    }

    attribute def StartCooldownSignal;
    attribute def CooldownCompleteSignal;
    attribute def TemperatureStableSignal;
    attribute def ParticleDetectedSignal;
    attribute def EventProcessedSignal;
    attribute def InitiateWarmupSignal;
    attribute def WarmupCompleteSignal;
    attribute def FaultDetectedSignal;
    attribute def FaultClearedSignal;

    port def ThermalPort;
    port def AnalogSignalPort;
    port def DigitalDataPort;
    port def CommandPort;

    action def CooldownProcedure {
        in targetTemp : AbsorberTemperature;
    }
    action def StabilizeTemperatureAction {
        in currentTemp : AbsorberTemperature;
    }
    action def ProcessParticleEventAction {
        in analogSignal : AnalogSignal;
        out detectorEvent : DetectorEvent;
    }
    action def WarmupProcedureAction;
    action def FaultHandlerAction {
        in faultCode : String;
    }

    part def CryogenicAbsorber {
        attribute energy : ParticleEnergy;
        attribute temp : AbsorberTemperature;
        port thermalPort : ThermalPort;
        port sensorMount : ThermalPort;
    }

    part def DilutionRefrigerator {
        attribute coolingPower : Real;
        attribute minTemp : AbsorberTemperature;
        port coldPort : ThermalPort;
    }

    part def ThermalLink {
        attribute thermalConductance : Real;
        port hotSide : ThermalPort;
        port coldSide : ThermalPort;
    }

    part def ThermistorSensor {
        attribute baselineResistance : SensorResistance;
        port mount : ThermalPort;
        port signalOut : AnalogSignalPort;
    }

    part def VacuumChamber {
        attribute internalPressure : PressureValue;
    }

    part def RadiationShield {
        attribute thickness : Real;
        attribute layers : Integer;
        attribute material : String;
    }

    part def LowNoiseAmplifier {
        attribute gain : Real;
        attribute noiseFloor : SignalVoltage;
        port signalIn : AnalogSignalPort;
        port signalOut : AnalogSignalPort;
    }

    part def DigitalAcquisitionSystem {
        attribute sampleRate : Real;
        attribute resolutionBits : Integer;
        port signalIn : AnalogSignalPort;
        port dataOut : DigitalDataPort;
        port cmdIn : CommandPort;
    }

    part def ControlElectronics {
        attribute status : String;
        port dataIn : DigitalDataPort;
        port cmdOut : CommandPort;
    }

    part def CryogenicParticleDetector {
        attribute operatingTemp : AbsorberTemperature;
        attribute shieldThickness : Real;
        port cmdPort : CommandPort;
        port dataPort : DigitalDataPort;

        part absorber : CryogenicAbsorber;
        part fridge : DilutionRefrigerator;
        part thermalLink : ThermalLink;
        part thermistor : ThermistorSensor;
        part chamber : VacuumChamber;
        part shield : RadiationShield;
        part amplifier : LowNoiseAmplifier;
        part daq : DigitalAcquisitionSystem;
        part controller : ControlElectronics;

        connection fridgeToLink connect fridge.coldPort to thermalLink.hotSide;
        connection linkToAbsorber connect thermalLink.coldSide to absorber.thermalPort;
        connection absorberToThermistor connect absorber.sensorMount to thermistor.mount;
        connection thermistorToAmp connect thermistor.signalOut to amplifier.signalIn;
        connection ampToDaq connect amplifier.signalOut to daq.signalIn;
        connection daqToController connect daq.dataOut to controller.dataIn;
        connection cmdToDaq connect controller.cmdOut to daq.cmdIn;

        exhibit state operationalStates : DetectorStates;
    }

    state def DetectorStates {
        entry; then offline;

        state offline;

        transition 'start_cooldown'
            first offline
            accept StartCooldownSignal
            then cooldown;

        state cooldown {
            entry action cooldownProcedure : CooldownProcedure { in targetTemp = 0.005 [SI::K]; }
        }

        transition 'cooldown_stabilize'
            first cooldown
            accept CooldownCompleteSignal
            then stabilize;

        state stabilize {
            do action stabilizeTemp : StabilizeTemperatureAction;
        }

        transition 'stabilize_ready'
            first stabilize
            accept TemperatureStableSignal
            then ready;

        state ready;

        transition 'ready_acquiring'
            first ready
            accept ParticleDetectedSignal
            then acquiring;

        state acquiring {
            entry action processEvent : ProcessParticleEventAction;
        }

        transition 'acquiring_ready'
            first acquiring
            accept EventProcessedSignal
            then ready;

        transition 'start_warmup'
            first ready
            accept InitiateWarmupSignal
            then warmup;

        state warmup {
            entry action warmupProc : WarmupProcedureAction;
        }

        transition 'warmup_offline'
            first warmup
            accept WarmupCompleteSignal
            then offline;

        transition 'fault_from_offline'
            first offline
            accept FaultDetectedSignal
            then fault;

        transition 'fault_from_cooldown'
            first cooldown
            accept FaultDetectedSignal
            then fault;

        transition 'fault_from_stabilize'
            first stabilize
            accept FaultDetectedSignal
            then fault;

        transition 'fault_from_ready'
            first ready
            accept FaultDetectedSignal
            then fault;

        transition 'fault_from_acquiring'
            first acquiring
            accept FaultDetectedSignal
            then fault;

        transition 'fault_from_warmup'
            first warmup
            accept FaultDetectedSignal
            then fault;

        state fault {
            entry action handleFault : FaultHandlerAction { in faultCode = "UNKNOWN"; }
        }

        transition 'fault_offline'
            first fault
            accept FaultClearedSignal
            then offline;
    }

    requirement def DetectorPerformanceRequirements {
        subject det : CryogenicParticleDetector;

        requirement detectDarkMatter {
            doc /* The system shall detect single particle interactions. */
        }

        requirement maintainCryogenicTemp {
            doc /* The operating temperature must be below 10 mK. */
            constraint { det.absorber.temp < 0.01 [SI::K] }
        }

        requirement lowNoiseAmplification {
            doc /* The amplifier noise floor shall be negligible. */
            constraint { det.amplifier.noiseFloor < 1e-9 [SI::V] }
        }

        requirement vacuumIntegrity {
            doc /* The vacuum chamber shall maintain pressure below 1e-6 Pa. */
            constraint { det.chamber.internalPressure < 1e-6 [SI::Pa] }
        }

        requirement shieldingAttenuation {
            doc /* The radiation shield shall attenuate background radiation by at least 10^6. */
            constraint { det.shield.layers >= 5 }
        }

        requirement samplingRate {
            doc /* The DAQ shall sample at a rate of at least 1 MHz. */
            constraint { det.daq.sampleRate >= 1e6 [SI::Hz] }
        }
    }
}
