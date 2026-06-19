package TrigeminalNerveStimulationModel {
    import ScalarValues::*;

    attribute def Current_mA :> Real {
        doc /* Unit: milliampere (mA). */
    }

    attribute def Voltage_V :> Real {
        doc /* Unit: volt (V). */
    }

    attribute def Frequency_Hz :> Real {
        doc /* Unit: hertz (Hz). */
    }

    attribute def Duration_ms :> Real {
        doc /* Unit: millisecond (ms). */
    }

    attribute def Duration_s :> Real {
        doc /* Unit: second (s). */
    }

    attribute def Charge_uC :> Real {
        doc /* Unit: microcoulomb (uC). */
    }

    attribute def Resistance_ohm :> Real {
        doc /* Unit: ohm. */
    }

    attribute def Temperature_C :> Real {
        doc /* Unit: degree Celsius. */
    }

    attribute def Energy_Wh :> Real {
        doc /* Unit: watt-hour (Wh). */
    }

    enum def TherapyMode {
        enum poweredOff;
        enum standby;
        enum selfTest;
        enum contactCheck;
        enum stimulationActive;
        enum paused;
        enum completed;
        enum faulted;
    }

    enum def PulsePolarity {
        enum anodicFirst;
        enum cathodicFirst;
        enum balancedBiphasic;
    }

    enum def ContactQuality {
        enum openCircuit;
        enum poor;
        enum acceptable;
        enum good;
        enum shortCircuit;
    }

    enum def FaultCode {
        enum none;
        enum batteryLow;
        enum electrodeOpen;
        enum electrodeShort;
        enum overCurrent;
        enum overTemperature;
        enum sessionTimeout;
        enum internalSelfTestFailure;
    }

    item def ElectricalPower {
        attribute voltage : Voltage_V;
        attribute availableEnergy : Energy_Wh;
    }

    item def UserCommand {
        attribute startRequested : Boolean;
        attribute pauseRequested : Boolean;
        attribute stopRequested : Boolean;
        attribute requestedIntensity : Current_mA;
        attribute requestedDuration : Duration_s;
    }

    item def UserIndication {
        attribute activeMode : TherapyMode;
        attribute remainingSessionTime : Duration_s;
        attribute contactQuality : ContactQuality;
        attribute fault : FaultCode;
    }

    item def TherapyPrescription {
        attribute amplitude : Current_mA;
        attribute pulseWidth : Duration_ms;
        attribute pulseFrequency : Frequency_Hz;
        attribute sessionDuration : Duration_s;
        attribute polarity : PulsePolarity;
        attribute chargePerPhase : Charge_uC;
    }

    item def StimulationCommand {
        attribute enableOutput : Boolean;
        attribute commandedAmplitude : Current_mA;
        attribute commandedPulseWidth : Duration_ms;
        attribute commandedFrequency : Frequency_Hz;
        attribute commandedPolarity : PulsePolarity;
        attribute commandedSessionTime : Duration_s;
    }

    item def StimulationStatus {
        attribute outputEnabled : Boolean;
        attribute measuredCurrent : Current_mA;
        attribute measuredVoltage : Voltage_V;
        attribute measuredImpedance : Resistance_ohm;
        attribute fault : FaultCode;
    }

    item def BiphasicElectricalPulse {
        attribute positivePhaseCurrent : Current_mA;
        attribute negativePhaseCurrent : Current_mA;
        attribute phaseWidth : Duration_ms;
        attribute interphaseGap : Duration_ms;
        attribute repetitionFrequency : Frequency_Hz;
        attribute netCharge : Charge_uC;
    }

    item def ElectrodeContactMeasurement {
        attribute contactImpedance : Resistance_ohm;
        attribute skinTemperature : Temperature_C;
        attribute contactQuality : ContactQuality;
    }

    item def ElectricFieldCoupling {
        attribute deliveredCurrent : Current_mA;
        attribute surfaceVoltage : Voltage_V;
        attribute estimatedNerveCoupling : Real;
    }

    item def NeuralModulationResponse {
        attribute trigeminalBranchStimulated : String;
        attribute responseDetected : Boolean;
        attribute estimatedModulationLevel : Real;
    }

    item def TherapySessionReport {
        attribute deliveredDuration : Duration_s;
        attribute averageCurrent : Current_mA;
        attribute averageImpedance : Resistance_ohm;
        attribute completedNormally : Boolean;
        attribute finalFault : FaultCode;
    }

    port def PowerSourcePort {
        out item power : ElectricalPower;
    }

    port def PowerLoadPort {
        in item power : ElectricalPower;
    }

    port def UserPanelDevicePort {
        out item command : UserCommand;
        in item indication : UserIndication;
    }

    port def UserPanelControllerPort {
        in item command : UserCommand;
        out item indication : UserIndication;
    }

    port def ControllerStimulatorPort {
        out item command : StimulationCommand;
        in item status : StimulationStatus;
    }

    port def StimulatorControllerPort {
        in item command : StimulationCommand;
        out item status : StimulationStatus;
    }

    port def StimulatorElectrodePort {
        out item pulse : BiphasicElectricalPulse;
        in item contact : ElectrodeContactMeasurement;
    }

    port def ElectrodeStimulatorPort {
        in item pulse : BiphasicElectricalPulse;
        out item contact : ElectrodeContactMeasurement;
    }

    port def ElectrodeTissuePort {
        out item coupling : ElectricFieldCoupling;
        in item response : NeuralModulationResponse;
    }

    port def TissueInterfacePort {
        in item coupling : ElectricFieldCoupling;
        out item response : NeuralModulationResponse;
    }

    action def VerifyElectrodeContact {
        in item measurement : ElectrodeContactMeasurement;
        out item acceptable : Boolean;
    }

    action def ComputeTherapyPrescription {
        in item command : UserCommand;
        out item prescription : TherapyPrescription;
    }

    action def GenerateBalancedBiphasicPulseTrain {
        in item prescription : TherapyPrescription;
        out item pulse : BiphasicElectricalPulse;
    }

    action def MonitorTherapySafety {
        in item status : StimulationStatus;
        in item contact : ElectrodeContactMeasurement;
        out item safeToContinue : Boolean;
        out item fault : FaultCode;
    }

    action def SummarizeTherapySession {
        in item status : StimulationStatus;
        in item contact : ElectrodeContactMeasurement;
        out item report : TherapySessionReport;
    }

    action def AdministerTrigeminalNerveStimulation {
        in item command : UserCommand;
        in item contact : ElectrodeContactMeasurement;
        in item status : StimulationStatus;
        out item stimulationCommand : StimulationCommand;
        out item indication : UserIndication;
        out item report : TherapySessionReport;

        action computePrescription : ComputeTherapyPrescription;
        action verifyContact : VerifyElectrodeContact;
        action monitorSafety : MonitorTherapySafety;
        action summarizeSession : SummarizeTherapySession;
    }

    state def TherapyOperatingStateMachine {
        in item userCommand : UserCommand;
        in item stimulationStatus : StimulationStatus;
        in item contactMeasurement : ElectrodeContactMeasurement;
        out item userIndication : UserIndication;

        entry; then poweredOff;

        state poweredOff;
        state standby;
        state selfTest;
        state contactCheck;
        state stimulationActive;
        state paused;
        state completed;
        state faulted;

        transition powerOn first poweredOff then selfTest;
        transition selfTestPassed first selfTest then standby;
        transition selfTestFailed first selfTest then faulted;
        transition requestTherapy first standby then contactCheck;
        transition contactAcceptable first contactCheck then stimulationActive;
        transition contactNotAcceptable first contactCheck then standby;
        transition pauseTherapy first stimulationActive then paused;
        transition resumeTherapy first paused then contactCheck;
        transition stopTherapy first stimulationActive then completed;
        transition completeTherapy first stimulationActive then completed;
        transition resetCompleted first completed then standby;
        transition detectFaultFromStandby first standby then faulted;
        transition detectFaultFromActive first stimulationActive then faulted;
        transition resetFault first faulted then standby;
        transition powerOffFromStandby first standby then poweredOff;
        transition powerOffFromFault first faulted then poweredOff;
    }

    part def RechargeableBattery {
        port powerOut : PowerSourcePort;

        attribute nominalVoltage : Voltage_V = 3.7;
        attribute fullChargeEnergy : Energy_Wh = 7.4;
        attribute lowBatteryThreshold : Voltage_V = 3.3;
    }

    part def UserInterface {
        port controllerPort : UserPanelDevicePort;

        attribute hasStartPauseStopControl : Boolean = true;
        attribute hasIntensityAdjustment : Boolean = true;
        attribute hasContactIndicator : Boolean = true;
        attribute hasFaultIndicator : Boolean = true;
    }

    part def TherapyController {
        port powerIn : PowerLoadPort;
        port userInterface : UserPanelControllerPort;
        port stimulator : ControllerStimulatorPort;

        attribute primaryFunction : String = "Noninvasively deliver controlled charge-balanced electrical pulses through forehead electrodes to stimulate trigeminal nerve branches and modulate neural activity at a therapeutic level.";
        attribute defaultAmplitude : Current_mA = 8.0;
        attribute maximumAmplitude : Current_mA = 16.0;
        attribute minimumAmplitude : Current_mA = 0.5;
        attribute defaultPulseWidth : Duration_ms = 0.25;
        attribute defaultFrequency : Frequency_Hz = 120.0;
        attribute maximumSessionDuration : Duration_s = 1800.0;
        attribute activeMode : TherapyMode = TherapyMode::poweredOff;

        state operatingState : TherapyOperatingStateMachine;
        action administerTherapy : AdministerTrigeminalNerveStimulation;
    }

    part def ConstantCurrentPulseGenerator {
        port powerIn : PowerLoadPort;
        port controller : StimulatorControllerPort;
        port electrodeInterface : StimulatorElectrodePort;

        attribute complianceVoltage : Voltage_V = 45.0;
        attribute maximumOutputCurrent : Current_mA = 16.0;
        attribute minimumOutputCurrent : Current_mA = 0.5;
        attribute minimumPulseWidth : Duration_ms = 0.05;
        attribute maximumPulseWidth : Duration_ms = 0.5;
        attribute minimumFrequency : Frequency_Hz = 20.0;
        attribute maximumFrequency : Frequency_Hz = 150.0;
        attribute chargeBalancedOutput : Boolean = true;

        action generatePulseTrain : GenerateBalancedBiphasicPulseTrain;
    }

    part def ForeheadElectrodeArray {
        port stimulatorInterface : ElectrodeStimulatorPort;
        port tissueInterface : ElectrodeTissuePort;

        attribute electrodeCount : Integer = 2;
        attribute placementDescription : String = "Bilateral supraorbital/supratrochlear forehead placement over ophthalmic trigeminal branches.";
        attribute hydrogelContactArea_cm2 : Real = 8.0;
        attribute nominalContactImpedance : Resistance_ohm = 2500.0;
        attribute maximumAllowedSkinTemperature : Temperature_C = 41.0;
    }

    part def TrigeminalNerveTarget {
        port tissueInterface : TissueInterfacePort;

        attribute anatomicalTarget : String = "Ophthalmic division branches of the trigeminal nerve near supraorbital and supratrochlear paths.";
        attribute stimulationIsNonInvasive : Boolean = true;
        attribute intendedPhysiologicalEffect : String = "Modulation of sensory neural activity associated with pain pathway signaling.";
    }

    part def SafetySupervisor {
        port powerIn : PowerLoadPort;
        port stimulatorMonitor : ControllerStimulatorPort;

        attribute maximumSafeCurrent : Current_mA = 16.0;
        attribute maximumSafeVoltage : Voltage_V = 45.0;
        attribute minimumSafeContactImpedance : Resistance_ohm = 500.0;
        attribute maximumSafeContactImpedance : Resistance_ohm = 10000.0;
        attribute maximumSafeSkinTemperature : Temperature_C = 41.0;
        attribute outputShutdownOnFault : Boolean = true;

        action monitorSafety : MonitorTherapySafety;
    }

    part def TrigeminalNerveStimulationSystem {
        doc /* Primary high-level function: provide non-invasive trigeminal nerve stimulation by controlling charge-balanced biphasic current pulses delivered through forehead electrodes to modulate trigeminal sensory neural activity while monitoring contact quality and safety limits. */

        port externalPowerInput : PowerLoadPort;

        part battery : RechargeableBattery;
        part userInterface : UserInterface;
        part therapyController : TherapyController;
        part pulseGenerator : ConstantCurrentPulseGenerator;
        part electrodeArray : ForeheadElectrodeArray;
        part trigeminalTarget : TrigeminalNerveTarget;
        part safetySupervisor : SafetySupervisor;

        attribute primaryFunction : String = "Noninvasively stimulate trigeminal nerve branches using controlled, charge-balanced electrical pulses delivered through forehead electrodes.";
        attribute nominalTherapyAmplitude : Current_mA = 8.0;
        attribute maximumTherapyAmplitude : Current_mA = 16.0;
        attribute nominalPulseWidth : Duration_ms = 0.25;
        attribute nominalPulseFrequency : Frequency_Hz = 120.0;
        attribute maximumSessionDuration : Duration_s = 1800.0;
        attribute nonInvasiveApplication : Boolean = true;

        connect externalPowerInput to therapyController.powerIn;
        connect battery.powerOut to therapyController.powerIn;
        connect battery.powerOut to pulseGenerator.powerIn;
        connect battery.powerOut to safetySupervisor.powerIn;
        connect userInterface.controllerPort to therapyController.userInterface;
        connect therapyController.stimulator to pulseGenerator.controller;
        connect pulseGenerator.electrodeInterface to electrodeArray.stimulatorInterface;
        connect electrodeArray.tissueInterface to trigeminalTarget.tissueInterface;
        connect safetySupervisor.stimulatorMonitor to pulseGenerator.controller;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall noninvasively deliver controlled, charge-balanced, biphasic electrical stimulation through forehead electrodes to stimulate trigeminal nerve branches and modulate neural activity for therapy. */

        subject tns : TrigeminalNerveStimulationSystem;

        require constraint nonInvasive {
            tns.nonInvasiveApplication == true
        }

        require constraint chargeBalancedCurrentLimitedTherapy {
            tns.maximumTherapyAmplitude <= 16.0
        }

        require constraint typicalTherapyFrequencyRange {
            tns.nominalPulseFrequency >= 20.0 and tns.nominalPulseFrequency <= 150.0
        }

        require constraint sessionDurationLimited {
            tns.maximumSessionDuration <= 1800.0
        }
    }

    requirement def ElectrodeSafetyRequirement {
        doc /* The system shall inhibit or stop stimulation when electrode contact is open, shorted, excessively high impedance, or associated with excessive skin temperature. */

        subject tns : TrigeminalNerveStimulationSystem;

        require constraint impedanceLowerBound {
            tns.safetySupervisor.minimumSafeContactImpedance >= 500.0
        }

        require constraint impedanceUpperBound {
            tns.safetySupervisor.maximumSafeContactImpedance <= 10000.0
        }

        require constraint skinTemperatureBound {
            tns.safetySupervisor.maximumSafeSkinTemperature <= 41.0
        }
    }

    requirement def OutputParameterRequirement {
        doc /* The pulse generator shall provide programmable constant-current stimulation within bounded amplitude, pulse-width, and frequency limits. */

        subject generator : ConstantCurrentPulseGenerator;

        require constraint currentBound {
            generator.maximumOutputCurrent <= 16.0
        }

        require constraint pulseWidthBound {
            generator.maximumPulseWidth <= 0.5
        }

        require constraint frequencyBound {
            generator.maximumFrequency <= 150.0
        }

        require constraint chargeBalanced {
            generator.chargeBalancedOutput == true
        }
    }

    part tnsSystem : TrigeminalNerveStimulationSystem;

    requirement primaryFunctionRequirement : PrimaryFunctionRequirement {
        subject tns = tnsSystem;
    }

    requirement electrodeSafetyRequirement : ElectrodeSafetyRequirement {
        subject tns = tnsSystem;
    }

    requirement outputParameterRequirement : OutputParameterRequirement {
        subject generator = tnsSystem.pulseGenerator;
    }
}
