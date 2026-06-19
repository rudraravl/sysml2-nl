package IontophoresisTherapyModel {
    private import ScalarValues::*;

    attribute def ElectricCurrent :> Real {
        attribute unitSymbol : String = "mA";
    }

    attribute def Voltage :> Real {
        attribute unitSymbol : String = "V";
    }

    attribute def ElectricalResistance :> Real {
        attribute unitSymbol : String = "ohm";
    }

    attribute def ElectricCharge :> Real {
        attribute unitSymbol : String = "C";
    }

    attribute def TimeDuration :> Real {
        attribute unitSymbol : String = "s";
    }

    attribute def CurrentRampRate :> Real {
        attribute unitSymbol : String = "mA/s";
    }

    attribute def Temperature :> Real {
        attribute unitSymbol : String = "degC";
    }

    attribute def Volume :> Real {
        attribute unitSymbol : String = "mL";
    }

    attribute def DrugConcentration :> Real {
        attribute unitSymbol : String = "mg/mL";
    }

    attribute def ContactArea :> Real {
        attribute unitSymbol : String = "cm^2";
    }

    attribute def DoseAccuracy :> Real {
        attribute unitSymbol : String = "percent";
    }

    attribute def Frequency :> Real {
        attribute unitSymbol : String = "Hz";
    }

    enum def ElectrodePolarity {
        enum anode;
        enum cathode;
    }

    enum def TherapyCommandKind {
        enum powerOn;
        enum powerOff;
        enum prime;
        enum startTherapy;
        enum pauseTherapy;
        enum resumeTherapy;
        enum stopTherapy;
        enum acknowledgeAlarm;
    }

    enum def AlarmKind {
        enum noAlarm;
        enum highCurrent;
        enum highVoltage;
        enum highSkinImpedance;
        enum lowSkinImpedance;
        enum electrodeLift;
        enum reservoirEmpty;
        enum overTemperature;
        enum doseComplete;
        enum internalFault;
    }

    item def ChargedDrugIon {
        attribute name : String;
        attribute valence : Real;
        attribute mobility : Real;
        attribute targetDose : ElectricCharge;
    }

    item def DrugSolution {
        attribute activeIon : ChargedDrugIon;
        attribute concentration : DrugConcentration;
        attribute availableVolume : Volume;
        attribute pH : Real;
    }

    item def ElectricalPower {
        attribute supplyVoltage : Voltage;
        attribute availableCurrent : ElectricCurrent;
    }

    item def ElectricalStimulus {
        attribute current : ElectricCurrent;
        attribute voltage : Voltage;
        attribute rampRate : CurrentRampRate;
        attribute deliveredCharge : ElectricCharge;
        attribute elapsedTime : TimeDuration;
    }

    item def SkinResponse {
        attribute measuredImpedance : ElectricalResistance;
        attribute skinTemperature : Temperature;
        attribute deliveredCharge : ElectricCharge;
        attribute electrodeAttached : Boolean;
    }

    item def TherapyCommand {
        attribute commandKind : TherapyCommandKind;
        attribute requestedCurrent : ElectricCurrent;
        attribute requestedDuration : TimeDuration;
        attribute requestedCharge : ElectricCharge;
    }

    item def TherapyStatus {
        attribute deliveredCurrent : ElectricCurrent;
        attribute deliveredVoltage : Voltage;
        attribute deliveredCharge : ElectricCharge;
        attribute remainingTime : TimeDuration;
        attribute alarm : AlarmKind;
    }

    item def AlarmNotification {
        attribute alarm : AlarmKind;
        attribute audibleFrequency : Frequency;
        attribute latched : Boolean;
    }

    port def PowerOutputPort {
        out item power : ElectricalPower;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def UserCommandInputPort {
        in item command : TherapyCommand;
    }

    port def UserCommandOutputPort {
        out item command : TherapyCommand;
    }

    port def StatusOutputPort {
        out item status : TherapyStatus;
    }

    port def StatusInputPort {
        in item status : TherapyStatus;
    }

    port def AlarmOutputPort {
        out item alarm : AlarmNotification;
    }

    port def AlarmInputPort {
        in item alarm : AlarmNotification;
    }

    port def DrugSolutionOutputPort {
        out item solution : DrugSolution;
    }

    port def DrugSolutionInputPort {
        in item solution : DrugSolution;
    }

    port def ElectrodeDriveOutputPort {
        out item stimulus : ElectricalStimulus;
    }

    port def ElectrodeDriveInputPort {
        in item stimulus : ElectricalStimulus;
    }

    port def SkinSensorOutputPort {
        out item response : SkinResponse;
    }

    port def SkinSensorInputPort {
        in item response : SkinResponse;
    }

    port def SkinContactOutputPort {
        out item stimulus : ElectricalStimulus;
        in item response : SkinResponse;
    }

    port def SkinContactInputPort {
        in item stimulus : ElectricalStimulus;
        out item response : SkinResponse;
    }

    constraint def SafeCurrentEnvelope {
        in current : ElectricCurrent;
        in voltage : Voltage;
        in deliveredCharge : ElectricCharge;
        in skinTemperature : Temperature;
        in electrodeAttached : Boolean;

        current >= 0.0 and
        current <= 4.0 and
        voltage <= 80.0 and
        deliveredCharge <= 4.8 and
        skinTemperature <= 41.0 and
        electrodeAttached == true
    }

    constraint def IontophoreticChargeEstimate {
        in current : ElectricCurrent;
        in elapsedTime : TimeDuration;
        out charge : ElectricCharge;

        charge == current * elapsedTime / 1000.0
    }

    constraint def DriveVoltageEstimate {
        in current : ElectricCurrent;
        in impedance : ElectricalResistance;
        out voltage : Voltage;

        voltage == current * impedance / 1000.0
    }

    action def InitializeController {
        out status : TherapyStatus;
    }

    action def PrimeDrugReservoir {
        in item solution : DrugSolution;
        out item primedSolution : DrugSolution;
    }

    action def MeasureSkinImpedance {
        in item response : SkinResponse;
        out impedance : ElectricalResistance;
    }

    action def ComputeDriveVoltage {
        in commandedCurrent : ElectricCurrent;
        in impedance : ElectricalResistance;
        out driveVoltage : Voltage;
    }

    action def ApplyControlledCurrent {
        in commandedCurrent : ElectricCurrent;
        in driveVoltage : Voltage;
        in elapsedTime : TimeDuration;
        out item stimulus : ElectricalStimulus;
    }

    action def MonitorTherapySafety {
        in item response : SkinResponse;
        in item stimulus : ElectricalStimulus;
        out item alarm : AlarmNotification;
    }

    action def RegulateIontophoresisCurrent {
        in commandedCurrent : ElectricCurrent;
        in elapsedTime : TimeDuration;
        in item skinResponse : SkinResponse;
        out item stimulus : ElectricalStimulus;
        out item alarm : AlarmNotification;

        action measure : MeasureSkinImpedance;
        action compute : ComputeDriveVoltage;
        action apply : ApplyControlledCurrent;
        action monitor : MonitorTherapySafety;

        first measure then compute;
        then apply;
        then monitor;
    }

    action def DeliverChargedDrugThroughSkin {
        in item prescribedSolution : DrugSolution;
        in commandedCurrent : ElectricCurrent;
        in requestedDuration : TimeDuration;
        in requestedCharge : ElectricCharge;
        in item skinResponse : SkinResponse;
        out item stimulus : ElectricalStimulus;
        out item status : TherapyStatus;
        out item alarm : AlarmNotification;

        action prime : PrimeDrugReservoir;
        action regulate : RegulateIontophoresisCurrent;

        first prime then regulate;
    }

    state def ControllerTherapyStateMachine {
        entry action initialize : InitializeController;

        state poweredOff;
        state selfTest;
        state ready;
        state priming;
        state deliveringTherapy;
        state paused;
        state completed;
        state alarmed;

        transition initialTransition first poweredOff;

        transition powerOnTransition
            first poweredOff
            accept TherapyCommand
            then selfTest;

        transition selfTestPassedTransition
            first selfTest
            then ready;

        transition primeTransition
            first ready
            accept TherapyCommand
            then priming;

        transition primedTransition
            first priming
            then ready;

        transition startTherapyTransition
            first ready
            accept TherapyCommand
            then deliveringTherapy;

        transition pauseTransition
            first deliveringTherapy
            accept TherapyCommand
            then paused;

        transition resumeTransition
            first paused
            accept TherapyCommand
            then deliveringTherapy;

        transition doseCompleteTransition
            first deliveringTherapy
            then completed;

        transition stopTransition
            first deliveringTherapy
            accept TherapyCommand
            then ready;

        transition alarmTransition
            first deliveringTherapy
            accept AlarmNotification
            then alarmed;

        transition alarmAcknowledgedTransition
            first alarmed
            accept TherapyCommand
            then ready;

        transition powerOffTransition
            first ready
            accept TherapyCommand
            then poweredOff;
    }

    part def BatteryPack {
        port powerOut : PowerOutputPort;

        attribute nominalVoltage : Voltage = 9.0;
        attribute maximumOutputCurrent : ElectricCurrent = 500.0;
        attribute remainingCapacity : ElectricCharge = 7200.0;
    }

    part def PowerConditioner {
        port rawPowerIn : PowerInputPort;
        port regulatedPowerOut : PowerOutputPort;

        attribute regulatedVoltage : Voltage = 5.0;
        attribute maximumTherapySupplyVoltage : Voltage = 80.0;
        attribute maximumSupplyCurrent : ElectricCurrent = 20.0;
    }

    part def UserInterface {
        port clinicianCommands : UserCommandInputPort;
        port commandOut : UserCommandOutputPort;
        port statusIn : StatusInputPort;
        port alarmIn : AlarmInputPort;

        attribute displayedCurrent : ElectricCurrent = 0.0;
        attribute displayedDose : ElectricCharge = 0.0;
        attribute displayedRemainingTime : TimeDuration = 0.0;
        attribute alarmToneFrequency : Frequency = 2500.0;
    }

    part def TherapyController {
        port powerIn : PowerInputPort;
        port commandIn : UserCommandInputPort;
        port statusOut : StatusOutputPort;
        port alarmOut : AlarmOutputPort;
        port stimulusOut : ElectrodeDriveOutputPort;
        port sensorIn : SkinSensorInputPort;

        attribute commandedCurrent : ElectricCurrent = 2.0;
        attribute maximumProgrammedCurrent : ElectricCurrent = 4.0;
        attribute minimumProgrammedCurrent : ElectricCurrent = 0.1;
        attribute commandedDuration : TimeDuration = 1200.0;
        attribute commandedCharge : ElectricCharge = 2.4;
        attribute deliveredCharge : ElectricCharge = 0.0;
        attribute samplePeriod : TimeDuration = 0.1;
        attribute doseAccuracyLimit : DoseAccuracy = 10.0;
        attribute maximumVoltage : Voltage = 80.0;
        attribute maximumSkinTemperature : Temperature = 41.0;

        exhibit state controllerState : ControllerTherapyStateMachine;
        perform action regulateCurrent : RegulateIontophoresisCurrent;
        perform action deliverTherapy : DeliverChargedDrugThroughSkin;
    }

    part def DrugReservoir {
        port solutionOut : DrugSolutionOutputPort;

        attribute capacity : Volume = 5.0;
        attribute remainingVolume : Volume = 5.0;
        attribute nominalConcentration : DrugConcentration = 20.0;
        attribute minimumUsableVolume : Volume = 0.2;

        item solution : DrugSolution {
            attribute concentration = 20.0;
            attribute availableVolume = 5.0;
            attribute pH = 6.8;
        }
    }

    part def HydrogelPad {
        port solutionIn : DrugSolutionInputPort;

        attribute retainedVolume : Volume = 1.0;
        attribute contactArea : ContactArea = 8.0;
        attribute hydrated : Boolean = true;
    }

    part def ActiveElectrode {
        port driveInput : ElectrodeDriveInputPort;
        port solutionInput : DrugSolutionInputPort;
        port skinInterface : SkinContactOutputPort;
        port responseOut : SkinSensorOutputPort;

        attribute polarity : ElectrodePolarity = ElectrodePolarity::anode;
        attribute contactArea : ContactArea = 8.0;
        attribute nominalCurrentDensity : Real = 0.25;
        attribute electrodeAttached : Boolean = true;
    }

    part def ReturnElectrode {
        port driveInput : ElectrodeDriveInputPort;
        port skinInterface : SkinContactOutputPort;
        port responseOut : SkinSensorOutputPort;

        attribute polarity : ElectrodePolarity = ElectrodePolarity::cathode;
        attribute contactArea : ContactArea = 12.0;
        attribute electrodeAttached : Boolean = true;
    }

    part def ElectrodePatchAssembly {
        port driveInput : ElectrodeDriveInputPort;
        port drugInput : DrugSolutionInputPort;
        port activeSkinPort : SkinContactOutputPort;
        port returnSkinPort : SkinContactOutputPort;
        port responseOut : SkinSensorOutputPort;

        part activeElectrode : ActiveElectrode;
        part returnElectrode : ReturnElectrode;
        part drugPad : HydrogelPad;

        attribute activeContactArea : ContactArea = 8.0;
        attribute returnContactArea : ContactArea = 12.0;

        connect driveInput to activeElectrode.driveInput;
        connect driveInput to returnElectrode.driveInput;
        connect drugInput to drugPad.solutionIn;
        connect drugInput to activeElectrode.solutionInput;
        connect activeElectrode.skinInterface to activeSkinPort;
        connect returnElectrode.skinInterface to returnSkinPort;
        connect activeElectrode.responseOut to responseOut;
        connect returnElectrode.responseOut to responseOut;
    }

    part def PatientSkinSite {
        port activeDrugSite : SkinContactInputPort;
        port returnSite : SkinContactInputPort;

        attribute initialSkinImpedance : ElectricalResistance = 20000.0;
        attribute minimumExpectedImpedance : ElectricalResistance = 5000.0;
        attribute maximumExpectedImpedance : ElectricalResistance = 60000.0;
        attribute baselineTemperature : Temperature = 33.0;
        attribute maximumAllowedTemperature : Temperature = 41.0;
        attribute deliveredChargeToTissue : ElectricCharge = 0.0;
    }

    part def IontophoresisSystem {
        port clinicianCommandPort : UserCommandInputPort;
        port clinicianStatusPort : StatusOutputPort;
        port activeSkinContact : SkinContactOutputPort;
        port returnSkinContact : SkinContactOutputPort;

        part battery : BatteryPack;
        part powerConditioner : PowerConditioner;
        part userInterface : UserInterface;
        part therapyController : TherapyController;
        part drugReservoir : DrugReservoir;
        part electrodePatch : ElectrodePatchAssembly;

        attribute maximumTherapyCurrent : ElectricCurrent = 4.0;
        attribute nominalTherapyCurrent : ElectricCurrent = 2.0;
        attribute maximumTherapyVoltage : Voltage = 80.0;
        attribute defaultTherapyDuration : TimeDuration = 1200.0;
        attribute maximumDeliveredCharge : ElectricCharge = 4.8;
        attribute primaryFunctionCurrentRampRate : CurrentRampRate = 0.1;

        perform action primaryFunction : DeliverChargedDrugThroughSkin;

        connect battery.powerOut to powerConditioner.rawPowerIn;
        connect powerConditioner.regulatedPowerOut to therapyController.powerIn;
        connect clinicianCommandPort to userInterface.clinicianCommands;
        connect userInterface.commandOut to therapyController.commandIn;
        connect therapyController.statusOut to userInterface.statusIn;
        connect therapyController.statusOut to clinicianStatusPort;
        connect therapyController.alarmOut to userInterface.alarmIn;
        connect therapyController.stimulusOut to electrodePatch.driveInput;
        connect therapyController.sensorIn to electrodePatch.responseOut;
        connect drugReservoir.solutionOut to electrodePatch.drugInput;
        connect electrodePatch.activeSkinPort to activeSkinContact;
        connect electrodePatch.returnSkinPort to returnSkinContact;
    }

    part def IontophoresisTreatmentContext {
        part device : IontophoresisSystem;
        part patient : PatientSkinSite;

        connect device.activeSkinContact to patient.activeDrugSite;
        connect device.returnSkinContact to patient.returnSite;
    }

    requirement def PrimaryFunctionRequirement {
        subject device : IontophoresisSystem;

        doc /* The iontophoresis system shall provide its primary high-level function by driving a controlled, low-level direct current between an active drug electrode and a return electrode so that charged drug ions migrate from the drug reservoir through the patient's skin while therapy dose and safety limits are monitored. */

        require constraint {
            device.nominalTherapyCurrent > 0.0 and
            device.nominalTherapyCurrent <= device.maximumTherapyCurrent and
            device.maximumTherapyVoltage <= 80.0 and
            device.defaultTherapyDuration > 0.0
        }
    }

    requirement def ControlledCurrentRequirement {
        subject device : IontophoresisSystem;

        require constraint {
            device.therapyController.commandedCurrent >= device.therapyController.minimumProgrammedCurrent and
            device.therapyController.commandedCurrent <= device.therapyController.maximumProgrammedCurrent and
            device.therapyController.maximumProgrammedCurrent <= 4.0
        }
    }

    requirement def DoseLimitRequirement {
        subject device : IontophoresisSystem;

        require constraint {
            device.therapyController.commandedCharge <= device.maximumDeliveredCharge and
            device.therapyController.deliveredCharge <= device.maximumDeliveredCharge
        }
    }

    requirement def VoltageLimitRequirement {
        subject device : IontophoresisSystem;

        require constraint {
            device.maximumTherapyVoltage <= 80.0 and
            device.therapyController.maximumVoltage <= device.maximumTherapyVoltage
        }
    }

    requirement def DrugReservoirRequirement {
        subject device : IontophoresisSystem;

        require constraint {
            device.drugReservoir.capacity >= 5.0 and
            device.drugReservoir.remainingVolume >= device.drugReservoir.minimumUsableVolume
        }
    }

    requirement def SkinSafetyRequirement {
        subject context : IontophoresisTreatmentContext;

        require constraint {
            context.patient.maximumAllowedTemperature <= 41.0 and
            context.patient.minimumExpectedImpedance >= 5000.0 and
            context.patient.maximumExpectedImpedance <= 60000.0
        }
    }

    requirement def AlarmRequirement {
        subject device : IontophoresisSystem;

        require constraint {
            device.userInterface.alarmToneFrequency >= 2000.0 and
            device.userInterface.alarmToneFrequency <= 4000.0
        }
    }

    part iontophoresisTreatment : IontophoresisTreatmentContext;

    requirement primaryFunction : PrimaryFunctionRequirement {
        subject device = iontophoresisTreatment.device;
    }

    requirement controlledCurrent : ControlledCurrentRequirement {
        subject device = iontophoresisTreatment.device;
    }

    requirement doseLimit : DoseLimitRequirement {
        subject device = iontophoresisTreatment.device;
    }

    requirement voltageLimit : VoltageLimitRequirement {
        subject device = iontophoresisTreatment.device;
    }

    requirement reservoirCapacity : DrugReservoirRequirement {
        subject device = iontophoresisTreatment.device;
    }

    requirement skinSafety : SkinSafetyRequirement {
        subject context = iontophoresisTreatment;
    }

    requirement alarmIndication : AlarmRequirement {
        subject device = iontophoresisTreatment.device;
    }

    satisfy primaryFunction by iontophoresisTreatment.device;
    satisfy controlledCurrent by iontophoresisTreatment.device.therapyController;
    satisfy doseLimit by iontophoresisTreatment.device.therapyController;
    satisfy voltageLimit by iontophoresisTreatment.device.powerConditioner;
    satisfy reservoirCapacity by iontophoresisTreatment.device.drugReservoir;
    satisfy skinSafety by iontophoresisTreatment.patient;
    satisfy alarmIndication by iontophoresisTreatment.device.userInterface;
}
