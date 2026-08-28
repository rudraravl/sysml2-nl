package HPGeDetectorSystem {

    import ScalarValues::*;

    // ============================================================
    // Value Types (with units)
    // ============================================================
    value type VoltageValue :> Real { unit 'V'; }
    value type CurrentValue :> Real { unit 'A'; }
    value type ChargeValue :> Real { unit 'C'; }
    value type TemperatureValue :> Real { unit 'K'; }
    value type EnergyValue :> Real { unit 'keV'; }
    value type TimeValue :> Real { unit 's'; }
    value type FrequencyValue :> Real { unit 'Hz'; }
    value type PressureValue :> Real { unit 'Pa'; }
    value type CountValue :> Integer;
    value type EventIDValue :> Integer;
    value type RatioValue :> Real { unit 'dB'; }

    // ============================================================
    // Item Definitions
    // ============================================================
    item def GammaRay {
        attribute incidentEnergy : EnergyValue;
        attribute directionAngle : Real;
    }

    item def RadiationEvent {
        attribute energy : EnergyValue;
        attribute particleType : String;
        attribute direction : String;
        attribute timestamp : TimeValue;
    }

    item def ChargePulse {
        attribute totalCharge : ChargeValue;
        attribute arrivalTime : TimeValue;
        attribute originEnergy : EnergyValue;
    }

    item def VoltagePulse {
        attribute peakAmplitude : VoltageValue;
        attribute pulseDuration : TimeValue;
        attribute arrivalTime : TimeValue;
        attribute originEnergy : EnergyValue;
    }

    item def DigitalSample {
        attribute energyChannel : CountValue;
        attribute timestamp : TimeValue;
        attribute sampleID : EventIDValue;
    }

    item def RecordedEvent {
        attribute eventID : EventIDValue;
        attribute measuredEnergy : EnergyValue;
        attribute timestamp : TimeValue;
        attribute channel : CountValue;
    }

    item def ControlCommand {
        attribute commandType : String;
        attribute targetValue : Real;
    }

    item def TemperatureStatus {
        attribute current : TemperatureValue;
        attribute setpoint : TemperatureValue;
        attribute stable : Boolean;
    }

    item def VoltageStatus {
        attribute current : VoltageValue;
        attribute setpoint : VoltageValue;
        attribute ramping : Boolean;
    }

    item def SystemStatusReport {
        attribute stateName : String;
        attribute temperatureOK : Boolean;
        attribute voltageOK : Boolean;
        attribute acquisitionActive : Boolean;
    }

    // ============================================================
    // Port Definitions
    // ============================================================
    port def RadiationInputPort {
        in radiation : RadiationEvent;
    }

    port def ChargeSignalPort {
        out pulse : ChargePulse;
    }

    port def VoltageSignalPort {
        out pulse : VoltagePulse;
    }

    port def DigitalDataPort {
        out sample : DigitalSample;
    }

    port def EventStreamPort {
        out recorded : RecordedEvent;
    }

    port def HVControlPort {
        in command : ControlCommand;
        out status : VoltageStatus;
    }

    port def ThermalControlPort {
        in command : ControlCommand;
        out status : TemperatureStatus;
    }

    port def ThermalSensePort {
        out temperature : TemperatureValue;
    }

    port def HVSensePort {
        out voltage : VoltageValue;
    }

    port def SystemControlPort {
        in command : ControlCommand;
        out status : SystemStatusReport;
    }

    // ============================================================
    // Component Definitions
    // ============================================================
    part def TemperatureController {
        attribute setpoint : TemperatureValue = 77.0;
        attribute tolerance : TemperatureValue = 1.0;
        attribute maxCoolingPower : Real;
        attribute currentTemp : TemperatureValue = 300.0;
        attribute coolingActive : Boolean = false;
        attribute tempStable : Boolean = false;
        attribute lastCommand : String = "";
        port thermalInterface : ThermalControlPort;
        port senseOut : ThermalSensePort;
        action def regulateTemperature {
            in measuredTemp : TemperatureValue;
            in target : TemperatureValue;
            out status : TemperatureStatus;
        }
        state machine CoolingStates {
            state off {
                doc /* Cryostat inactive, no active cooling applied. */
            }
            state ramping {
                doc /* Active cooling toward the 77 K setpoint. */
            }
            state stable {
                doc /* Temperature within tolerance of 77 K. */
            }
            transition t1 off -> ramping when lastCommand == "start";
            transition t2 ramping -> stable when |currentTemp - setpoint| < tolerance;
            transition t3 stable -> off when lastCommand == "stop";
            transition t4 ramping -> off when lastCommand == "stop";
        }
    }

    part def HVPowerSupply {
        attribute targetVoltage : VoltageValue = 3000.0;
        attribute maxRampRate : VoltageValue = 100.0;
        attribute currentOutput : VoltageValue = 0.0;
        attribute ramping : Boolean = false;
        attribute lastCommand : String = "";
        port hvInterface : HVControlPort;
        port senseOut : HVSensePort;
        action def rampUp {
            in target : VoltageValue;
            out finalVoltage : VoltageValue;
        }
        action def rampDown {
            out finalVoltage : VoltageValue;
        }
        state machine HVStates {
            state off;
            state ramping;
            state on;
            transition t1 off -> ramping when lastCommand == "rampUp";
            transition t2 ramping -> on when currentOutput >= targetVoltage;
            transition t3 on -> ramping when lastCommand == "rampDown";
            transition t4 ramping -> off when currentOutput <= 0.0;
        }
    }

    part def HPGeCrystal {
        attribute operatingTemperature : TemperatureValue = 77.0;
        attribute biasVoltage : VoltageValue = 3000.0;
        attribute activeVolume : Real = 100.0;
        attribute detectionEfficiency : Real = 0.5;
        attribute depletionVoltage : VoltageValue = 2500.0;
        attribute sensitive : Boolean = false;
        attribute meanIonizationEnergy : EnergyValue = 2.96e-6;
        port radiationIn : RadiationInputPort;
        port chargeOut : ChargeSignalPort;
        port thermalSenseIn : ~ThermalSensePort;
        port hvSenseIn : ~HVSensePort;
        action def convertRadiationToCharge {
            in event : RadiationEvent;
            out pulse : ChargePulse;
        }
        state machine CrystalStates {
            state insensitive {
                doc /* Bias voltage below depletion or temperature too high. */
            }
            state sensitive {
                doc /* Crystal biased and cold; ready to convert radiation to charge. */
            }
            transition t1 insensitive -> sensitive when (biasVoltage > depletionVoltage) & (operatingTemperature < 100.0);
            transition t2 sensitive -> insensitive when (biasVoltage < depletionVoltage) | (operatingTemperature > 120.0);
        }
    }

    part def ChargeAmplifier {
        attribute transimpedanceGain : Real = 1.0e6;
        attribute noiseFloor : VoltageValue = 1.0e-6;
        attribute bandwidth : FrequencyValue = 1.0e7;
        port chargeIn : ~ChargeSignalPort;
        port voltageOut : VoltageSignalPort;
        action def amplify {
            in chargePulse : ChargePulse;
            out voltagePulse : VoltagePulse;
        }
    }

    part def PulseShaper {
        attribute shapingTime : TimeValue = 1.0e-6;
        attribute baselineRestorer : Boolean = true;
        attribute pileupRejection : Boolean = true;
        attribute poleZeroCancellation : Boolean = true;
        port pulseIn : ~VoltageSignalPort;
        port pulseOut : VoltageSignalPort;
        action def shape {
            in rawPulse : VoltagePulse;
            out shapedPulse : VoltagePulse;
        }
    }

    part def PulseHeightAnalyzer {
        attribute adcResolutionBits : CountValue = 16;
        attribute sampleRate : FrequencyValue = 1.0e8;
        attribute conversionGain : EnergyValue = 0.05;
        attribute fullScaleVoltage : VoltageValue = 10.0;
        port pulseIn : ~VoltageSignalPort;
        port digitalOut : DigitalDataPort;
        action def analyze {
            in pulse : VoltagePulse;
            out sample : DigitalSample;
        }
    }

    part def DataAcquisitionUnit {
        attribute bufferDepth : CountValue = 65536;
        attribute clockResolution : TimeValue = 1.0e-9;
        attribute nextEventID : EventIDValue = 1;
        attribute eventCount : CountValue = 0;
        ref attribute eventBuffer : RecordedEvent[0..*];
        port digitalIn : ~DigitalDataPort;
        port eventOut : EventStreamPort;
        action def recordEvent {
            in sample : DigitalSample;
            out recorded : RecordedEvent;
        }
        action def flushBuffer {
            out events : RecordedEvent[0..*];
        }
    }

    part def SystemController {
        attribute currentMode : String = "standby";
        attribute acquisitionEnabled : Boolean = false;
        port controlIf : SystemControlPort;
        port thermalCommand : ~ThermalControlPort;
        port hvCommand : ~HVControlPort;
        action def issueCommand {
            in cmd : String;
            in targetValue : Real;
            out command : ControlCommand;
        }
    }

    // ============================================================
    // Top-Level System
    // ============================================================
    part def HPGeDetectorSystem {
        part controller : SystemController;
        part temperatureController : TemperatureController;
        part hvSupply : HVPowerSupply;
        part crystal : HPGeCrystal;
        part amplifier : ChargeAmplifier;
        part shaper : PulseShaper;
        part analyzer : PulseHeightAnalyzer;
        part daq : DataAcquisitionUnit;

        port radiationInput : RadiationInputPort;
        port eventOutput : EventStreamPort;
        port systemControl : SystemControlPort;

        // --- Signal-path connections ---
        connection c_radToCrystal connect radiationInput to crystal.radiationIn;
        connection c_crystalToAmp connect crystal.chargeOut to amplifier.chargeIn;
        connection c_ampToShaper connect amplifier.voltageOut to shaper.pulseIn;
        connection c_shaperToAnalyzer connect shaper.pulseOut to analyzer.pulseIn;
        connection c_analyzerToDaq connect analyzer.digitalOut to daq.digitalIn;
        connection c_daqToOutput connect daq.eventOut to eventOutput;

        // --- Control and sense connections ---
        connection c_ctrlThermal connect controller.thermalCommand to temperatureController.thermalInterface;
        connection c_ctrlHV connect controller.hvCommand to hvSupply.hvInterface;
        connection c_thermalSense connect temperatureController.senseOut to crystal.thermalSenseIn;
        connection c_hvSense connect hvSupply.senseOut to crystal.hvSenseIn;
        connection c_ctrlBinding connect controller.controlIf to systemControl;

        // --- State machine control flags ---
        attribute startCommandReceived : Boolean = false;
        attribute shutdownRequested : Boolean = false;
        attribute maintenanceRequested : Boolean = false;
        attribute maintenanceComplete : Boolean = false;
        attribute acquisitionRequested : Boolean = false;
        attribute stopAcquisition : Boolean = false;
        attribute emergencyShutdown : Boolean = false;
        attribute shutdownComplete : Boolean = false;
        attribute initComplete : Boolean = false;
        attribute tempStable : Boolean = false;
        attribute hvStable : Boolean = false;

        state machine SystemStates {
            state standby {
                doc /* High voltage off, cryostat off, electronics idle. */
            }
            state initialization {
                doc /* Cooling crystal to 77 K and ramping high voltage to 3000 V. */
                state cooling {
                    doc /* Active cryogenic cooling in progress. */
                }
                state voltageRamp {
                    doc /* Controlled ramp of bias voltage toward 3000 V. */
                }
                transition t_coolToRamp cooling -> voltageRamp when tempStable;
                transition t_initToOp initialization -> operational when initComplete;
            }
            state operational {
                doc /* System armed; ready for or performing acquisition. */
                state idle {
                    doc /* Ready but not currently recording events. */
                }
                state acquiring {
                    doc /* Actively recording radiation events to the DAQ buffer. */
                }
                transition t_idleToAcq idle -> acquiring when acquisitionRequested;
                transition t_acqToIdle acquiring -> idle when stopAcquisition;
            }
            state maintenance {
                doc /* HV disabled, cryostat may warm; service access permitted. */
            }
            state shutdown {
                doc /* Controlled power-down of HV and cooling systems. */
                state voltageRampDown {
                    doc /* Controlled reduction of bias voltage toward zero. */
                }
                state warming {
                    doc /* Cryostat permitted to warm after HV reaches safe level. */
                }
                transition t_rampToWarm voltageRampDown -> warming when hvStable == false;
                transition t_shutdownToStandby shutdown -> standby when shutdownComplete;
            }
            transition t_standbyToInit standby -> initialization when startCommandReceived;
            transition t_opToMaint operational -> maintenance when maintenanceRequested;
            transition t_maintToOp maintenance -> operational when maintenanceComplete;
            transition t_opToShutdown operational -> shutdown when shutdownRequested;
            transition t_standbyToShutdown standby -> shutdown when emergencyShutdown;
        }

        // --- Operational action ---
        action def processRadiationEvent {
            in event : RadiationEvent;
            out recorded : RecordedEvent;
        }
    }

    // ============================================================
    // Requirements
    // ============================================================
    requirement RadiationDetectionRequirement {
        doc /* The system shall detect individual ionizing radiation events (particles or photons). */
        subject system : HPGeDetectorSystem;
        attribute minDetectionEfficiency : Real = 0.5;
    }

    requirement EnergyMeasurementRequirement {
        doc /* The system shall precisely measure the energy deposited by each detected event. */
        subject system : HPGeDetectorSystem;
        attribute energyResolutionFWHM : EnergyValue = 2.0;
        attribute referenceEnergy : EnergyValue = 1332.0;
    }

    requirement CryogenicCoolingRequirement {
        doc /* The HPGe crystal shall be cryogenically cooled to 77 K +/- 1 K to reduce electronic noise. */
        subject system : HPGeDetectorSystem;
        attribute targetTemperature : TemperatureValue = 77.0;
        attribute tolerance : TemperatureValue = 1.0;
    }

    requirement HighVoltageRequirement {
        doc /* A stable bias voltage of approximately 3000 V shall be applied across the HPGe crystal. */
        subject system : HPGeDetectorSystem;
        attribute biasVoltage : VoltageValue = 3000.0;
        attribute stabilityPercent : Real = 0.01;
    }

    requirement DigitalRecordingRequirement {
        doc /* Each detected event shall be digitally recorded with a unique ID, measured energy, and precise timestamp. */
        subject system : HPGeDetectorSystem;
        attribute requiredFields : String = "eventID, measuredEnergy, timestamp";
    }

    requirement StateManagementRequirement {
        doc /* The system shall support standby, initialization, operational (idle/acquiring), maintenance, and shutdown states with controlled transitions. */
        subject system : HPGeDetectorSystem;
    }

    requirement AcquisitionRateRequirement {
        doc /* The system shall sustain event rates up to 10000 events/s without significant pileup degradation. */
        subject system : HPGeDetectorSystem;
        attribute maxEventRate : FrequencyValue = 10000.0;
    }

    requirement SignalChainIntegrityRequirement {
        doc /* The charge signal from the crystal shall pass sequentially through charge amplifier, pulse shaper, pulse-height analyzer, and data acquisition unit. */
        subject system : HPGeDetectorSystem;
    }
}
