package 'TherapeuticDeviceSystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def IntensityLevel :> Real;
    attribute def DeviceFrequency :> ISQ::FrequencyValue;
    attribute def TherapyDuration :> ISQ::DurationValue;
    attribute def DeviceTemperature :> ISQ::ThermodynamicTemperatureValue;
    attribute def DeviceVoltage :> ISQ::ElectricPotentialValue;
    attribute def DeviceCurrent :> ISQ::ElectricCurrentValue;

    attribute def DeviceMode {
        attribute isActive : Boolean;
        attribute isPowered : Boolean;
        attribute currentMode : String;
    }

    attribute def TherapyParameters {
        attribute intensity : IntensityLevel;
        attribute frequency : DeviceFrequency;
        attribute duration : TherapyDuration;
        attribute pattern : String;
    }

    attribute def SafetyParameters {
        attribute maxTemperature : DeviceTemperature;
        attribute maxCurrent : DeviceCurrent;
        attribute maxVoltage : DeviceVoltage;
        attribute maxDuration : TherapyDuration;
    }

    item def ControlSignal {
        attribute command : String;
        attribute parameters : TherapyParameters;
        attribute timestamp : TherapyDuration;
    }

    item def StatusData {
        attribute deviceState : DeviceMode;
        attribute currentTemperature : DeviceTemperature;
        attribute batteryLevel : Real;
        attribute errorCode : Integer;
    }

    port def ControlPort {
        in commandInput : ControlSignal;
        out statusOutput : StatusData;
    }

    port def PowerPort {
        in powerSupply : ISQ::PowerValue;
        out batteryStatus : Real;
    }

    port def StimulationPort {
        out stimulationOutput : DeviceCurrent;
        in feedbackInput : Real;
    }

    port def SensorPort {
        out temperatureReading : DeviceTemperature;
        out pressureReading : ISQ::PressureValue;
    }

    part def ControllerUnit {
        port controlInterface : ControlPort;
        attribute operatingMode : DeviceMode;
        attribute therapySettings : TherapyParameters;
        attribute safetyLimits : SafetyParameters;

        perform action manageOperation {
            first start;
            then action initialize {
                out initialSettings : TherapyParameters;
            }
            then merge controlLoop;
            then action receiveCommand {
                in cmd : ControlSignal;
                out validCommand : Boolean;
            }
            then decide;
                if receiveCommand.validCommand then processCommand;
                if not receiveCommand.validCommand then rejectCommand;
            action processCommand {
                in command : ControlSignal;
                out updatedSettings : TherapyParameters;
            }
            then action validateSafety {
                in settings : TherapyParameters;
                in limits : SafetyParameters;
                out safetyOk : Boolean;
            }
            then decide;
                if validateSafety.safetyOk then applySettings;
                if not validateSafety.safetyOk then emergencyStop;
            action applySettings {
                in settings : TherapyParameters;
                out applied : Boolean;
            }
            then controlLoop;
            action rejectCommand {
                out rejected : Boolean;
            }
            then controlLoop;
            action emergencyStop {
                out stopped : Boolean;
            }
            then done;
        }
    }

    part def PowerManagement {
        port powerInterface : PowerPort;
        attribute batteryCapacity : ISQ::EnergyValue;
        attribute currentCharge : Real;
        attribute chargingState : Boolean;

        perform action managePower {
            action monitorBattery {
                out chargeLevel : Real;
                out voltageLevel : DeviceVoltage;
            }
            action regulatePower {
                in inputPower : ISQ::PowerValue;
                out outputPower : ISQ::PowerValue;
            }
            action checkLowBattery {
                in chargeLevel : Real;
                out lowBatteryAlert : Boolean;
            }
        }
    }

    part def StimulationGenerator {
        port stimulationInterface : StimulationPort;
        attribute waveformType : String;
        attribute outputLevel : DeviceCurrent;
        attribute activePattern : String;

        perform action generateStimulation {
            in therapyParams : TherapyParameters;
            out stimulationSignal : DeviceCurrent;

            first start;
            then action configureWaveform {
                in intensity : IntensityLevel;
                in frequency : DeviceFrequency;
                in pattern : String;
                out waveformConfig : String;
            }
            then action produceSignal {
                in config : String;
                out signal : DeviceCurrent;
            }
            then action modulateOutput {
                in signal : DeviceCurrent;
                in duration : TherapyDuration;
                out modulatedSignal : DeviceCurrent;
            }
            then action monitorFeedback {
                in feedback : Real;
                out feedbackOk : Boolean;
            }
            then decide;
                if monitorFeedback.feedbackOk then continueStimulation;
                if not monitorFeedback.feedbackOk then adjustOutput;
            action continueStimulation;
            action adjustOutput {
                out adjustedSignal : DeviceCurrent;
            }
            then done;
        }
    }

    part def SafetyMonitoringSystem {
        port sensorInterface : SensorPort;
        attribute temperatureThreshold : DeviceTemperature;
        attribute currentThreshold : DeviceCurrent;
        attribute pressureThreshold : ISQ::PressureValue;

        perform action monitorSafety {
            action checkTemperature {
                in currentTemp : DeviceTemperature;
                in threshold : DeviceTemperature;
                out tempSafe : Boolean;
            }
            action checkCurrent {
                in outputCurrent : DeviceCurrent;
                in threshold : DeviceCurrent;
                out currentSafe : Boolean;
            }
            action checkPressure {
                in currentPressure : ISQ::PressureValue;
                in threshold : ISQ::PressureValue;
                out pressureSafe : Boolean;
            }
            action evaluateSafety {
                in tempSafe : Boolean;
                in currentSafe : Boolean;
                in pressureSafe : Boolean;
                out overallSafe : Boolean;
            }
            action initiateShutdown {
                in safetyViolation : Boolean;
                out shutdownTriggered : Boolean;
            }
        }
    }

    part def BiocompatibleEnclosure {
        attribute material : String;
        attribute surfaceTreatment : String;
        attribute dimensions : ISQ::LengthValue[3];
        attribute insertionDepth : ISQ::LengthValue;
    }

    part def WirelessCommunication {
        attribute protocol : String;
        attribute frequency : DeviceFrequency;
        attribute range : ISQ::LengthValue;

        perform action communicateWirelessly {
            action transmitStatus {
                in status : StatusData;
                out transmitted : Boolean;
            }
            action receiveCommands {
                out command : ControlSignal;
            }
        }
    }

    part therapeuticDevice {
        part controller : ControllerUnit {
            port ctrl : ControlPort;
        }

        part powerSystem : PowerManagement {
            port pwr : PowerPort;
        }

        part stimulator : StimulationGenerator {
            port stim : StimulationPort;
        }

        part safetyMonitor : SafetyMonitoringSystem {
            port sensors : SensorPort;
        }

        part enclosure : BiocompatibleEnclosure {
            attribute material = "medical-grade silicone";
            attribute surfaceTreatment = "antimicrobial coating";
        }

        part wireless : WirelessCommunication {
            attribute protocol = "Bluetooth Low Energy";
            attribute frequency = 2.4e9 [SI::Hz];
        }

        connection controlToPower connect controller.ctrl to powerSystem.pwr;
        connection controlToStimulator connect controller.ctrl to stimulator.stim;
        connection safetyToController connect safetyMonitor.sensors to controller.ctrl;
    }

    action def StartTherapySession {
        in userParameters : TherapyParameters;
        in safetyChecks : SafetyParameters;
        out sessionStarted : Boolean;
    }

    action def StopTherapySession {
        in currentState : DeviceMode;
        out sessionStopped : Boolean;
    }

    action therapeuticWorkflow {
        first start;
        then action performPreCheck {
            out preCheckPassed : Boolean;
        }
        then decide;
            if performPreCheck.preCheckPassed then startSession;
            if not performPreCheck.preCheckPassed then abortStart;
        action startSession : StartTherapySession {
            in userParameters;
            in safetyChecks;
            out sessionStarted;
        }
        then action executeTherapy {
            loop {
                action deliverStimulation {
                    in params : TherapyParameters;
                    out stimulationDelivered : Boolean;
                }
                then action monitorConditions {
                    in temperature : DeviceTemperature;
                    in pressure : ISQ::PressureValue;
                    out conditionsNormal : Boolean;
                }
                then decide;
                    if monitorConditions.conditionsNormal then continueTherapy;
                    if not monitorConditions.conditionsNormal then handleAbnormal;
                action continueTherapy;
                action handleAbnormal {
                    out stopRequired : Boolean;
                }
            }
        }
        then action stopSession : StopTherapySession {
            in currentState;
            out sessionStopped;
        }
        action abortStart {
            out aborted : Boolean;
        }
        then done;
    }

    requirement def SafetyRequirement {
        doc /* Device shall operate within safe limits for tissue contact, temperature, and electrical stimulation. */
    }

    requirement def BiocompatibilityRequirement {
        doc /* All materials in contact with tissue shall be biocompatible, hypoallergenic, and non-toxic. */
    }

    requirement def PowerRequirement {
        doc /* Device shall provide minimum 3 hours continuous operation on full battery charge. */
    }

    requirement def WirelessRequirement {
        doc /* Device shall support wireless control and monitoring within specified range. */
    }

    requirement <'REQ-001'> primaryFunctionRequirement {
        doc /* The therapeutic device shall deliver controlled neuromuscular electrical stimulation 
                for therapeutic and wellness purposes through safe, biocompatible tissue contact. */

        subject device : therapeuticDevice;

        require safetyReq : SafetyRequirement;
        require biocompatReq : BiocompatibilityRequirement;
        require powerReq : PowerRequirement;
        require wirelessReq : WirelessRequirement;

        assume constraint properInsertion {
            device.controller.operatingMode.isActive == true
        }

        assume constraint userConsent {
            doc /* Device operated with informed user consent and appropriate training. */
        }
    }

    requirement <'REQ-002'> adjustabilityRequirement {
        doc /* Device shall provide adjustable stimulation parameters to accommodate individual user preferences and needs. */
    }

    requirement <'REQ-003'> usabilityRequirement {
        doc /* Device shall be easy to operate via wireless interface with clear status feedback. */
    }
}
