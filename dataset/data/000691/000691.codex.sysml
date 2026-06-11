package MicrocurrentNeuromuscularStimulatorModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def ElectricCurrentValue :> ISQ::electricCurrent {
        unit = SI::microA;
    }

    attribute def ElectricVoltageValue :> ISQ::electricPotential {
        unit = SI::V;
    }

    attribute def ElectricChargeValue :> ISQ::electricCharge {
        unit = SI::microC;
    }

    attribute def FrequencyValue :> ISQ::frequency {
        unit = SI::Hz;
    }

    attribute def TimeValue :> ISQ::time {
        unit = SI::s;
    }

    attribute def ResistanceValue :> ISQ::resistance {
        unit = SI::ohm;
    }

    attribute def TemperatureValue :> ISQ::thermodynamicTemperature {
        unit = SI::degC;
    }

    attribute def EnergyValue :> ISQ::energy {
        unit = SI::J;
    }

    enum def TherapyModeKind {
        enum off;
        enum painModulation;
        enum muscleRecovery;
        enum edemaReduction;
        enum woundSupport;
        enum custom;
    }

    enum def ElectrodeContactKind {
        enum disconnected;
        enum poor;
        enum acceptable;
        enum optimal;
    }

    enum def FaultKind {
        enum noFault;
        enum overCurrent;
        enum overVoltage;
        enum electrodeOpenCircuit;
        enum electrodeShortCircuit;
        enum lowBattery;
        enum overTemperature;
        enum controlProcessorFault;
        enum userEmergencyStop;
    }

    item def ElectricalEnergy {
        attribute voltage : ElectricVoltageValue;
        attribute current : ElectricCurrentValue;
        attribute energy : EnergyValue;
    }

    item def StimulationPulse {
        attribute amplitude : ElectricCurrentValue;
        attribute pulseWidth : TimeValue;
        attribute frequency : FrequencyValue;
        attribute polarityPositive : Boolean;
        attribute chargePerPhase : ElectricChargeValue;
    }

    item def ContactMeasurement {
        attribute skinElectrodeImpedance : ResistanceValue;
        attribute contactQuality : ElectrodeContactKind;
        attribute measuredAt : TimeValue;
    }

    item def TherapyCommand {
        attribute requestedMode : TherapyModeKind;
        attribute requestedAmplitude : ElectricCurrentValue;
        attribute requestedPulseWidth : TimeValue;
        attribute requestedFrequency : FrequencyValue;
        attribute requestedDuration : TimeValue;
    }

    item def TherapyStatus {
        attribute activeMode : TherapyModeKind;
        attribute deliveredAmplitude : ElectricCurrentValue;
        attribute elapsedTime : TimeValue;
        attribute remainingTime : TimeValue;
        attribute fault : FaultKind;
        attribute outputEnabled : Boolean;
    }

    item def BioelectricInterfaceSignal {
        attribute tissueCurrentDensity : ElectricCurrentValue;
        attribute perceivedIntensityLevel : Real;
        attribute neuromuscularActivationEstimate : Real;
    }

    port def PowerInputPort {
        in item powerIn : ElectricalEnergy;
    }

    port def PowerOutputPort {
        out item powerOut : ElectricalEnergy;
    }

    port def CommandInputPort {
        in item command : TherapyCommand;
    }

    port def StatusOutputPort {
        out item status : TherapyStatus;
    }

    port def PulseOutputPort {
        out item pulse : StimulationPulse;
    }

    port def ElectrodePort {
        out item therapeuticPulse : StimulationPulse;
        in item contactFeedback : ContactMeasurement;
    }

    port def TissueInterfacePort {
        in item appliedPulse : StimulationPulse;
        out item biologicalResponse : BioelectricInterfaceSignal;
    }

    part def RechargeableBattery {
        attribute nominalVoltage : ElectricVoltageValue = 3.7 [SI::V];
        attribute capacity : ElectricChargeValue = 2500000 [SI::microC];
        attribute remainingEnergy : EnergyValue;
        attribute lowBatteryThreshold : ElectricVoltageValue = 3.3 [SI::V];

        port powerOut : PowerOutputPort;
    }

    part def PowerManagementUnit {
        attribute regulatedLogicVoltage : ElectricVoltageValue = 3.3 [SI::V];
        attribute regulatedStimulusVoltageLimit : ElectricVoltageValue = 12.0 [SI::V];
        attribute converterEfficiency : Real = 0.88;

        port rawPowerIn : PowerInputPort;
        port logicPowerOut : PowerOutputPort;
        port stimulationPowerOut : PowerOutputPort;
    }

    part def UserInterface {
        attribute selectedMode : TherapyModeKind = TherapyModeKind::off;
        attribute selectedAmplitude : ElectricCurrentValue = 100 [SI::microA];
        attribute selectedPulseWidth : TimeValue = 0.5 [SI::s];
        attribute selectedFrequency : FrequencyValue = 0.5 [SI::Hz];
        attribute selectedDuration : TimeValue = 1200 [SI::s];

        port commandOut : CommandInputPort;
        port statusIn : StatusOutputPort;
    }

    part def TherapyController {
        attribute activeMode : TherapyModeKind = TherapyModeKind::off;
        attribute commandedAmplitude : ElectricCurrentValue = 100 [SI::microA];
        attribute commandedPulseWidth : TimeValue = 0.5 [SI::s];
        attribute commandedFrequency : FrequencyValue = 0.5 [SI::Hz];
        attribute commandedDuration : TimeValue = 1200 [SI::s];
        attribute elapsedTherapyTime : TimeValue = 0 [SI::s];
        attribute outputPermission : Boolean = false;
        attribute detectedFault : FaultKind = FaultKind::noFault;

        port commandIn : CommandInputPort;
        port statusOut : StatusOutputPort;
        port pulseCommandOut : PulseOutputPort;
        port contactMeasurementIn : ElectrodePort;
    }

    part def MicrocurrentPulseGenerator {
        attribute maximumAmplitude : ElectricCurrentValue = 600 [SI::microA];
        attribute minimumAmplitude : ElectricCurrentValue = 10 [SI::microA];
        attribute complianceVoltageLimit : ElectricVoltageValue = 12 [SI::V];
        attribute currentRegulationTolerance : Real = 0.05;
        attribute biphasicChargeBalanceTolerance : Real = 0.02;

        port stimulusPowerIn : PowerInputPort;
        port pulseCommandIn : PulseOutputPort;
        port electrodeDriveOut : PulseOutputPort;
    }

    part def ElectrodeLeadSet {
        attribute leadResistance : ResistanceValue = 2.0 [SI::ohm];
        attribute openCircuitImpedanceThreshold : ResistanceValue = 100000 [SI::ohm];
        attribute shortCircuitImpedanceThreshold : ResistanceValue = 100 [SI::ohm];

        port generatorIn : PulseOutputPort;
        port positiveElectrode : ElectrodePort;
        port negativeElectrode : ElectrodePort;
    }

    part def SkinElectrodePair {
        attribute gelInterfaceImpedance : ResistanceValue;
        attribute contactQuality : ElectrodeContactKind;
        attribute maximumSafeCurrent : ElectricCurrentValue = 600 [SI::microA];
        attribute skinTemperature : TemperatureValue;

        port leadConnection : ElectrodePort;
        port tissueConnection : TissueInterfacePort;
    }

    part def NeuromuscularTissueRegion {
        attribute baselineImpedance : ResistanceValue = 1000 [SI::ohm];
        attribute stimulatedImpedance : ResistanceValue;
        attribute activationThresholdEstimate : ElectricCurrentValue = 50 [SI::microA];
        attribute recoveryResponseIndex : Real;
        attribute painModulationResponseIndex : Real;

        port tissueSurface : TissueInterfacePort;
    }

    part def SafetyMonitor {
        attribute measuredOutputCurrent : ElectricCurrentValue;
        attribute measuredOutputVoltage : ElectricVoltageValue;
        attribute measuredElectrodeImpedance : ResistanceValue;
        attribute measuredTemperature : TemperatureValue;
        attribute currentLimit : ElectricCurrentValue = 650 [SI::microA];
        attribute voltageLimit : ElectricVoltageValue = 13 [SI::V];
        attribute temperatureLimit : TemperatureValue = 41 [SI::degC];
        attribute activeFault : FaultKind = FaultKind::noFault;

        port contactSenseIn : ElectrodePort;
        port statusOut : StatusOutputPort;
    }

    action def AcceptTherapyCommand {
        in item command : TherapyCommand;
        out attribute mode : TherapyModeKind;
        out attribute amplitude : ElectricCurrentValue;
        out attribute pulseWidth : TimeValue;
        out attribute frequency : FrequencyValue;
        out attribute duration : TimeValue;

        first start;
        then validateCommand;
        then assignTherapyParameters;
        then done;

        action validateCommand {
            assert constraint {
                command.requestedAmplitude >= 10 [SI::microA] and
                command.requestedAmplitude <= 600 [SI::microA] and
                command.requestedPulseWidth >= 0.05 [SI::s] and
                command.requestedPulseWidth <= 2.0 [SI::s] and
                command.requestedFrequency >= 0.1 [SI::Hz] and
                command.requestedFrequency <= 10 [SI::Hz] and
                command.requestedDuration >= 60 [SI::s] and
                command.requestedDuration <= 3600 [SI::s]
            }
        }

        action assignTherapyParameters {
            bind mode = command.requestedMode;
            bind amplitude = command.requestedAmplitude;
            bind pulseWidth = command.requestedPulseWidth;
            bind frequency = command.requestedFrequency;
            bind duration = command.requestedDuration;
        }
    }

    action def GenerateMicrocurrentPulse {
        in attribute amplitude : ElectricCurrentValue;
        in attribute pulseWidth : TimeValue;
        in attribute frequency : FrequencyValue;
        out item pulse : StimulationPulse;

        first start;
        then formPositivePhase;
        then formNegativeBalancingPhase;
        then publishPulse;
        then done;

        action formPositivePhase;
        action formNegativeBalancingPhase;
        action publishPulse {
            bind pulse.amplitude = amplitude;
            bind pulse.pulseWidth = pulseWidth;
            bind pulse.frequency = frequency;
            bind pulse.chargePerPhase = amplitude * pulseWidth;
        }
    }

    action def MeasureElectrodeContact {
        in attribute measuredImpedance : ResistanceValue;
        out item contact : ContactMeasurement;

        first start;
        then classifyContact;
        then done;

        action classifyContact {
            if measuredImpedance > 100000 [SI::ohm] then {
                bind contact.contactQuality = ElectrodeContactKind::disconnected;
            } else if measuredImpedance > 10000 [SI::ohm] then {
                bind contact.contactQuality = ElectrodeContactKind::poor;
            } else if measuredImpedance > 500 [SI::ohm] then {
                bind contact.contactQuality = ElectrodeContactKind::acceptable;
            } else {
                bind contact.contactQuality = ElectrodeContactKind::optimal;
            }
            bind contact.skinElectrodeImpedance = measuredImpedance;
        }
    }

    action def DisableStimulationOutput {
        out item status : TherapyStatus;

        first start;
        then openOutputSwitch;
        then setOutputDisabledStatus;
        then done;

        action openOutputSwitch;
        action setOutputDisabledStatus {
            bind status.outputEnabled = false;
        }
    }

    state def StimulatorOperatingStateMachine {
        attribute mode : TherapyModeKind;
        attribute fault : FaultKind;
        attribute outputEnabled : Boolean;

        state Off;
        state Ready;
        state ContactCheck;
        state TherapyActive;
        state Paused;
        state Faulted;
        state TherapyComplete;

        transition initial then Off;

        transition Off_to_Ready
            first Off
            accept TherapyCommand
            if mode != TherapyModeKind::off
            then Ready;

        transition Ready_to_ContactCheck
            first Ready
            accept TherapyCommand
            if fault == FaultKind::noFault
            then ContactCheck;

        transition ContactCheck_to_TherapyActive
            first ContactCheck
            if fault == FaultKind::noFault
            then TherapyActive {
                action enableOutput {
                    bind outputEnabled = true;
                }
            }

        transition ContactCheck_to_Faulted
            first ContactCheck
            if fault == FaultKind::electrodeOpenCircuit or fault == FaultKind::electrodeShortCircuit
            then Faulted;

        transition TherapyActive_to_Paused
            first TherapyActive
            accept TherapyCommand
            if mode == TherapyModeKind::off
            then Paused {
                action pauseOutput {
                    bind outputEnabled = false;
                }
            }

        transition Paused_to_TherapyActive
            first Paused
            accept TherapyCommand
            if mode != TherapyModeKind::off and fault == FaultKind::noFault
            then TherapyActive;

        transition TherapyActive_to_TherapyComplete
            first TherapyActive
            if mode != TherapyModeKind::off
            then TherapyComplete {
                action completeOutput {
                    bind outputEnabled = false;
                }
            }

        transition TherapyActive_to_Faulted
            first TherapyActive
            if fault != FaultKind::noFault
            then Faulted {
                action faultShutdown {
                    bind outputEnabled = false;
                }
            }

        transition Faulted_to_Ready
            first Faulted
            accept TherapyCommand
            if fault == FaultKind::noFault
            then Ready;

        transition TherapyComplete_to_Ready
            first TherapyComplete
            accept TherapyCommand
            if mode != TherapyModeKind::off
            then Ready;

        transition Ready_to_Off
            first Ready
            accept TherapyCommand
            if mode == TherapyModeKind::off
            then Off;
    }

    part def MicrocurrentElectricalNeuromuscularStimulator {
        doc /* A portable medical-electrical system whose primary high-level function is to deliver controlled, low-amplitude microcurrent stimulation through skin electrodes to a neuromuscular tissue region in order to support therapeutic modulation of pain, recovery, edema, or wound-related tissue response while maintaining output safety limits. */

        attribute systemMass : Real;
        attribute therapyMode : TherapyModeKind = TherapyModeKind::off;
        attribute prescribedAmplitude : ElectricCurrentValue = 100 [SI::microA];
        attribute prescribedPulseWidth : TimeValue = 0.5 [SI::s];
        attribute prescribedFrequency : FrequencyValue = 0.5 [SI::Hz];
        attribute prescribedDuration : TimeValue = 1200 [SI::s];
        attribute maximumOutputCurrent : ElectricCurrentValue = 600 [SI::microA];
        attribute maximumComplianceVoltage : ElectricVoltageValue = 12 [SI::V];

        port therapyCommandIn : CommandInputPort;
        port therapyStatusOut : StatusOutputPort;
        port tissueInterface : TissueInterfacePort;

        part battery : RechargeableBattery;
        part powerManagement : PowerManagementUnit;
        part userInterface : UserInterface;
        part controller : TherapyController;
        part pulseGenerator : MicrocurrentPulseGenerator;
        part leadSet : ElectrodeLeadSet;
        part electrodes : SkinElectrodePair;
        part targetTissue : NeuromuscularTissueRegion;
        part safetyMonitor : SafetyMonitor;

        connection batteryToPowerManagement
            connect battery.powerOut to powerManagement.rawPowerIn;

        connection logicPowerToController
            connect powerManagement.logicPowerOut to controller.commandIn;

        connection stimulationPowerToGenerator
            connect powerManagement.stimulationPowerOut to pulseGenerator.stimulusPowerIn;

        connection externalCommandToUserInterface
            connect therapyCommandIn to userInterface.commandOut;

        connection userInterfaceToController
            connect userInterface.commandOut to controller.commandIn;

        connection controllerStatusToUserInterface
            connect controller.statusOut to userInterface.statusIn;

        connection controllerStatusToExternal
            connect controller.statusOut to therapyStatusOut;

        connection controllerToPulseGenerator
            connect controller.pulseCommandOut to pulseGenerator.pulseCommandIn;

        connection pulseGeneratorToLeadSet
            connect pulseGenerator.electrodeDriveOut to leadSet.generatorIn;

        connection leadSetPositiveToElectrode
            connect leadSet.positiveElectrode to electrodes.leadConnection;

        connection leadSetNegativeToElectrode
            connect leadSet.negativeElectrode to electrodes.leadConnection;

        connection electrodeToTissue
            connect electrodes.tissueConnection to targetTissue.tissueSurface;

        connection tissueToExternalInterface
            connect targetTissue.tissueSurface to tissueInterface;

        connection electrodeFeedbackToSafetyMonitor
            connect electrodes.leadConnection to safetyMonitor.contactSenseIn;

        connection safetyStatusToController
            connect safetyMonitor.statusOut to controller.statusOut;

        perform action acceptCommand : AcceptTherapyCommand;
        perform action pulseFormation : GenerateMicrocurrentPulse;
        perform action contactMeasurement : MeasureElectrodeContact;
        perform action shutdownOutput : DisableStimulationOutput;

        exhibit state operatingState : StimulatorOperatingStateMachine;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The stimulator shall deliver regulated microcurrent electrical pulses through external electrodes to neuromuscular tissue for therapeutic modulation without intentionally producing macrocurrent muscle contraction. */
        subject stimulator : MicrocurrentElectricalNeuromuscularStimulator;

        require constraint {
            stimulator.maximumOutputCurrent <= 600 [SI::microA]
        }
    }

    requirement def ChargeBalancedOutputRequirement {
        doc /* The stimulator shall produce charge-balanced biphasic stimulation so that net delivered charge over each complete pulse cycle remains near zero. */
        subject stimulator : MicrocurrentElectricalNeuromuscularStimulator;

        require constraint {
            stimulator.pulseGenerator.biphasicChargeBalanceTolerance <= 0.02
        }
    }

    requirement def OutputCurrentLimitRequirement {
        doc /* The output stage shall limit stimulation current to a therapeutic microcurrent range under normal operation and detected fault conditions. */
        subject stimulator : MicrocurrentElectricalNeuromuscularStimulator;

        require constraint {
            stimulator.pulseGenerator.maximumAmplitude <= stimulator.maximumOutputCurrent
        }
    }

    requirement def ComplianceVoltageRequirement {
        doc /* The output stage shall not exceed the configured compliance voltage limit while driving the electrode-tissue load. */
        subject stimulator : MicrocurrentElectricalNeuromuscularStimulator;

        require constraint {
            stimulator.pulseGenerator.complianceVoltageLimit <= stimulator.maximumComplianceVoltage
        }
    }

    requirement def ElectrodeContactRequirement {
        doc /* The stimulator shall verify electrode contact quality before enabling therapy output and shall inhibit output for disconnected or shorted electrode conditions. */
        subject stimulator : MicrocurrentElectricalNeuromuscularStimulator;

        require constraint {
            stimulator.leadSet.openCircuitImpedanceThreshold == 100000 [SI::ohm] and
            stimulator.leadSet.shortCircuitImpedanceThreshold == 100 [SI::ohm]
        }
    }

    requirement def TherapyParameterRangeRequirement {
        doc /* The controller shall accept therapy settings only within the supported range for amplitude, pulse width, frequency, and duration. */
        subject stimulator : MicrocurrentElectricalNeuromuscularStimulator;

        require constraint {
            stimulator.prescribedAmplitude >= 10 [SI::microA] and
            stimulator.prescribedAmplitude <= 600 [SI::microA] and
            stimulator.prescribedPulseWidth >= 0.05 [SI::s] and
            stimulator.prescribedPulseWidth <= 2.0 [SI::s] and
            stimulator.prescribedFrequency >= 0.1 [SI::Hz] and
            stimulator.prescribedFrequency <= 10 [SI::Hz] and
            stimulator.prescribedDuration >= 60 [SI::s] and
            stimulator.prescribedDuration <= 3600 [SI::s]
        }
    }

    requirement def FaultShutdownRequirement {
        doc /* The stimulator shall disable stimulation output when overcurrent, overvoltage, open electrode, shorted electrode, low battery, overtemperature, processor fault, or emergency stop is detected. */
        subject stimulator : MicrocurrentElectricalNeuromuscularStimulator;

        require constraint {
            stimulator.safetyMonitor.currentLimit <= 650 [SI::microA] and
            stimulator.safetyMonitor.voltageLimit <= 13 [SI::V] and
            stimulator.safetyMonitor.temperatureLimit <= 41 [SI::degC]
        }
    }

    requirement def UserStatusRequirement {
        doc /* The stimulator shall report active mode, delivered amplitude, elapsed time, remaining time, fault state, and output enable state to the user interface during operation. */
        subject stimulator : MicrocurrentElectricalNeuromuscularStimulator;
    }

    requirement def PortablePowerRequirement {
        doc /* The stimulator shall operate from an internal rechargeable battery and provide regulated logic and stimulation supply rails. */
        subject stimulator : MicrocurrentElectricalNeuromuscularStimulator;

        require constraint {
            stimulator.battery.nominalVoltage == 3.7 [SI::V] and
            stimulator.powerManagement.regulatedLogicVoltage == 3.3 [SI::V]
        }
    }

    satisfy PrimaryFunctionRequirement by MicrocurrentElectricalNeuromuscularStimulator;
    satisfy ChargeBalancedOutputRequirement by MicrocurrentElectricalNeuromuscularStimulator::pulseGenerator;
    satisfy OutputCurrentLimitRequirement by MicrocurrentElectricalNeuromuscularStimulator::pulseGenerator;
    satisfy ComplianceVoltageRequirement by MicrocurrentElectricalNeuromuscularStimulator::pulseGenerator;
    satisfy ElectrodeContactRequirement by MicrocurrentElectricalNeuromuscularStimulator::leadSet;
    satisfy TherapyParameterRangeRequirement by MicrocurrentElectricalNeuromuscularStimulator::controller;
    satisfy FaultShutdownRequirement by MicrocurrentElectricalNeuromuscularStimulator::safetyMonitor;
    satisfy UserStatusRequirement by MicrocurrentElectricalNeuromuscularStimulator::userInterface;
    satisfy PortablePowerRequirement by MicrocurrentElectricalNeuromuscularStimulator::powerManagement;

    analysis def TherapyDeliveryAnalysis {
        subject stimulator : MicrocurrentElectricalNeuromuscularStimulator;

        objective {
            doc /* Estimate whether commanded stimulation remains within microcurrent therapeutic limits while maintaining electrode contact and charge balance. */
        }

        return attribute currentMargin : ElectricCurrentValue;
        return attribute voltageMargin : ElectricVoltageValue;

        constraint currentSafetyMargin {
            currentMargin == stimulator.maximumOutputCurrent - stimulator.prescribedAmplitude
        }

        constraint voltageSafetyMargin {
            voltageMargin == stimulator.maximumComplianceVoltage - stimulator.pulseGenerator.complianceVoltageLimit
        }
    }

    verification def OutputSafetyVerification {
        subject stimulator : MicrocurrentElectricalNeuromuscularStimulator;

        objective {
            doc /* Verify that stimulation output is disabled for unsafe current, unsafe voltage, invalid contact, high temperature, or emergency stop fault conditions. */
        }

        verify FaultShutdownRequirement;
        verify OutputCurrentLimitRequirement;
        verify ElectrodeContactRequirement;
    }

    verification def PrimaryFunctionVerification {
        subject stimulator : MicrocurrentElectricalNeuromuscularStimulator;

        objective {
            doc /* Verify that a valid therapy command causes the controller, pulse generator, lead set, and electrodes to deliver microcurrent stimulation to the neuromuscular tissue interface. */
        }

        verify PrimaryFunctionRequirement;
        verify TherapyParameterRangeRequirement;
        verify ChargeBalancedOutputRequirement;
    }

}