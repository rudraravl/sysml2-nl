package HyfrecatorSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    value def Watt :> Real;
    value def Volt :> Real;
    value def Milliampere :> Real;
    value def Ohm :> Real;
    value def Kilohertz :> Real;
    value def Percent :> Real;
    value def Millimeter :> Real;
    value def Second :> Real;
    value def Celsius :> Real;
    value def Joule :> Real;

    enum def WaveformMode {
        enum coagulation;
        enum fulguration;
        enum desiccation;
        enum bipolarCoagulation;
        enum standby;
    }

    enum def OutputState {
        enum disabled;
        enum armed;
        enum active;
        enum faultInhibited;
    }

    enum def FaultKind {
        enum none;
        enum overCurrent;
        enum overTemperature;
        enum returnPathInvalid;
        enum handpieceDisconnected;
        enum footswitchStuck;
        enum selfTestFailed;
    }

    item def MainsPower {
        attribute rmsVoltage : Volt;
        attribute frequency : Kilohertz;
        attribute protectiveEarthPresent : Boolean;
    }

    item def DCPower {
        attribute voltage : Volt;
        attribute currentLimit : Milliampere;
        attribute isolated : Boolean;
    }

    item def RFPower {
        attribute peakVoltage : Volt;
        attribute outputPower : Watt;
        attribute carrierFrequency : Kilohertz;
        attribute dutyCycle : Percent;
        attribute mode : WaveformMode;
    }

    item def TissueLoad {
        attribute impedance : Ohm;
        attribute contactArea : Millimeter;
        attribute hydrationLevel : Percent;
        attribute targetTemperature : Celsius;
    }

    item def ThermalEffect {
        attribute deliveredEnergy : Joule;
        attribute estimatedTemperature : Celsius;
        attribute coagulationDepth : Millimeter;
        attribute hemostasisAchieved : Boolean;
    }

    item def ControlCommand {
        attribute requestedMode : WaveformMode;
        attribute requestedPower : Watt;
        attribute activationRequested : Boolean;
    }

    item def StatusIndication {
        attribute outputState : OutputState;
        attribute selectedMode : WaveformMode;
        attribute setPower : Watt;
        attribute measuredPower : Watt;
        attribute fault : FaultKind;
    }

    item def OperatorInput {
        attribute modeSelection : WaveformMode;
        attribute powerSetting : Watt;
        attribute handSwitchPressed : Boolean;
        attribute footSwitchPressed : Boolean;
    }

    item def AudibleSignal {
        attribute toneFrequency : Kilohertz;
        attribute toneDuration : Second;
        attribute alarm : Boolean;
    }

    port def MainsInPort {
        in item power : MainsPower;
    }

    port def DCPowerPort {
        in item input : DCPower;
        out item output : DCPower;
    }

    port def RFOutputPort {
        out item rf : RFPower;
    }

    port def TissueInterfacePort {
        in item load : TissueLoad;
        out item effect : ThermalEffect;
    }

    port def OperatorInputPort {
        in item input : OperatorInput;
    }

    port def CommandPort {
        in item command : ControlCommand;
        out item commandOut : ControlCommand;
    }

    port def StatusPort {
        out item status : StatusIndication;
    }

    port def AudioPort {
        out item signal : AudibleSignal;
    }

    action def ConvertMainsToIsolatedDC {
        in item mains : MainsPower;
        out item dc : DCPower;

        constraint {
            dc.isolated == true;
            dc.voltage >= 24.0;
            dc.currentLimit <= 5000.0;
        }
    }

    action def GenerateRFPower {
        in item command : ControlCommand;
        in item dc : DCPower;
        out item rf : RFPower;

        constraint {
            rf.mode == command.requestedMode;
            rf.outputPower <= command.requestedPower;
            rf.carrierFrequency >= 350.0;
            rf.carrierFrequency <= 500.0;
            rf.peakVoltage <= 9000.0;
        }
    }

    action def ApplyRFToTissue {
        in item rf : RFPower;
        in item tissue : TissueLoad;
        out item effect : ThermalEffect;

        constraint {
            effect.deliveredEnergy >= 0.0;
            effect.estimatedTemperature >= tissue.targetTemperature;
            effect.coagulationDepth <= 5.0;
        }
    }

    action def MonitorSafety {
        in item rf : RFPower;
        in item tissue : TissueLoad;
        out attribute fault : FaultKind;

        constraint {
            if tissue.impedance > 5000.0 then fault == FaultKind::returnPathInvalid;
            if rf.outputPower > 50.0 then fault == FaultKind::overCurrent;
        }
    }

    action def UpdateUserIndications {
        in item command : ControlCommand;
        in attribute state : OutputState;
        in attribute fault : FaultKind;
        out item status : StatusIndication;
        out item audio : AudibleSignal;

        constraint {
            status.outputState == state;
            status.selectedMode == command.requestedMode;
            status.setPower == command.requestedPower;
            status.fault == fault;
            audio.alarm == (fault != FaultKind::none);
        }
    }

    state def HyfrecatorOperatingState {
        entry action perform UpdateUserIndications;

        state Off;
        state SelfTest;
        state Standby;
        state Armed;
        state DeliveringRF;
        state FaultLockout;

        transition first Off;
        transition Off_to_SelfTest
            first Off
            then SelfTest;

        transition SelfTest_to_Standby
            first SelfTest
            if selfTestPassed
            then Standby;

        transition SelfTest_to_Fault
            first SelfTest
            if not selfTestPassed
            then FaultLockout;

        transition Standby_to_Armed
            first Standby
            if operatorEnabledOutput and noActiveFault
            then Armed;

        transition Armed_to_DeliveringRF
            first Armed
            if activationRequested and validTissueLoad
            then DeliveringRF;

        transition DeliveringRF_to_Armed
            first DeliveringRF
            if not activationRequested
            then Armed;

        transition DeliveringRF_to_Fault
            first DeliveringRF
            if activeFaultDetected
            then FaultLockout;

        transition Armed_to_Standby
            first Armed
            if operatorDisabledOutput
            then Standby;

        transition Fault_to_Standby
            first FaultLockout
            if faultResetRequested and noActiveFault
            then Standby;

        attribute selfTestPassed : Boolean;
        attribute operatorEnabledOutput : Boolean;
        attribute operatorDisabledOutput : Boolean;
        attribute activationRequested : Boolean;
        attribute validTissueLoad : Boolean;
        attribute activeFaultDetected : Boolean;
        attribute noActiveFault : Boolean;
        attribute faultResetRequested : Boolean;
    }

    part def PowerSupply {
        port mainsIn : MainsInPort;
        port dcOut : DCPowerPort;

        attribute inputVoltageRangeLow : Volt = 100.0;
        attribute inputVoltageRangeHigh : Volt = 240.0;
        attribute isolationWithstandVoltage : Volt = 4000.0;
        attribute maxOutputPower : Watt = 90.0;

        perform action ConvertMainsToIsolatedDC {
            in mains = mainsIn.power;
            out dc = dcOut.output;
        }
    }

    part def RFGenerator {
        port dcIn : DCPowerPort;
        port commandIn : CommandPort;
        port rfOut : RFOutputPort;

        attribute carrierFrequency : Kilohertz = 450.0;
        attribute maximumMonopolarPower : Watt = 35.0;
        attribute maximumBipolarPower : Watt = 50.0;
        attribute maximumOpenCircuitVoltage : Volt = 9000.0;
        attribute outputState : OutputState = OutputState::disabled;

        perform action GenerateRFPower {
            in command = commandIn.command;
            in dc = dcIn.input;
            out rf = rfOut.rf;
        }
    }

    part def Handpiece {
        port rfInput : RFOutputPort;
        port tissuePort : TissueInterfacePort;
        port operatorInput : OperatorInputPort;

        attribute electrodeTipDiameter : Millimeter = 1.0;
        attribute cableLength : Millimeter = 3000.0;
        attribute disposableTipAttached : Boolean;
        attribute handSwitchEnabled : Boolean;

        connect rfInput.rf to tissuePort.effect;
    }

    part def BipolarForceps {
        port rfInput : RFOutputPort;
        port tissuePort : TissueInterfacePort;

        attribute jawSpacing : Millimeter = 2.0;
        attribute insulatedShaftLength : Millimeter = 120.0;
        attribute reusable : Boolean = true;
    }

    part def FootSwitch {
        port operatorInput : OperatorInputPort;

        attribute normallyOpenContact : Boolean = true;
        attribute stuckSwitchDetected : Boolean;
    }

    part def UserInterface {
        port operatorIn : OperatorInputPort;
        port commandOut : CommandPort;
        port statusOut : StatusPort;
        port audioOut : AudioPort;

        attribute selectedMode : WaveformMode = WaveformMode::standby;
        attribute selectedPower : Watt = 5.0;
        attribute displayBrightness : Percent = 80.0;
        attribute activationToneEnabled : Boolean = true;

        constraint powerSettingLimit {
            selectedPower >= 0.0;
            selectedPower <= 50.0;
        }
    }

    part def SafetyController {
        port commandIn : CommandPort;
        port rfMonitor : RFOutputPort;
        port tissueMonitor : TissueInterfacePort;
        port statusOut : StatusPort;

        attribute activeFault : FaultKind = FaultKind::none;
        attribute maximumCaseTemperature : Celsius = 60.0;
        attribute maximumContinuousActivationTime : Second = 30.0;
        attribute leakageCurrentLimit : Milliampere = 0.1;

        perform action MonitorSafety {
            in rf = rfMonitor.rf;
            in tissue = tissueMonitor.load;
            out fault = activeFault;
        }
    }

    part def PatientTissue {
        port treatmentSite : TissueInterfacePort;

        attribute baselineImpedance : Ohm = 800.0;
        attribute desiredCoagulationDepth : Millimeter = 2.0;
        attribute initialTemperature : Celsius = 37.0;
        attribute bloodPerfusionPresent : Boolean = true;
    }

    part def Hyfrecator {
        doc /* A hyfrecator is a high-frequency electrosurgical system whose primary function is to deliver controlled radio-frequency energy through a small electrode to superficial tissue in order to desiccate, fulgurate, or coagulate tissue and produce localized hemostasis or lesion destruction. */

        part powerSupply : PowerSupply;
        part rfGenerator : RFGenerator;
        part handpiece : Handpiece;
        part bipolarForceps : BipolarForceps;
        part footSwitch : FootSwitch;
        part userInterface : UserInterface;
        part safetyController : SafetyController;

        port mainsInput : MainsInPort;
        port monopolarTreatmentPort : TissueInterfacePort;
        port bipolarTreatmentPort : TissueInterfacePort;
        port operatorControls : OperatorInputPort;
        port deviceStatus : StatusPort;
        port audibleOutput : AudioPort;

        attribute nominalCarrierFrequency : Kilohertz = 450.0;
        attribute standbyPowerConsumption : Watt = 8.0;
        attribute maximumTreatmentPower : Watt = 50.0;
        attribute minimumSetPower : Watt = 0.5;
        attribute maximumActivationTime : Second = 30.0;
        attribute intendedUseSuperficialTissueOnly : Boolean = true;

        connect mainsInput.power to powerSupply.mainsIn.power;
        connect powerSupply.dcOut.output to rfGenerator.dcIn.input;
        connect userInterface.commandOut.commandOut to rfGenerator.commandIn.command;
        connect rfGenerator.rfOut.rf to handpiece.rfInput.rf;
        connect rfGenerator.rfOut.rf to bipolarForceps.rfInput.rf;
        connect handpiece.tissuePort.load to monopolarTreatmentPort.load;
        connect handpiece.tissuePort.effect to monopolarTreatmentPort.effect;
        connect bipolarForceps.tissuePort.load to bipolarTreatmentPort.load;
        connect bipolarForceps.tissuePort.effect to bipolarTreatmentPort.effect;
        connect operatorControls.input to userInterface.operatorIn.input;
        connect footSwitch.operatorInput.input to userInterface.operatorIn.input;
        connect rfGenerator.rfOut.rf to safetyController.rfMonitor.rf;
        connect monopolarTreatmentPort.load to safetyController.tissueMonitor.load;
        connect safetyController.statusOut.status to deviceStatus.status;
        connect userInterface.statusOut.status to deviceStatus.status;
        connect userInterface.audioOut.signal to audibleOutput.signal;

        state operatingState : HyfrecatorOperatingState;

        perform action ConvertMainsToIsolatedDC {
            in mains = mainsInput.power;
            out dc = powerSupply.dcOut.output;
        }

        perform action GenerateRFPower {
            in command = userInterface.commandOut.commandOut;
            in dc = powerSupply.dcOut.output;
            out rf = rfGenerator.rfOut.rf;
        }

        perform action ApplyRFToTissue {
            in rf = rfGenerator.rfOut.rf;
            in tissue = monopolarTreatmentPort.load;
            out effect = monopolarTreatmentPort.effect;
        }

        constraint outputPowerWithinSelectedLimit {
            rfGenerator.maximumMonopolarPower <= maximumTreatmentPower;
            rfGenerator.maximumBipolarPower <= maximumTreatmentPower;
        }

        constraint carrierFrequencyInElectrosurgicalRange {
            nominalCarrierFrequency >= 350.0;
            nominalCarrierFrequency <= 500.0;
        }

        constraint superficialTreatmentEnergyControl {
            maximumActivationTime <= 30.0;
            intendedUseSuperficialTissueOnly == true;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall provide controlled high-frequency electrosurgical energy to superficial tissue through a handpiece or bipolar accessory for desiccation, fulguration, or coagulation. */

        subject hyfrecator : Hyfrecator;

        require constraint {
            hyfrecator.nominalCarrierFrequency >= 350.0;
            hyfrecator.nominalCarrierFrequency <= 500.0;
            hyfrecator.maximumTreatmentPower <= 50.0;
            hyfrecator.intendedUseSuperficialTissueOnly == true;
        }
    }

    requirement def PowerIsolationRequirement {
        doc /* The power supply shall isolate patient-applied RF circuitry from mains power. */

        subject hyfrecator : Hyfrecator;

        require constraint {
            hyfrecator.powerSupply.isolationWithstandVoltage >= 4000.0;
            hyfrecator.powerSupply.maxOutputPower >= hyfrecator.maximumTreatmentPower;
        }
    }

    requirement def OutputControlRequirement {
        doc /* The RF output shall be enabled only when the operator requests activation, a valid treatment accessory is connected, and no active safety fault is present. */

        subject hyfrecator : Hyfrecator;

        require constraint {
            hyfrecator.safetyController.activeFault == FaultKind::none;
            hyfrecator.rfGenerator.outputState != OutputState::faultInhibited;
        }
    }

    requirement def UserFeedbackRequirement {
        doc /* The device shall indicate selected mode, set power, output state, measured output, and fault condition to the operator. */

        subject hyfrecator : Hyfrecator;

        require constraint {
            hyfrecator.userInterface.displayBrightness >= 20.0;
            hyfrecator.userInterface.activationToneEnabled == true;
        }
    }

    requirement def ThermalEffectRequirement {
        doc /* The applied RF energy shall produce localized tissue heating sufficient for hemostasis while limiting coagulation depth for superficial procedures. */

        subject treatmentEffect : ThermalEffect;

        require constraint {
            treatmentEffect.estimatedTemperature >= 60.0;
            treatmentEffect.coagulationDepth <= 5.0;
        }
    }

    requirement def ContinuousActivationLimitRequirement {
        doc /* The system shall inhibit continuous RF activation beyond the configured maximum activation interval. */

        subject hyfrecator : Hyfrecator;

        require constraint {
            hyfrecator.maximumActivationTime <= 30.0;
            hyfrecator.safetyController.maximumContinuousActivationTime <= 30.0;
        }
    }

    requirement def LeakageCurrentRequirement {
        doc /* Patient leakage current shall remain below the configured applied-part leakage limit during normal operation. */

        subject hyfrecator : Hyfrecator;

        require constraint {
            hyfrecator.safetyController.leakageCurrentLimit <= 0.1;
        }
    }

    part def ClinicalUseScenario {
        part device : Hyfrecator;
        part patientTissue : PatientTissue;

        connect device.monopolarTreatmentPort.load to patientTissue.treatmentSite.load;
        connect device.monopolarTreatmentPort.effect to patientTissue.treatmentSite.effect;

        attribute selectedMode : WaveformMode = WaveformMode::desiccation;
        attribute selectedPower : Watt = 10.0;
        attribute activationDuration : Second = 3.0;

        perform action ApplyRFToTissue {
            in rf = device.rfGenerator.rfOut.rf;
            in tissue = patientTissue.treatmentSite.load;
            out effect = patientTissue.treatmentSite.effect;
        }

        satisfy PrimaryFunctionRequirement by device;
        satisfy PowerIsolationRequirement by device;
        satisfy OutputControlRequirement by device;
        satisfy UserFeedbackRequirement by device;
        satisfy ContinuousActivationLimitRequirement by device;
        satisfy LeakageCurrentRequirement by device;
        satisfy ThermalEffectRequirement by patientTissue.treatmentSite.effect;
    }
}