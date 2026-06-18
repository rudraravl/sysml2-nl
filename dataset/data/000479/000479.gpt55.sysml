package NeurostimulationPrimaryFunctionModel {
    import ScalarValues::*;

    enum def TherapyMode {
        enum tonic;
        enum burst;
        enum closedLoopAdaptive;
        enum testOnly;
    }

    enum def TherapyStateKind {
        enum poweredOff;
        enum standby;
        enum configuring;
        enum therapyActive;
        enum charging;
        enum suspended;
        enum fault;
        enum mriSafe;
    }

    enum def ElectrodeContactRole {
        enum cathode;
        enum anode;
        enum highImpedance;
        enum sensing;
    }

    enum def FaultSeverity {
        enum advisory;
        enum recoverable;
        enum therapyInhibited;
        enum critical;
    }

    attribute def Current_mA :> Real {
        attribute unit : String = "mA";
    }

    attribute def Voltage_V :> Real {
        attribute unit : String = "V";
    }

    attribute def PulseWidth_us :> Real {
        attribute unit : String = "us";
    }

    attribute def Frequency_Hz :> Real {
        attribute unit : String = "Hz";
    }

    attribute def Impedance_Ohm :> Real {
        attribute unit : String = "ohm";
    }

    attribute def Charge_uC :> Real {
        attribute unit : String = "uC";
    }

    attribute def ChargeDensity_uC_per_mm2 :> Real {
        attribute unit : String = "uC/mm^2";
    }

    attribute def Area_mm2 :> Real {
        attribute unit : String = "mm^2";
    }

    attribute def Time_s :> Real {
        attribute unit : String = "s";
    }

    attribute def Temperature_C :> Real {
        attribute unit : String = "degC";
    }

    attribute def BatteryPercent :> Real {
        attribute unit : String = "%";
    }

    attribute def DataRate_kbps :> Real {
        attribute unit : String = "kbps";
    }

    attribute def MagneticFluxDensity_T :> Real {
        attribute unit : String = "T";
    }

    attribute def NeuralSignal_uV :> Real {
        attribute unit : "uV";
    }

    item def TherapyProgram {
        attribute programIdentifier : String;
        attribute mode : TherapyMode;
        attribute nominalAmplitude : Current_mA;
        attribute maximumAmplitude : Current_mA;
        attribute pulseWidth : PulseWidth_us;
        attribute frequency : Frequency_Hz;
        attribute burstOnTime : Time_s;
        attribute burstOffTime : Time_s;
        attribute rampUpTime : Time_s;
        attribute rampDownTime : Time_s;
        attribute activeContactCount : Integer;
        attribute closedLoopEnabled : Boolean;
        attribute patientAdjustable : Boolean;
    }

    item def ElectrodeContactConfiguration {
        attribute contactNumber : Integer;
        attribute role : ElectrodeContactRole;
        attribute surfaceArea : Area_mm2;
        attribute measuredImpedance : Impedance_Ohm;
        attribute enabled : Boolean;
    }

    item def BiphasicPulseTrain {
        attribute amplitude : Current_mA;
        attribute complianceVoltage : Voltage_V;
        attribute pulseWidthPerPhase : PulseWidth_us;
        attribute interPhaseInterval : PulseWidth_us;
        attribute frequency : Frequency_Hz;
        attribute chargePerPhase : Charge_uC;
        attribute chargeBalanced : Boolean;
        attribute mode : TherapyMode;
    }

    item def NeuralTelemetry {
        attribute sensedFieldPotential : NeuralSignal_uV;
        attribute biomarkerLevel : Real;
        attribute stimulationArtifactDetected : Boolean;
        attribute timestamp : Time_s;
    }

    item def ElectrodeTelemetry {
        attribute contactNumber : Integer;
        attribute impedance : Impedance_Ohm;
        attribute deliveredCurrent : Current_mA;
        attribute deliveredVoltage : Voltage_V;
        attribute leadIntegrityOk : Boolean;
    }

    item def DeviceStatus {
        attribute therapyState : TherapyStateKind;
        attribute batteryStateOfCharge : BatteryPercent;
        attribute caseTemperature : Temperature_C;
        attribute activeProgramIdentifier : String;
        attribute faultPresent : Boolean;
        attribute faultSeverity : FaultSeverity;
        attribute remainingServiceLife : Time_s;
    }

    item def ProgrammerCommand {
        attribute commandIdentifier : String;
        attribute requestedMode : TherapyMode;
        attribute requestedAmplitude : Current_mA;
        attribute requestedPulseWidth : PulseWidth_us;
        attribute requestedFrequency : Frequency_Hz;
        attribute enableTherapy : Boolean;
        attribute authenticated : Boolean;
    }

    item def PatientControlRequest {
        attribute increaseAmplitude : Boolean;
        attribute decreaseAmplitude : Boolean;
        attribute suspendTherapy : Boolean;
        attribute resumeTherapy : Boolean;
        attribute requestedProgramIdentifier : String;
    }

    item def ChargingPower {
        attribute receivedPower : Real;
        attribute unit : String = "W";
        attribute couplingQuality : Real;
        attribute chargerTemperature : Temperature_C;
    }

    item def SafetyAlarm {
        attribute alarmIdentifier : String;
        attribute severity : FaultSeverity;
        attribute description : String;
        attribute therapyInhibited : Boolean;
    }

    port def StimulationPort {
        out item pulseTrain : BiphasicPulseTrain;
        in item electrodeTelemetry : ElectrodeTelemetry;
    }

    port def ElectrodeTissuePort {
        in item pulseTrain : BiphasicPulseTrain;
        out item neuralTelemetry : NeuralTelemetry;
        out item electrodeTelemetry : ElectrodeTelemetry;
    }

    port def WirelessProgrammingPort {
        in item command : ProgrammerCommand;
        out item status : DeviceStatus;
        out item alarm : SafetyAlarm;
    }

    port def PatientControlPort {
        in item request : PatientControlRequest;
        out item status : DeviceStatus;
    }

    port def RechargePort {
        in item power : ChargingPower;
        out item status : DeviceStatus;
    }

    port def NeuralSensePort {
        in item neuralTelemetry : NeuralTelemetry;
        out item sensingStatus : DeviceStatus;
    }

    constraint def PulseChargeLimit {
        in amplitude : Current_mA;
        in pulseWidth : PulseWidth_us;
        in chargePerPhase : Charge_uC;
        constraint chargeCalculation {
            chargePerPhase == amplitude * pulseWidth / 1000.0
        }
    }

    constraint def ChargeDensitySafetyLimit {
        in chargePerPhase : Charge_uC;
        in contactArea : Area_mm2;
        in maximumChargeDensity : ChargeDensity_uC_per_mm2;
        constraint densityLimit {
            chargePerPhase / contactArea <= maximumChargeDensity
        }
    }

    constraint def TherapyParameterEnvelope {
        in amplitude : Current_mA;
        in pulseWidth : PulseWidth_us;
        in frequency : Frequency_Hz;
        constraint envelope {
            amplitude >= 0.0 and amplitude <= 25.0 and
            pulseWidth >= 20.0 and pulseWidth <= 1000.0 and
            frequency >= 1.0 and frequency <= 1200.0
        }
    }

    constraint def ThermalSafetyLimit {
        in caseTemperature : Temperature_C;
        constraint temperatureLimit {
            caseTemperature <= 43.0
        }
    }

    action def AuthenticateProgrammerCommand {
        in item receivedCommand : ProgrammerCommand;
        out item acceptedCommand : ProgrammerCommand;
        out attribute authenticationPassed : Boolean;
    }

    action def ValidateTherapyProgram {
        in item candidateProgram : TherapyProgram;
        in item contactConfiguration : ElectrodeContactConfiguration;
        out item validatedProgram : TherapyProgram;
        out attribute programSafe : Boolean;
        assert constraint TherapyParameterEnvelope {
            in amplitude = candidateProgram.maximumAmplitude;
            in pulseWidth = candidateProgram.pulseWidth;
            in frequency = candidateProgram.frequency;
        }
    }

    action def SenseNeuralActivity {
        in item electrodeTelemetry : ElectrodeTelemetry;
        out item neuralTelemetry : NeuralTelemetry;
    }

    action def ComputeAdaptiveStimulus {
        in item program : TherapyProgram;
        in item neuralTelemetry : NeuralTelemetry;
        out item computedPulseTrain : BiphasicPulseTrain;
    }

    action def GenerateBiphasicPulseTrain {
        in item requestedPulseTrain : BiphasicPulseTrain;
        out item deliveredPulseTrain : BiphasicPulseTrain;
        assert constraint PulseChargeLimit {
            in amplitude = requestedPulseTrain.amplitude;
            in pulseWidth = requestedPulseTrain.pulseWidthPerPhase;
            in chargePerPhase = requestedPulseTrain.chargePerPhase;
        }
    }

    action def MonitorDeliverySafety {
        in item deliveredPulseTrain : BiphasicPulseTrain;
        in item electrodeTelemetry : ElectrodeTelemetry;
        in item status : DeviceStatus;
        out item alarm : SafetyAlarm;
        out attribute therapyAllowed : Boolean;
        assert constraint ThermalSafetyLimit {
            in caseTemperature = status.caseTemperature;
        }
    }

    action def ClosedLoopNeurostimulationSession {
        in item prescribedProgram : TherapyProgram;
        in item contactConfiguration : ElectrodeContactConfiguration;
        in item sensedTelemetry : NeuralTelemetry;
        in item electrodeTelemetry : ElectrodeTelemetry;
        in item deviceStatus : DeviceStatus;
        out item deliveredTherapy : BiphasicPulseTrain;
        out item reportedStatus : DeviceStatus;
        out item safetyAlarm : SafetyAlarm;

        action validateProgram : ValidateTherapyProgram {
            in candidateProgram = prescribedProgram;
            in contactConfiguration = contactConfiguration;
        }

        action computeStimulus : ComputeAdaptiveStimulus {
            in program = validateProgram.validatedProgram;
            in neuralTelemetry = sensedTelemetry;
        }

        action generatePulseTrain : GenerateBiphasicPulseTrain {
            in requestedPulseTrain = computeStimulus.computedPulseTrain;
            out deliveredPulseTrain = deliveredTherapy;
        }

        action monitorSafety : MonitorDeliverySafety {
            in deliveredPulseTrain = deliveredTherapy;
            in electrodeTelemetry = electrodeTelemetry;
            in status = deviceStatus;
            out alarm = safetyAlarm;
        }
    }

    state def NeurostimulatorOperatingStates {
        entry; then PoweredOff;

        state PoweredOff;
        state Standby;
        state Configuring;
        state TherapyActive;
        state Charging;
        state Suspended;
        state Fault;
        state MRISafe;

        transition powerOn
            first PoweredOff
            then Standby;

        transition receiveValidProgram
            first Standby
            then Configuring;

        transition configurationComplete
            first Configuring
            then TherapyActive;

        transition suspendRequested
            first TherapyActive
            then Suspended;

        transition resumeRequested
            first Suspended
            then TherapyActive;

        transition chargerDetected
            first Standby
            then Charging;

        transition chargeComplete
            first Charging
            then Standby;

        transition unsafeConditionDetected
            first TherapyActive
            then Fault;

        transition faultCleared
            first Fault
            then Standby;

        transition mriModeEnabled
            first Standby
            then MRISafe;

        transition mriModeDisabled
            first MRISafe
            then Standby;

        transition powerOff
            first Standby
            then PoweredOff;
    }

    part def ElectrodeContact {
        attribute contactNumber : Integer;
        attribute role : ElectrodeContactRole;
        attribute surfaceArea : Area_mm2 = 6.0;
        attribute nominalImpedance : Impedance_Ohm = 750.0;
        attribute maximumChargeDensity : ChargeDensity_uC_per_mm2 = 30.0;
        port tissueInterface : ElectrodeTissuePort;
    }

    part def ElectrodeArray {
        attribute contactCount : Integer = 8;
        part contact1 : ElectrodeContact {
            attribute contactNumber = 1;
            attribute role = cathode;
        }
        part contact2 : ElectrodeContact {
            attribute contactNumber = 2;
            attribute role = anode;
        }
        part contact3 : ElectrodeContact {
            attribute contactNumber = 3;
            attribute role = highImpedance;
        }
        part contact4 : ElectrodeContact {
            attribute contactNumber = 4;
            attribute role = highImpedance;
        }
        part contact5 : ElectrodeContact {
            attribute contactNumber = 5;
            attribute role = sensing;
        }
        part contact6 : ElectrodeContact {
            attribute contactNumber = 6;
            attribute role = sensing;
        }
        part contact7 : ElectrodeContact {
            attribute contactNumber = 7;
            attribute role = highImpedance;
        }
        part contact8 : ElectrodeContact {
            attribute contactNumber = 8;
            attribute role = highImpedance;
        }
        port arrayInterface : ElectrodeTissuePort;
    }

    part def ImplantableLead {
        attribute conductorCount : Integer = 8;
        attribute leadLength : Real = 600.0;
        attribute leadLengthUnit : String = "mm";
        attribute insulationMaterial : String = "medical grade polyurethane";
        port proximalConnector : StimulationPort;
        port distalElectrodes : ElectrodeTissuePort;
        part electrodeArray : ElectrodeArray;

        connection distalConnection connect distalElectrodes to electrodeArray.arrayInterface;
    }

    part def RechargeableBattery {
        attribute stateOfCharge : BatteryPercent = 80.0;
        attribute minimumTherapyStateOfCharge : BatteryPercent = 10.0;
        attribute nominalCapacity : Real = 1.8;
        attribute nominalCapacityUnit : String = "Ah";
        attribute nominalVoltage : Voltage_V = 3.7;
    }

    part def PulseGeneratorElectronics {
        attribute maximumOutputCurrent : Current_mA = 25.0;
        attribute maximumComplianceVoltage : Voltage_V = 12.0;
        attribute minimumPulseWidth : PulseWidth_us = 20.0;
        attribute maximumPulseWidth : PulseWidth_us = 1000.0;
        attribute minimumFrequency : Frequency_Hz = 1.0;
        attribute maximumFrequency : Frequency_Hz = 1200.0;
        port stimulationOutput : StimulationPort;
        port sensingInput : NeuralSensePort;
    }

    part def WirelessTelemetryModule {
        attribute programmingDataRate : DataRate_kbps = 250.0;
        attribute patientControlDataRate : DataRate_kbps = 50.0;
        attribute encryptionEnabled : Boolean = true;
        port programmerInterface : WirelessProgrammingPort;
        port patientInterface : PatientControlPort;
    }

    part def InductiveChargingModule {
        attribute maximumReceivedPower : Real = 2.5;
        attribute maximumReceivedPowerUnit : String = "W";
        attribute chargingEfficiency : Real = 0.72;
        port chargingInterface : RechargePort;
    }

    part def SafetySupervisor {
        attribute maximumCaseTemperature : Temperature_C = 43.0;
        attribute maximumMagneticFluxDensityForNormalMode : MagneticFluxDensity_T = 0.01;
        attribute therapyInhibited : Boolean = false;
        attribute leadIntegrityRequired : Boolean = true;
    }

    part def ImplantablePulseGenerator {
        doc /* Implantable component that stores therapy programs, generates charge-balanced electrical pulses, monitors electrodes and battery status, and communicates with external controllers. */

        attribute serialNumber : String = "NS-IPG-2048-0001";
        attribute activeState : TherapyStateKind = standby;
        attribute activeProgramId : String = "P1";
        attribute caseTemperature : Temperature_C = 36.5;

        item activeTherapyProgram : TherapyProgram {
            attribute programIdentifier = "P1";
            attribute mode = closedLoopAdaptive;
            attribute nominalAmplitude = 3.5;
            attribute maximumAmplitude = 8.0;
            attribute pulseWidth = 200.0;
            attribute frequency = 60.0;
            attribute burstOnTime = 5.0;
            attribute burstOffTime = 0.0;
            attribute rampUpTime = 2.0;
            attribute rampDownTime = 2.0;
            attribute activeContactCount = 2;
            attribute closedLoopEnabled = true;
            attribute patientAdjustable = true;
        }

        part battery : RechargeableBattery;
        part pulseElectronics : PulseGeneratorElectronics;
        part telemetry : WirelessTelemetryModule;
        part chargerReceiver : InductiveChargingModule;
        part safetySupervisor : SafetySupervisor;

        port stimulationPort : StimulationPort;
        port programmerPort : WirelessProgrammingPort;
        port patientPort : PatientControlPort;
        port rechargePort : RechargePort;
        port neuralSensePort : NeuralSensePort;

        state operatingBehavior : NeurostimulatorOperatingStates;

        action deliverTherapy : ClosedLoopNeurostimulationSession;

        connection pulseToCaseOutput connect pulseElectronics.stimulationOutput to stimulationPort;
        connection sensingToElectronics connect neuralSensePort to pulseElectronics.sensingInput;
        connection programmerRadio connect telemetry.programmerInterface to programmerPort;
        connection patientRadio connect telemetry.patientInterface to patientPort;
        connection chargingPath connect chargerReceiver.chargingInterface to rechargePort;
    }

    part def NeuralTargetTissue {
        doc /* Physiological target whose neural activity is modulated by controlled electrical stimulation. */

        attribute anatomicalRegion : String = "dorsal column spinal cord";
        attribute baselineBiomarkerLevel : Real = 1.0;
        attribute desiredBiomarkerRangeLow : Real = 0.35;
        attribute desiredBiomarkerRangeHigh : Real = 0.65;
        attribute stimulationThreshold : Current_mA = 1.2;
        attribute discomfortThreshold : Current_mA = 9.0;

        port electrodeInterface : ElectrodeTissuePort;
    }

    part def ClinicianProgrammer {
        attribute authenticatedUserRole : String = "clinician";
        attribute storesAuditLog : Boolean = true;
        port wirelessLink : WirelessProgrammingPort;
    }

    part def PatientController {
        attribute maximumPatientAmplitudeIncrease : Current_mA = 1.0;
        attribute maximumPatientAmplitudeDecrease : Current_mA = 2.0;
        attribute hasTherapySuspendButton : Boolean = true;
        port wirelessLink : PatientControlPort;
    }

    part def ExternalCharger {
        attribute maximumTransmitPower : Real = 5.0;
        attribute maximumTransmitPowerUnit : String = "W";
        attribute alignmentIndicatorPresent : Boolean = true;
        port chargingLink : RechargePort;
    }

    part def NeurostimulationSystem {
        doc /* High-level system whose primary function is to deliver programmable, charge-balanced electrical stimulation to a neural target to modulate neural activity while maintaining patient safety through monitoring, telemetry, and therapy limits. */

        attribute systemName : String = "Closed Loop Implantable Neurostimulation System";
        attribute intendedPrimaryFunction : String = "Modulate neural activity by delivering controlled electrical pulse trains to selected electrode contacts according to a validated therapy program.";
        attribute maximumDeliveredCurrent : Current_mA = 25.0;
        attribute maximumCaseTemperature : Temperature_C = 43.0;
        attribute minimumOperatingBatteryCharge : BatteryPercent = 10.0;

        part ipg : ImplantablePulseGenerator;
        part lead : ImplantableLead;
        part neuralTarget : NeuralTargetTissue;
        part clinicianProgrammer : ClinicianProgrammer;
        part patientController : PatientController;
        part externalCharger : ExternalCharger;

        port therapyPort : StimulationPort;
        port tissuePort : ElectrodeTissuePort;
        port clinicianCommunicationPort : WirelessProgrammingPort;
        port patientCommunicationPort : PatientControlPort;
        port chargingPort : RechargePort;

        connection ipgToLead connect ipg.stimulationPort to lead.proximalConnector;
        connection leadToTarget connect lead.distalElectrodes to neuralTarget.electrodeInterface;
        connection clinicianProgrammingLink connect clinicianProgrammer.wirelessLink to ipg.programmerPort;
        connection patientControlLink connect patientController.wirelessLink to ipg.patientPort;
        connection chargingLink connect externalCharger.chargingLink to ipg.rechargePort;
        connection externalTherapyPortBinding connect therapyPort to ipg.stimulationPort;
        connection externalTissuePortBinding connect tissuePort to neuralTarget.electrodeInterface;
        connection externalClinicianPortBinding connect clinicianCommunicationPort to clinicianProgrammer.wirelessLink;
        connection externalPatientPortBinding connect patientCommunicationPort to patientController.wirelessLink;
        connection externalChargingPortBinding connect chargingPort to externalCharger.chargingLink;

        action primaryFunction : ClosedLoopNeurostimulationSession;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The neurostimulation system shall provide its primary function by delivering controlled, charge-balanced electrical pulse trains through implanted electrodes to a neural target in accordance with a validated therapy program. */
        subject system : NeurostimulationSystem;
        require constraint primaryFunctionDefined {
            system.maximumDeliveredCurrent <= 25.0
        }
    }

    requirement def TherapyProgrammabilityRequirement {
        doc /* The system shall allow an authenticated clinician to configure stimulation mode, amplitude, pulse width, frequency, contact selection, and closed-loop behavior. */
        subject system : NeurostimulationSystem;
        require constraint programmableEnvelope {
            system.ipg.pulseElectronics.maximumOutputCurrent >= system.ipg.activeTherapyProgram.maximumAmplitude and
            system.ipg.pulseElectronics.maximumPulseWidth >= system.ipg.activeTherapyProgram.pulseWidth and
            system.ipg.pulseElectronics.maximumFrequency >= system.ipg.activeTherapyProgram.frequency
        }
    }

    requirement def ChargeBalanceRequirement {
        doc /* Delivered stimulation pulses shall be biphasic and charge balanced to reduce electrochemical tissue and electrode risk. */
        subject pulseTrain : BiphasicPulseTrain;
        require constraint chargeBalanced {
            pulseTrain.chargeBalanced == true
        }
    }

    requirement def PatientSafetyRequirement {
        doc /* The system shall inhibit or suspend therapy when unsafe temperature, battery, lead integrity, or parameter conditions are detected. */
        subject system : NeurostimulationSystem;
        require constraint safetyLimits {
            system.ipg.caseTemperature <= system.maximumCaseTemperature and
            system.ipg.battery.stateOfCharge >= system.minimumOperatingBatteryCharge
        }
    }

    requirement def ElectrodeImpedanceMonitoringRequirement {
        doc /* The system shall monitor electrode impedance during therapy to detect open circuits, short circuits, and lead integrity faults. */
        subject telemetry : ElectrodeTelemetry;
        require constraint impedanceRange {
            telemetry.impedance >= 50.0 and telemetry.impedance <= 10000.0
        }
    }

    requirement def PatientControlRequirement {
        doc /* The patient shall be able to suspend, resume, and adjust therapy only within clinician-authorized limits. */
        subject controller : PatientController;
        require constraint patientAdjustmentLimit {
            controller.maximumPatientAmplitudeIncrease <= 1.0
        }
    }

    requirement def RechargeRequirement {
        doc /* The rechargeable implant shall accept transcutaneous inductive charging and report charge status to the external charger. */
        subject system : NeurostimulationSystem;
        require constraint chargingAvailable {
            system.ipg.battery.stateOfCharge <= 100.0
        }
    }

    part neurostimulationSystem : NeurostimulationSystem;

    requirement primaryFunction : PrimaryFunctionRequirement {
        subject system = neurostimulationSystem;
    }

    requirement therapyProgrammability : TherapyProgrammabilityRequirement {
        subject system = neurostimulationSystem;
    }

    requirement patientSafety : PatientSafetyRequirement {
        subject system = neurostimulationSystem;
    }

    requirement patientControl : PatientControlRequirement {
        subject controller = neurostimulationSystem.patientController;
    }

    requirement rechargeCapability : RechargeRequirement {
        subject system = neurostimulationSystem;
    }

    satisfy primaryFunction by neurostimulationSystem;
    satisfy therapyProgrammability by neurostimulationSystem.ipg;
    satisfy patientSafety by neurostimulationSystem.ipg.safetySupervisor;
    satisfy patientControl by neurostimulationSystem.patientController;
    satisfy rechargeCapability by neurostimulationSystem.externalCharger;
}
