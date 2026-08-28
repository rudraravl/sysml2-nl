package HNS_System {
    import ScalarValues::*;

    // ===== Unit Definitions =====
    unit def milliampere;
    unit def volt;
    unit def hertz;
    unit def microsecond;
    unit def millisecond;
    unit def second;
    unit def literPerMinute;
    unit def breathsPerMinute;
    unit def percent;
    unit def ohm;
    unit def centimeter;
    unit def squareMillimeter;
    unit def year;

    // ===== Value Types =====
    value type ElectricCurrent :> Real {
        unit milliampere;
    }
    value type ElectricVoltage :> Real {
        unit volt;
    }
    value type Frequency :> Real {
        unit hertz;
    }
    value type PulseWidth :> Real {
        unit microsecond;
    }
    value type TimeDuration :> Real {
        unit millisecond;
    }
    value type BreathingRateValue :> Real {
        unit breathsPerMinute;
    }
    value type AirflowValue :> Real {
        unit literPerMinute;
    }
    value type BatteryPercentage :> Real {
        unit percent;
    }
    value type Impedance :> Real {
        unit ohm;
    }
    value type LengthValue :> Real {
        unit centimeter;
    }
    value type AreaValue :> Real {
        unit squareMillimeter;
    }
    value type Years :> Real {
        unit year;
    }

    // ===== Item Types =====
    item def BreathingSample {
        attribute airflow : AirflowValue;
        attribute breathingRate : BreathingRateValue;
        attribute timestamp : TimeDuration;
    }

    item def ApneaDetectionSignal {
        attribute apneaDetected : Boolean;
        attribute onsetTime : TimeDuration;
        attribute severity : Real;
    }

    item def StimulationParameters {
        attribute current : ElectricCurrent;
        attribute frequency : Frequency;
        attribute pulseWidth : PulseWidth;
        attribute burstDuration : TimeDuration;
    }

    item def TherapyCommand {
        attribute command : String;
    }

    item def SystemStatus {
        attribute stateName : String;
        attribute batteryLevel : BatteryPercentage;
        attribute timestamp : TimeDuration;
    }

    // ===== Enumeration =====
    enum def ApneaSeverityLevel {
        enumval mild;
        enumval moderate;
        enumval severe;
    }

    enum def LeadType {
        enumval unipolar;
        enumval bipolar;
        enumval multipolar;
    }

    // ===== Port Definitions =====
    port def RespiratoryDataOutPort {
        out breathingSample : BreathingSample;
    }

    port def RespiratoryDataInPort {
        in breathingSample : BreathingSample;
    }

    port def ApneaSignalOutPort {
        out apneaSignal : ApneaDetectionSignal;
    }

    port def ApneaSignalInPort {
        in apneaSignal : ApneaDetectionSignal;
    }

    port def StimulationOutPort {
        out stimulationParams : StimulationParameters;
    }

    port def StimulationInPort {
        in stimulationParams : StimulationParameters;
    }

    port def CommandOutPort {
        out command : TherapyCommand;
    }

    port def CommandInPort {
        in command : TherapyCommand;
    }

    port def StatusOutPort {
        out status : SystemStatus;
    }

    // ===== Requirements =====
    requirement def ApneaDetectionRequirement {
        doc "The system shall detect apnea events within 10 seconds of onset based on airflow and breathing rate sensor data.";
        attribute maxDetectionTime : TimeDuration = 10000;
        subject detectionTime : TimeDuration;
        require detectionTime <= maxDetectionTime;
    }

    requirement def StimulationDeliveryRequirement {
        doc "The IPG shall deliver controlled electrical stimulation pulses to the hypoglossal nerve via the stimulation lead and cuff electrode.";
        attribute maxStimulationCurrent : ElectricCurrent = 5.0;
        attribute nominalFrequency : Frequency = 33;
        attribute nominalPulseWidth : PulseWidth = 90;
        subject deliveredCurrent : ElectricCurrent;
        require deliveredCurrent <= maxStimulationCurrent;
    }

    requirement def BatteryLifeRequirement {
        doc "The IPG battery shall last at least 5 years under normal nightly operation.";
        attribute minBatteryLife : Years = 5;
    }

    requirement def AirwayPatencyRequirement {
        doc "Stimulation shall maintain upper airway patency without waking the patient during sleep.";
    }

    requirement def ClosedLoopTherapyRequirement {
        doc "The system shall operate as a closed-loop therapy automatically throughout the night, detecting apnea and responding with stimulation.";
    }

    requirement def RemoteControlRequirement {
        doc "The patient shall be able to turn the system on before sleep and off after waking using a handheld remote control.";
    }

    requirement def LeadIntegrityRequirement {
        doc "The stimulation lead shall maintain electrical integrity from IPG to nerve cuff electrode.";
        attribute maxConductorResistance : Impedance = 50;
    }

    requirement def ElectrodeImpedanceRequirement {
        doc "The nerve cuff electrode shall maintain impedance within therapeutic range.";
        attribute minImpedance : Impedance = 400;
        attribute maxImpedance : Impedance = 2000;
    }

    requirement def SensorSamplingRequirement {
        doc "The respiratory sensor shall sample breathing data at sufficient rate to detect apnea events.";
        attribute minSamplingRate : Frequency = 50;
    }

    // ===== Part Definitions =====

    part def BatteryPack {
        doc "Implantable battery powering the IPG throughout its service life.";
        attribute capacity : ElectricCurrent = 1500;
        attribute currentCharge : BatteryPercentage = 100;
        attribute minOperatingLevel : BatteryPercentage = 10;
        attribute estimatedLife : Years = 5;
        attribute chemistry : String = "lithium";

        action def discharge {
            in amount : ElectricCurrent;
            out remainingCharge : BatteryPercentage;
        }

        action def checkLevel {
            out level : BatteryPercentage;
            out isLow : Boolean;
        }
    }

    part def RespiratorySensor {
        doc "Respiratory sensor placed near the ribs to continuously monitor breathing patterns including airflow and breathing rate.";
        port dataOutPort : RespiratoryDataOutPort;
        port apneaSignalPort : ApneaSignalOutPort;

        attribute samplingRate : Frequency = 100;
        attribute airflowThreshold : AirflowValue = 0.5;
        attribute rateThreshold : BreathingRateValue = 5;
        attribute apneaDetectionWindow : TimeDuration = 10000;
        attribute isImplanted : Boolean = true;
        attribute placementLocation : String = "intercostal";

        action def sampleBreathing {
            out sample : BreathingSample;
        }

        action def analyzeForApnea {
            in sample : BreathingSample;
            out signal : ApneaDetectionSignal;
        }

        action def calibrate {
            out calibrationSuccess : Boolean;
        }

        perform sampleBreathing;
        perform analyzeForApnea;
    }

    part def NerveCuffElectrode {
        doc "Cuff electrode carefully placed around the hypoglossal nerve to deliver stimulation pulses.";
        port stimulationInPort : StimulationInPort;

        attribute contactArea : AreaValue = 10;
        attribute impedance : Impedance = 1000;
        attribute nerveTarget : String = "hypoglossal";
        attribute placementLocation : String = "neck";
        attribute electrodeType : String = "cuff";
        attribute contactCount : Integer = 4;

        action def deliverStimulationToNerve {
            in params : StimulationParameters;
        }

        action def measureImpedance {
            out measuredImpedance : Impedance;
        }
    }

    part def StimulationLead {
        doc "Thin, flexible wire running from the IPG in the upper chest to the nerve cuff electrode in the neck.";
        port proximalPort : StimulationInPort;
        port distalPort : StimulationOutPort;

        attribute leadLength : LengthValue = 50;
        attribute conductorResistance : Impedance = 50;
        attribute insulationRating : ElectricVoltage = 500;
        attribute flexibility : String = "high";
        attribute leadType : LeadType = LeadType::bipolar;
        attribute connectorType : String = "IS-1";

        action def conductStimulation {
            in params : StimulationParameters;
            out conductedParams : StimulationParameters;
        }
    }

    part def RemoteControl {
        doc "External, handheld remote control used by the patient to turn the system on and off.";
        port commandPort : CommandOutPort;
        port statusPort : StatusOutPort;

        attribute powerSource : String = "CR2032";
        attribute isWaterproof : Boolean = true;
        attribute communicationRange : LengthValue = 100;
        attribute communicationType : String = "RF telemetry";

        action def sendTherapyCommand {
            out cmd : TherapyCommand;
        }

        action def receiveStatus {
            in status : SystemStatus;
        }

        action def displayStatus {
            in status : SystemStatus;
        }
    }

    part def ImplantablePulseGenerator {
        doc "Implantable Pulse Generator - the brain of the HNS system, surgically placed under the skin in the upper chest.";
        port sensorDataPort : RespiratoryDataInPort;
        port apneaInputPort : ApneaSignalInPort;
        port stimulationOutPort : StimulationOutPort;
        port commandPort : CommandInPort;
        port statusOutPort : StatusOutPort;

        part battery : BatteryPack;

        attribute nominalStimulationCurrent : ElectricCurrent = 3.0;
        attribute nominalStimulationFrequency : Frequency = 33;
        attribute nominalPulseWidth : PulseWidth = 90;
        attribute stimulationBurstDuration : TimeDuration = 5000;
        attribute implantLocation : String = "upper chest";
        attribute titrationLevel : Integer = 1;
        attribute maxTitrationLevel : Integer = 10;

        attribute therapyOnRequested : Boolean = false;
        attribute therapyOffRequested : Boolean = false;
        attribute apneaDetected : Boolean = false;
        attribute apneaResolved : Boolean = true;
        attribute batteryLow : Boolean = false;
        attribute faultDetected : Boolean = false;

        action def processBreathingData {
            in sample : BreathingSample;
        }

        action def generateStimulationPulse {
            out params : StimulationParameters;
        }

        action def powerOnSystem;
        action def powerOffSystem;
        action def beginMonitoring;
        action def stopMonitoring;
        action def beginStimulation;
        action def endStimulation;
        action def handleFault;
        action def logData;
        action def adjustTitration {
            in currentLevel : Integer;
            out newLevel : Integer;
        }

        state machine def IPGStateMachine {
            state off {
                entry powerOffSystem;
            }

            state standby {
                entry powerOnSystem;
            }

            state monitoring {
                entry beginMonitoring;
                do processBreathingData;
                exit stopMonitoring;
            }

            state stimulating {
                entry beginStimulation;
                do generateStimulationPulse;
                exit endStimulation;
            }

            state fault {
                entry handleFault;
            }

            transition offToStandby first off then standby
                when therapyOnRequested;

            transition standbyToMonitoring first standby then monitoring
                when not batteryLow;

            transition monitoringToStimulating first monitoring then stimulating
                when apneaDetected;

            transition stimulatingToMonitoring first stimulating then monitoring
                when apneaResolved;

            transition monitoringToStandby first monitoring then standby
                when therapyOffRequested;

            transition standbyToOff first standby then off
                when therapyOffRequested;

            transition toFault first (monitoring, stimulating) then fault
                when faultDetected or batteryLow;

            transition faultToStandby first fault then standby
                when not faultDetected and not batteryLow;
        }

        exhibit IPGStateMachine;
    }

    // ===== Anatomical Parts =====
    part def HypoglossalNerve {
        doc "The hypoglossal nerve - cranial nerve XII that controls the movement of the tongue.";
        attribute location : String = "neck";
        attribute function : String = "tongue motor control";
        attribute nerveType : String = "cranial nerve XII";

        action def activate {
            in params : StimulationParameters;
            out activationSignal : Boolean;
        }
    }

    part def GenioglossalMuscle {
        doc "The genioglossal muscle at the base of the tongue responsible for tongue protrusion.";
        attribute location : String = "tongue base";
        attribute function : String = "tongue protrusion";
        attribute innervation : String = "hypoglossal nerve";

        action def contract {
            in activationSignal : Boolean;
            out contractionForce : Real;
        }
    }

    part def UpperAirway {
        doc "Upper airway passage that must remain patent during sleep to prevent obstruction.";
        attribute isPatent : Boolean = true;
        attribute patencyStatus : String = "open";

        action def maintain {
            in muscleContraction : Boolean;
            out patencyMaintained : Boolean;
        }

        action def collapse {
            out collapsed : Boolean;
        }
    }

    part def Tongue {
        doc "The tongue, whose forward movement opens the upper airway.";
        attribute position : String = "neutral";

        action def moveForward {
            in contractionForce : Real;
            out displacement : LengthValue;
        }
    }

    part def Patient {
        doc "Patient receiving hypoglossal nerve stimulation therapy for obstructive sleep apnea.";
        part hypoglossalNerve : HypoglossalNerve;
        part genioglossalMuscle : GenioglossalMuscle;
        part upperAirway : UpperAirway;
        part tongue : Tongue;

        attribute sleepState : String = "sleeping";
        attribute hasOSA : Boolean = true;
    }

    // ===== Top-Level System =====
    part def HNSDevice {
        doc "Hypoglossal Nerve Stimulation System - an implantable medical device for treating obstructive sleep apnea through closed-loop airway management.";

        part ipg : ImplantablePulseGenerator;
        part respiratorySensor : RespiratorySensor;
        part stimulationLead : StimulationLead;
        part nerveCuffElectrode : NerveCuffElectrode;
        part remoteControl : RemoteControl;
        part patient : Patient;

        // Electrical and data connections
        connection sensorDataLink connect respiratorySensor.dataOutPort to ipg.sensorDataPort;
        connection apneaSignalLink connect respiratorySensor.apneaSignalPort to ipg.apneaInputPort;
        connection stimulationLink connect ipg.stimulationOutPort to stimulationLead.proximalPort;
        connection leadToElectrodeLink connect stimulationLead.distalPort to nerveCuffElectrode.stimulationInPort;
        connection commandLink connect remoteControl.commandPort to ipg.commandPort;
        connection statusLink connect ipg.statusOutPort to remoteControl.statusPort;

        // Anatomical interaction connections
        connection electrodeToNerve connect nerveCuffElectrode to patient.hypoglossalNerve;
        connection nerveToMuscle connect patient.hypoglossalNerve to patient.genioglossalMuscle;
        connection muscleToTongue connect patient.genioglossalMuscle to patient.tongue;
        connection tongueToAirway connect patient.tongue to patient.upperAirway;

        // Requirement satisfaction
        satisfy ApneaDetectionRequirement by respiratorySensor;
        satisfy StimulationDeliveryRequirement by ipg;
        satisfy BatteryLifeRequirement by ipg.battery;
        satisfy AirwayPatencyRequirement by patient.upperAirway;
        satisfy ClosedLoopTherapyRequirement by ipg;
        satisfy RemoteControlRequirement by remoteControl;
        satisfy LeadIntegrityRequirement by stimulationLead;
        satisfy ElectrodeImpedanceRequirement by nerveCuffElectrode;
        satisfy SensorSamplingRequirement by respiratorySensor;
    }
}
