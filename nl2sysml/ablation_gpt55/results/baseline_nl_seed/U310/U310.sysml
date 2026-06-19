package MicrocurrentNeuromuscularStimulatorModel {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def VoltageValue :> ISQ::electricPotential {
        :>> unit = SI::V;
    }

    attribute def CurrentValue :> ISQ::electricCurrent {
        :>> unit = SI::A;
    }

    attribute def TimeValue :> ISQ::duration {
        :>> unit = SI::s;
    }

    attribute def FrequencyValue :> ISQ::frequency {
        :>> unit = SI::Hz;
    }

    attribute def ResistanceValue :> ISQ::resistance {
        :>> unit = SI::ohm;
    }

    attribute def PowerValue :> ISQ::power {
        :>> unit = SI::W;
    }

    attribute def EnergyValue :> ISQ::energy {
        :>> unit = SI::J;
    }

    attribute def TemperatureValue :> ISQ::thermodynamicTemperature {
        :>> unit = SI::K;
    }

    attribute def FractionValue :> ScalarValues::Real;

    enum def TherapyModeKind {
        enum painModulation;
        enum muscleReeducation;
        enum recoverySupport;
        enum edemaReduction;
    }

    enum def SessionStateKind {
        enum off;
        enum selfTest;
        enum idle;
        enum ready;
        enum deliveringTherapy;
        enum paused;
        enum fault;
        enum charging;
    }

    enum def LeadConditionKind {
        enum connected;
        enum highImpedance;
        enum openCircuit;
        enum shortCircuit;
    }

    enum def FaultKind {
        enum noFault;
        enum lowBattery;
        enum electrodeOpen;
        enum electrodeShort;
        enum overCurrent;
        enum overVoltage;
        enum excessiveSkinImpedance;
        enum internalSelfTestFailure;
        enum overTemperature;
    }

    item def DcElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute power : PowerValue;
    }

    item def TherapyProgram {
        attribute mode : TherapyModeKind;
        attribute targetAmplitude : CurrentValue;
        attribute maximumAmplitude : CurrentValue;
        attribute pulseWidth : TimeValue;
        attribute pulseFrequency : FrequencyValue;
        attribute sessionDuration : TimeValue;
        attribute rampUpDuration : TimeValue;
        attribute rampDownDuration : TimeValue;
        attribute dutyCycle : FractionValue;
    }

    item def TherapyCommand {
        attribute requestedState : SessionStateKind;
        attribute requestedAmplitude : CurrentValue;
        attribute requestedDuration : TimeValue;
    }

    item def DeviceStatus {
        attribute currentState : SessionStateKind;
        attribute activeFault : FaultKind;
        attribute batteryStateOfCharge : FractionValue;
        attribute measuredSkinImpedance : ResistanceValue;
        attribute deliveredCurrent : CurrentValue;
        attribute remainingSessionTime : TimeValue;
    }

    item def ElectrodeContact {
        attribute leadCondition : LeadConditionKind;
        attribute skinImpedance : ResistanceValue;
        attribute contactVoltage : VoltageValue;
    }

    item def MicrocurrentPulse {
        attribute amplitude : CurrentValue;
        attribute pulseWidth : TimeValue;
        attribute polarityPositive : Boolean;
        attribute interPulseInterval : TimeValue;
    }

    item def MicrocurrentPulseTrain {
        attribute amplitude : CurrentValue;
        attribute pulseWidth : TimeValue;
        attribute frequency : FrequencyValue;
        attribute duration : TimeValue;
        attribute maximumComplianceVoltage : VoltageValue;
    }

    item def UserInput {
        attribute selectedMode : TherapyModeKind;
        attribute requestedAmplitude : CurrentValue;
        attribute requestedDuration : TimeValue;
        attribute startRequested : Boolean;
        attribute pauseRequested : Boolean;
        attribute stopRequested : Boolean;
    }

    item def DisplayInformation {
        attribute displayedState : SessionStateKind;
        attribute displayedAmplitude : CurrentValue;
        attribute displayedTimeRemaining : TimeValue;
        attribute displayedFault : FaultKind;
        attribute displayedBatteryStateOfCharge : FractionValue;
    }

    port def DcPowerInputPort {
        in item dcPower : DcElectricalPower;
    }

    port def DcPowerOutputPort {
        out item dcPower : DcElectricalPower;
    }

    port def TherapyProgramInputPort {
        in item program : TherapyProgram;
    }

    port def CommandInputPort {
        in item command : TherapyCommand;
    }

    port def StatusOutputPort {
        out item status : DeviceStatus;
    }

    port def UserInputPort {
        in item input : UserInput;
    }

    port def DisplayOutputPort {
        out item display : DisplayInformation;
    }

    port def PulseOutputPort {
        out item pulseTrain : MicrocurrentPulseTrain;
        in item contact : ElectrodeContact;
    }

    port def ElectrodeTerminalPort {
        out item pulse : MicrocurrentPulse;
        in item contact : ElectrodeContact;
    }

    port def MeasurementOutputPort {
        out item contact : ElectrodeContact;
    }

    port def MeasurementInputPort {
        in item contact : ElectrodeContact;
    }

    port def ControlOutputPort {
        out item command : TherapyCommand;
    }

    port def ControlInputPort {
        in item command : TherapyCommand;
    }

    port def FaultOutputPort {
        out item faultStatus : DeviceStatus;
    }

    port def FaultInputPort {
        in item faultStatus : DeviceStatus;
    }

    constraint def SafeCurrentLimit {
        in deliveredCurrent : CurrentValue;
        in maximumSafeCurrent : CurrentValue;
        constraint { deliveredCurrent <= maximumSafeCurrent }
    }

    constraint def ComplianceVoltageLimit {
        in complianceVoltage : VoltageValue;
        in maximumComplianceVoltage : VoltageValue;
        constraint { complianceVoltage <= maximumComplianceVoltage }
    }

    constraint def ElectrodeImpedanceOperatingRange {
        in measuredImpedance : ResistanceValue;
        in minimumAllowedImpedance : ResistanceValue;
        in maximumAllowedImpedance : ResistanceValue;
        constraint { measuredImpedance >= minimumAllowedImpedance and measuredImpedance <= maximumAllowedImpedance }
    }

    constraint def BatteryEnergySufficientForSession {
        in availableEnergy : EnergyValue;
        in requiredEnergy : EnergyValue;
        constraint { availableEnergy >= requiredEnergy }
    }

    action def RunPowerOnSelfTest {
        in item suppliedPower : DcElectricalPower;
        out item selfTestStatus : DeviceStatus;
    }

    action def MeasureElectrodeContact {
        in item deliveredProbePulse : MicrocurrentPulse;
        out item measuredContact : ElectrodeContact;
    }

    action def ValidateTherapyProgram {
        in item requestedProgram : TherapyProgram;
        in item measuredContact : ElectrodeContact;
        out item acceptedProgram : TherapyProgram;
        out item validationStatus : DeviceStatus;
    }

    action def GenerateTherapyPulseTrain {
        in item acceptedProgram : TherapyProgram;
        in item measuredContact : ElectrodeContact;
        out item generatedPulseTrain : MicrocurrentPulseTrain;
    }

    action def RegulateOutputCurrent {
        in item generatedPulseTrain : MicrocurrentPulseTrain;
        in item measuredContact : ElectrodeContact;
        out item regulatedPulseTrain : MicrocurrentPulseTrain;
        out item regulationStatus : DeviceStatus;
    }

    action def DeliverRegulatedMicrocurrent {
        in item regulatedPulseTrain : MicrocurrentPulseTrain;
        out item electrodeContactFeedback : ElectrodeContact;
    }

    action def StopOutputSafely {
        in item currentStatus : DeviceStatus;
        out item stoppedStatus : DeviceStatus;
    }

    action def ExecuteTherapySession {
        in item requestedProgram : TherapyProgram;
        in item initialContact : ElectrodeContact;
        out item sessionStatus : DeviceStatus;

        action validate : ValidateTherapyProgram;
        action generate : GenerateTherapyPulseTrain;
        action regulate : RegulateOutputCurrent;
        action deliver : DeliverRegulatedMicrocurrent;
        action stop : StopOutputSafely;

        flow requestedProgram to validate.requestedProgram;
        flow initialContact to validate.measuredContact;
        flow validate.acceptedProgram to generate.acceptedProgram;
        flow initialContact to generate.measuredContact;
        flow generate.generatedPulseTrain to regulate.generatedPulseTrain;
        flow initialContact to regulate.measuredContact;
        flow regulate.regulatedPulseTrain to deliver.regulatedPulseTrain;
        flow regulate.regulationStatus to stop.currentStatus;
        flow stop.stoppedStatus to sessionStatus;
    }

    state def StimulatorOperatingStateMachine {
        entry; then off;

        state off;
        state selfTest;
        state idle;
        state ready;
        state deliveringTherapy;
        state paused;
        state fault;
        state charging;

        transition powerOn
            first off
            then selfTest;

        transition selfTestPassed
            first selfTest
            then idle;

        transition selfTestFailed
            first selfTest
            then fault;

        transition programAccepted
            first idle
            then ready;

        transition startTherapy
            first ready
            then deliveringTherapy;

        transition pauseTherapy
            first deliveringTherapy
            then paused;

        transition resumeTherapy
            first paused
            then deliveringTherapy;

        transition completeTherapy
            first deliveringTherapy
            then idle;

        transition stopFromReady
            first ready
            then idle;

        transition faultDuringTherapy
            first deliveringTherapy
            then fault;

        transition faultFromPaused
            first paused
            then fault;

        transition clearFault
            first fault
            then idle;

        transition beginCharging
            first off
            then charging;

        transition endCharging
            first charging
            then off;
    }

    part def RechargeableBattery {
        port dcOut : DcPowerOutputPort;

        attribute nominalVoltage : VoltageValue = 3.7;
        attribute maximumVoltage : VoltageValue = 4.2;
        attribute minimumOperatingVoltage : VoltageValue = 3.2;
        attribute capacityEnergy : EnergyValue = 28800.0;
        attribute stateOfCharge : FractionValue = 1.0;
        attribute maximumDischargeCurrent : CurrentValue = 1.5;
        attribute maximumChargeCurrent : CurrentValue = 0.75;
    }

    part def BatteryCharger {
        port dcIn : DcPowerInputPort;
        port batteryDcOut : DcPowerOutputPort;

        attribute inputVoltage : VoltageValue = 5.0;
        attribute regulatedChargeVoltage : VoltageValue = 4.2;
        attribute chargeTerminationCurrent : CurrentValue = 0.05;
        attribute maximumChargePower : PowerValue = 5.0;
    }

    part def PowerManagementUnit {
        port batteryIn : DcPowerInputPort;
        port chargerIn : DcPowerInputPort;
        port regulatedOut : DcPowerOutputPort;

        attribute regulatedLogicVoltage : VoltageValue = 3.3;
        attribute regulatedStimulusRailVoltage : VoltageValue = 30.0;
        attribute quiescentPower : PowerValue = 0.08;
        attribute conversionEfficiency : FractionValue = 0.87;
        attribute undervoltageThreshold : VoltageValue = 3.2;
    }

    part def UserInterface {
        port userIn : UserInputPort;
        port commandOut : ControlOutputPort;
        port statusIn : FaultInputPort;
        port displayOut : DisplayOutputPort;

        attribute minimumSelectableAmplitude : CurrentValue = 0.00001;
        attribute maximumSelectableAmplitude : CurrentValue = 0.0006;
        attribute amplitudeStep : CurrentValue = 0.00001;
        attribute minimumSessionDuration : TimeValue = 60.0;
        attribute maximumSessionDuration : TimeValue = 1800.0;
    }

    part def TherapyController {
        port powerIn : DcPowerInputPort;
        port userCommandIn : ControlInputPort;
        port programIn : TherapyProgramInputPort;
        port contactIn : MeasurementInputPort;
        port pulseCommandOut : ControlOutputPort;
        port statusOut : StatusOutputPort;

        attribute maximumAllowedCurrent : CurrentValue = 0.0006;
        attribute absoluteHardwareCurrentLimit : CurrentValue = 0.0010;
        attribute minimumAllowedImpedance : ResistanceValue = 500.0;
        attribute maximumAllowedImpedance : ResistanceValue = 20000.0;
        attribute defaultSessionDuration : TimeValue = 1200.0;
        attribute controllerLoopPeriod : TimeValue = 0.01;

        perform action selfTest : RunPowerOnSelfTest;
        perform action therapySession : ExecuteTherapySession;
        exhibit state operatingStates : StimulatorOperatingStateMachine;
    }

    part def PulseGenerator {
        port powerIn : DcPowerInputPort;
        port commandIn : ControlInputPort;
        port pulseOut : PulseOutputPort;
        port statusOut : StatusOutputPort;

        attribute amplitudeResolution : CurrentValue = 0.000001;
        attribute minimumPulseAmplitude : CurrentValue = 0.00001;
        attribute maximumPulseAmplitude : CurrentValue = 0.0006;
        attribute absoluteCurrentLimit : CurrentValue = 0.0010;
        attribute minimumPulseWidth : TimeValue = 0.00005;
        attribute maximumPulseWidth : TimeValue = 0.00100;
        attribute minimumFrequency : FrequencyValue = 0.5;
        attribute maximumFrequency : FrequencyValue = 300.0;
        attribute maximumComplianceVoltage : VoltageValue = 30.0;

        assert constraint currentLimit : SafeCurrentLimit {
            in deliveredCurrent = maximumPulseAmplitude;
            in maximumSafeCurrent = absoluteCurrentLimit;
        }

        assert constraint complianceLimit : ComplianceVoltageLimit {
            in complianceVoltage = maximumComplianceVoltage;
            in maximumComplianceVoltage = maximumComplianceVoltage;
        }
    }

    part def ElectrodeLeadAssembly {
        port stimulatorIn : PulseOutputPort;
        port positiveElectrode : ElectrodeTerminalPort;
        port negativeElectrode : ElectrodeTerminalPort;
        port measurementOut : MeasurementOutputPort;

        attribute leadResistance : ResistanceValue = 2.0;
        attribute maximumLeadCurrent : CurrentValue = 0.0010;
        attribute electrodeGelArea : ScalarValues::Real = 0.0009;
        attribute minimumSkinImpedance : ResistanceValue = 500.0;
        attribute maximumSkinImpedance : ResistanceValue = 20000.0;

        assert constraint impedanceRange : ElectrodeImpedanceOperatingRange {
            in measuredImpedance = maximumSkinImpedance;
            in minimumAllowedImpedance = minimumSkinImpedance;
            in maximumAllowedImpedance = maximumSkinImpedance;
        }
    }

    part def ImpedanceMonitor {
        port probeCommandIn : ControlInputPort;
        port electrodeMeasurementIn : MeasurementInputPort;
        port contactOut : MeasurementOutputPort;
        port statusOut : StatusOutputPort;

        attribute probeCurrent : CurrentValue = 0.00002;
        attribute probePulseWidth : TimeValue = 0.0001;
        attribute measurementPeriod : TimeValue = 1.0;
        attribute openCircuitThreshold : ResistanceValue = 20000.0;
        attribute shortCircuitThreshold : ResistanceValue = 500.0;

        perform action measureContact : MeasureElectrodeContact;
    }

    part def SafetySupervisor {
        port controllerStatusIn : FaultInputPort;
        port generatorStatusIn : FaultInputPort;
        port contactIn : MeasurementInputPort;
        port inhibitCommandOut : ControlOutputPort;
        port safetyStatusOut : StatusOutputPort;

        attribute maximumSafeCurrent : CurrentValue = 0.0010;
        attribute maximumSafeVoltage : VoltageValue = 30.0;
        attribute maximumSurfaceTemperature : TemperatureValue = 313.15;
        attribute faultReactionTime : TimeValue = 0.05;
        attribute latchingFaultRequired : Boolean = true;
    }

    part def MicrocurrentElectricalNeuromuscularStimulator {
        port chargePowerIn : DcPowerInputPort;
        port userInput : UserInputPort;
        port displayOutput : DisplayOutputPort;
        port therapyOutput : PulseOutputPort;
        port deviceStatus : StatusOutputPort;

        attribute prescribedProgram : TherapyProgram;
        attribute primaryOutputCurrent : CurrentValue = 0.0003;
        attribute maximumTherapeuticCurrent : CurrentValue = 0.0006;
        attribute absoluteCurrentLimit : CurrentValue = 0.0010;
        attribute nominalPulseWidth : TimeValue = 0.00025;
        attribute nominalPulseFrequency : FrequencyValue = 100.0;
        attribute nominalSessionDuration : TimeValue = 1200.0;
        attribute nominalComplianceVoltage : VoltageValue = 30.0;

        part battery : RechargeableBattery;
        part charger : BatteryCharger;
        part powerManagement : PowerManagementUnit;
        part userInterface : UserInterface;
        part controller : TherapyController;
        part pulseGenerator : PulseGenerator;
        part electrodeLeadAssembly : ElectrodeLeadAssembly;
        part impedanceMonitor : ImpedanceMonitor;
        part safetySupervisor : SafetySupervisor;

        connect chargePowerIn to charger.dcIn;
        connect charger.batteryDcOut to powerManagement.chargerIn;
        connect battery.dcOut to powerManagement.batteryIn;
        connect powerManagement.regulatedOut to controller.powerIn;
        connect powerManagement.regulatedOut to pulseGenerator.powerIn;

        connect userInput to userInterface.userIn;
        connect userInterface.displayOut to displayOutput;
        connect userInterface.commandOut to controller.userCommandIn;

        connect controller.pulseCommandOut to pulseGenerator.commandIn;
        connect pulseGenerator.pulseOut to electrodeLeadAssembly.stimulatorIn;
        connect electrodeLeadAssembly.stimulatorIn to therapyOutput;

        connect electrodeLeadAssembly.measurementOut to impedanceMonitor.electrodeMeasurementIn;
        connect impedanceMonitor.contactOut to controller.contactIn;
        connect impedanceMonitor.contactOut to safetySupervisor.contactIn;

        connect controller.statusOut to userInterface.statusIn;
        connect controller.statusOut to safetySupervisor.controllerStatusIn;
        connect pulseGenerator.statusOut to safetySupervisor.generatorStatusIn;
        connect safetySupervisor.safetyStatusOut to deviceStatus;
        connect safetySupervisor.inhibitCommandOut to pulseGenerator.commandIn;

        assert constraint systemCurrentLimit : SafeCurrentLimit {
            in deliveredCurrent = maximumTherapeuticCurrent;
            in maximumSafeCurrent = absoluteCurrentLimit;
        }
    }

    requirement def HighLevelPrimaryFunctionRequirement {
        doc /* The device shall provide non-invasive neuromuscular stimulation by delivering controlled microampere-level electrical pulse trains through surface electrodes to targeted tissue while monitoring contact quality and limiting output for user safety. */
        subject stimulator : MicrocurrentElectricalNeuromuscularStimulator;
        require constraint {
            stimulator.maximumTherapeuticCurrent <= stimulator.absoluteCurrentLimit
        }
    }

    requirement def MicrocurrentAmplitudeRequirement {
        doc /* The delivered therapy current shall remain in the microcurrent range during normal therapy. */
        subject stimulator : MicrocurrentElectricalNeuromuscularStimulator;
        require constraint {
            stimulator.maximumTherapeuticCurrent <= 0.0006
        }
    }

    requirement def OutputSafetyRequirement {
        doc /* The hardware shall inhibit stimulation when electrode impedance indicates open-circuit, short-circuit, or excessive skin impedance conditions. */
        subject stimulator : MicrocurrentElectricalNeuromuscularStimulator;
        require constraint {
            stimulator.absoluteCurrentLimit <= 0.0010
        }
    }

    requirement def SessionControlRequirement {
        doc /* The system shall support a timed therapy session with selectable therapy mode, amplitude, pulse width, frequency, pause, stop, and automatic completion. */
        subject stimulator : MicrocurrentElectricalNeuromuscularStimulator;
        require constraint {
            stimulator.nominalSessionDuration <= 1800.0
        }
    }

    part microcurrentStimulator : MicrocurrentElectricalNeuromuscularStimulator {
        attribute :>> primaryOutputCurrent = 0.0003;
        attribute :>> maximumTherapeuticCurrent = 0.0006;
        attribute :>> absoluteCurrentLimit = 0.0010;
        attribute :>> nominalPulseWidth = 0.00025;
        attribute :>> nominalPulseFrequency = 100.0;
        attribute :>> nominalSessionDuration = 1200.0;
        attribute :>> nominalComplianceVoltage = 30.0;
    }

    requirement highLevelPrimaryFunction : HighLevelPrimaryFunctionRequirement {
        subject stimulator = microcurrentStimulator;
    }

    requirement microcurrentAmplitude : MicrocurrentAmplitudeRequirement {
        subject stimulator = microcurrentStimulator;
    }

    requirement outputSafety : OutputSafetyRequirement {
        subject stimulator = microcurrentStimulator;
    }

    requirement sessionControl : SessionControlRequirement {
        subject stimulator = microcurrentStimulator;
    }
}
