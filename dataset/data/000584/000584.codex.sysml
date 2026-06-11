package DiathermySystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Power_W :> Real {
        unit = W;
    }

    attribute def Frequency_Hz :> Real {
        unit = Hz;
    }

    attribute def Voltage_V :> Real {
        unit = V;
    }

    attribute def Current_A :> Real {
        unit = A;
    }

    attribute def Temperature_C :> Real {
        unit = degC;
    }

    attribute def Time_s :> Real {
        unit = s;
    }

    attribute def Impedance_Ohm :> Real {
        unit = ohm;
    }

    attribute def Energy_J :> Real {
        unit = J;
    }

    enum def TherapyMode {
        enum off;
        enum warming;
        enum coagulation;
        enum cutting;
        enum standby;
        enum fault;
    }

    enum def ElectrodeContactState {
        enum open;
        enum partial;
        enum acceptable;
        enum unsafe;
    }

    item def MainsElectricalPower {
        attribute voltage : Voltage_V;
        attribute frequency : Frequency_Hz;
        attribute currentLimit : Current_A;
    }

    item def LowVoltagePower {
        attribute dcVoltage : Voltage_V;
        attribute availablePower : Power_W;
    }

    item def RfEnergy {
        attribute carrierFrequency : Frequency_Hz;
        attribute outputPower : Power_W;
        attribute peakVoltage : Voltage_V;
        attribute rmsCurrent : Current_A;
        attribute deliveredEnergy : Energy_J;
    }

    item def ThermalDose {
        attribute targetTemperature : Temperature_C;
        attribute measuredTemperature : Temperature_C;
        attribute exposureTime : Time_s;
    }

    item def TissueFeedback {
        attribute tissueImpedance : Impedance_Ohm;
        attribute tissueTemperature : Temperature_C;
        attribute contactState : ElectrodeContactState;
    }

    item def UserCommand {
        attribute requestedMode : TherapyMode;
        attribute requestedPower : Power_W;
        attribute requestedDuration : Time_s;
    }

    item def AlarmSignal {
        attribute alarmActive : Boolean;
        attribute alarmCode : String;
        attribute severity : String;
    }

    port def PowerInPort {
        in item power : MainsElectricalPower;
    }

    port def DcPowerPort {
        out item power : LowVoltagePower;
    }

    port def RfOutputPort {
        out item rf : RfEnergy;
    }

    port def RfInputPort {
        in item rf : RfEnergy;
    }

    port def FeedbackPort {
        in item feedback : TissueFeedback;
    }

    port def SensorOutputPort {
        out item feedback : TissueFeedback;
    }

    port def CommandInputPort {
        in item command : UserCommand;
    }

    port def AlarmOutputPort {
        out item alarm : AlarmSignal;
    }

    port def ThermalInterfacePort {
        out item dose : ThermalDose;
    }

    part def PowerSupply {
        port mainsIn : PowerInPort;
        port dcOut : DcPowerPort;

        attribute inputVoltage : Voltage_V = 120;
        attribute dcBusVoltage : Voltage_V = 48;
        attribute maxOutputPower : Power_W = 500;
        attribute isolationLeakageCurrent : Current_A = 0.0001;

        action regulatePower {
            in item inputPower : MainsElectricalPower;
            out item regulatedPower : LowVoltagePower;
        }
    }

    part def RfGenerator {
        port dcIn : DcPowerPort;
        port commandIn : CommandInputPort;
        port feedbackIn : FeedbackPort;
        port rfOut : RfOutputPort;

        attribute nominalCarrierFrequency : Frequency_Hz = 500000;
        attribute minimumCarrierFrequency : Frequency_Hz = 300000;
        attribute maximumCarrierFrequency : Frequency_Hz = 1000000;
        attribute maximumTherapeuticPower : Power_W = 200;
        attribute maximumSurgicalPower : Power_W = 400;
        attribute outputImpedance : Impedance_Ohm = 50;
        attribute selectedMode : TherapyMode = TherapyMode::standby;
        attribute commandedPower : Power_W = 0;

        action synthesizeRfEnergy {
            in item dcPower : LowVoltagePower;
            in item command : UserCommand;
            in item tissueFeedback : TissueFeedback;
            out item rfEnergy : RfEnergy;
        }

        action limitOutputPower {
            in item tissueFeedback : TissueFeedback;
            in attribute requestedPower : Power_W;
            out attribute limitedPower : Power_W;
        }
    }

    part def PatientReturnMonitor {
        port feedbackOut : SensorOutputPort;

        attribute minimumSafeImpedance : Impedance_Ohm = 20;
        attribute maximumSafeImpedance : Impedance_Ohm = 300;
        attribute maximumReturnPadTemperature : Temperature_C = 41;

        action evaluateContact {
            in attribute measuredImpedance : Impedance_Ohm;
            in attribute measuredTemperature : Temperature_C;
            out item feedback : TissueFeedback;
        }
    }

    part def ActiveElectrode {
        port rfIn : RfInputPort;
        port tissueDoseOut : ThermalInterfacePort;

        attribute electrodeTipArea : Real = 4.0;
        attribute maximumTipTemperature : Temperature_C = 120;
        attribute insulationRating : Voltage_V = 2500;

        action coupleEnergyToTissue {
            in item rfEnergy : RfEnergy;
            out item dose : ThermalDose;
        }
    }

    part def ReturnElectrode {
        port feedbackOut : SensorOutputPort;

        attribute contactArea : Real = 150.0;
        attribute maximumAllowedTemperature : Temperature_C = 41;
        attribute contactImpedance : Impedance_Ohm;
    }

    part def UserInterface {
        port commandOut : CommandInputPort;
        port alarmIn : AlarmOutputPort;

        attribute displayedMode : TherapyMode;
        attribute displayedPower : Power_W;
        attribute displayedTemperature : Temperature_C;
        attribute audibleAlarmEnabled : Boolean = true;

        action captureUserSettings {
            out item command : UserCommand;
        }

        action displaySystemStatus {
            in item feedback : TissueFeedback;
            in item alarm : AlarmSignal;
        }
    }

    part def SafetyController {
        port commandIn : CommandInputPort;
        port feedbackIn : FeedbackPort;
        port alarmOut : AlarmOutputPort;

        attribute maximumPatientTemperature : Temperature_C = 45;
        attribute maximumContinuousActivationTime : Time_s = 60;
        attribute maximumOpenCircuitVoltage : Voltage_V = 1500;
        attribute safeStateRequired : Boolean = false;

        action detectUnsafeCondition {
            in item command : UserCommand;
            in item feedback : TissueFeedback;
            out item alarm : AlarmSignal;
            out attribute inhibitOutput : Boolean;
        }
    }

    part def DiathermyUnit {
        port mainsInput : PowerInPort;
        port therapyCommand : CommandInputPort;
        port patientFeedback : FeedbackPort;
        port rfTherapyOutput : RfOutputPort;
        port alarmOutput : AlarmOutputPort;
        port thermalDoseOutput : ThermalInterfacePort;

        part powerSupply : PowerSupply;
        part rfGenerator : RfGenerator;
        part activeElectrode : ActiveElectrode;
        part returnElectrode : ReturnElectrode;
        part returnMonitor : PatientReturnMonitor;
        part userInterface : UserInterface;
        part safetyController : SafetyController;

        attribute primaryFunction : String =
            "Convert controlled electrical input power into regulated high-frequency radio-frequency energy and deliver it through clinical electrodes to produce localized tissue heating for therapeutic warming, coagulation, or cutting while monitoring patient contact, tissue response, and safety limits.";

        attribute operatingMode : TherapyMode = TherapyMode::standby;
        attribute carrierFrequency : Frequency_Hz = 500000;
        attribute maximumDeliveredPower : Power_W = 400;
        attribute maximumTissueTemperature : Temperature_C = 45;

        connect mainsInput to powerSupply.mainsIn;
        connect powerSupply.dcOut to rfGenerator.dcIn;
        connect therapyCommand to rfGenerator.commandIn;
        connect therapyCommand to safetyController.commandIn;
        connect patientFeedback to rfGenerator.feedbackIn;
        connect patientFeedback to safetyController.feedbackIn;
        connect rfGenerator.rfOut to activeElectrode.rfIn;
        connect rfGenerator.rfOut to rfTherapyOutput;
        connect activeElectrode.tissueDoseOut to thermalDoseOutput;
        connect safetyController.alarmOut to alarmOutput;
        connect returnMonitor.feedbackOut to patientFeedback;
        connect returnElectrode.feedbackOut to patientFeedback;

        state def OperatingStateMachine {
            state initial;
            state Standby;
            state Ready;
            state DeliveringTherapy;
            state Monitoring;
            state Fault;
            state Shutdown;

            transition initial then Standby;

            transition Standby then Ready
                accept UserCommand
                if command.requestedMode != TherapyMode::off;

            transition Ready then DeliveringTherapy
                accept UserCommand
                if command.requestedPower > 0 and command.requestedDuration > 0;

            transition DeliveringTherapy then Monitoring
                accept TissueFeedback
                if feedback.contactState == ElectrodeContactState::acceptable;

            transition Monitoring then DeliveringTherapy
                accept TissueFeedback
                if feedback.tissueTemperature < 45 and feedback.contactState == ElectrodeContactState::acceptable;

            transition DeliveringTherapy then Fault
                accept TissueFeedback
                if feedback.tissueTemperature >= 45 or feedback.contactState == ElectrodeContactState::unsafe;

            transition Monitoring then Fault
                accept TissueFeedback
                if feedback.tissueImpedance < 20 or feedback.tissueImpedance > 300;

            transition Fault then Standby
                accept UserCommand
                if command.requestedMode == TherapyMode::standby;

            transition Standby then Shutdown
                accept UserCommand
                if command.requestedMode == TherapyMode::off;
        }

        action performDiathermyTreatment {
            in item command : UserCommand;
            in item feedback : TissueFeedback;
            out item deliveredRf : RfEnergy;
            out item dose : ThermalDose;
            out item alarm : AlarmSignal;

            first startStandby;
            then validateCommand;
            then evaluatePatientContact;
            then generateControlledRf;
            then deliverEnergyToTissue;
            then monitorThermalDose;
            then stopOrFault;

            action startStandby;
            action validateCommand;
            action evaluatePatientContact;
            action generateControlledRf;
            action deliverEnergyToTissue;
            action monitorThermalDose;
            action stopOrFault;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /* The diathermy system shall deliver controlled high-frequency electrical energy to patient tissue to produce localized heating for therapeutic warming, coagulation, or cutting. */

        subject diathermy : DiathermyUnit;

        require constraint {
            diathermy.carrierFrequency >= 300000 [Hz] and
            diathermy.carrierFrequency <= 1000000 [Hz]
        }
    }

    requirement def PowerControlRequirement {
        doc
        /* The diathermy system shall regulate delivered radio-frequency output power according to the selected clinical mode and requested user setting. */

        subject diathermy : DiathermyUnit;

        require constraint {
            diathermy.maximumDeliveredPower <= 400 [W]
        }
    }

    requirement def TissueTemperatureSafetyRequirement {
        doc
        /* The diathermy system shall inhibit output and generate an alarm when monitored patient tissue temperature exceeds the configured safe limit. */

        subject diathermy : DiathermyUnit;

        require constraint {
            diathermy.maximumTissueTemperature <= 45 [degC]
        }
    }

    requirement def ReturnElectrodeMonitoringRequirement {
        doc
        /* The diathermy system shall monitor return electrode contact quality to reduce the risk of unintended heating at the patient return path. */

        subject monitor : PatientReturnMonitor;

        require constraint {
            monitor.minimumSafeImpedance >= 20 [ohm] and
            monitor.maximumSafeImpedance <= 300 [ohm] and
            monitor.maximumReturnPadTemperature <= 41 [degC]
        }
    }

    requirement def IsolationRequirement {
        doc
        /* The power supply shall provide isolated low-voltage power for the RF generator and limit patient leakage current. */

        subject supply : PowerSupply;

        require constraint {
            supply.isolationLeakageCurrent <= 0.0001 [A]
        }
    }

    satisfy PrimaryFunctionRequirement by DiathermyUnit;
    satisfy PowerControlRequirement by DiathermyUnit;
    satisfy TissueTemperatureSafetyRequirement by DiathermyUnit;
    satisfy ReturnElectrodeMonitoringRequirement by PatientReturnMonitor;
    satisfy IsolationRequirement by PowerSupply;

    part clinicalDiathermySystem : DiathermyUnit {
        attribute carrierFrequency = 500000 [Hz];
        attribute maximumDeliveredPower = 400 [W];
        attribute maximumTissueTemperature = 45 [degC];
    }
}