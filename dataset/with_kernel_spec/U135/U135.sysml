package VADSystemModel {
    private import SI::*;
    private import ScalarValues::*;

    value type BloodPressureValue :> Real;
    value type BloodFlowRateValue :> Real;
    value type HeartRateValue :> Real;
    value type RotationalSpeedValue :> Real;
    value type VoltageValue :> Real;
    value type CurrentValue :> Real;
    value type SwitchOverTimeValue :> Real;

    item def Blood {
        attribute pressure : BloodPressureValue;
        attribute flowRate : BloodFlowRateValue;
    }
    item def ElectricPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    item def SensorData {
        attribute bloodPressure : BloodPressureValue;
        attribute bloodFlowRate : BloodFlowRateValue;
        attribute heartRate : HeartRateValue;
    }
    item def ControlSignal {
        attribute pumpSpeed : RotationalSpeedValue;
    }
    item def AlarmSignal {
        attribute active : Boolean;
        attribute msg : String;
    }

    port def BloodInPort {
        in item blood : Blood;
    }
    port def BloodOutPort {
        out item blood : Blood;
    }
    port def PowerInPort {
        in item power : ElectricPower;
    }
    port def PowerOutPort {
        out item power : ElectricPower;
    }
    port def DataInPort {
        in item data : SensorData;
    }
    port def DataOutPort {
        out item data : SensorData;
    }
    port def CmdInPort {
        in item cmd : ControlSignal;
    }
    port def CmdOutPort {
        out item cmd : ControlSignal;
    }
    port def AlarmOutPort {
        out item alarm : AlarmSignal;
    }

    function ComputeDesiredSpeed {
        in bloodPressure : BloodPressureValue;
        in bloodFlowRate : BloodFlowRateValue;
        in heartRate : HeartRateValue;
        return speed : RotationalSpeedValue;
    }

    part def Impeller {
        attribute speed : RotationalSpeedValue;
        attribute levitated : Boolean = true;
        port bloodIn : BloodInPort;
        port bloodOut : BloodOutPort;
    }
    part def BrushlessMotor {
        port powerIn : PowerInPort;
        port controlIn : CmdInPort;
    }
    part def MagneticBearings {
        attribute levitationActive : Boolean = true;
    }
    part def BiocompatibleHousing {
        attribute material : String = 'biocompatible';
    }

    state machine def PumpOperation {
        initial state idle;
        state running;
        transition from idle to running on startCommand;
        transition from running to idle on stopCommand;
    }

    part def RotaryBloodPumpAssembly {
        port bloodInlet : BloodInPort;
        port bloodOutlet : BloodOutPort;
        port powerIn : PowerInPort;
        port controlIn : CmdInPort;
        attribute currentSpeed : RotationalSpeedValue;
        part impeller : Impeller;
        part motor : BrushlessMotor;
        part magneticBearings : MagneticBearings;
        part housing : BiocompatibleHousing;
        event occurrence startCommand;
        event occurrence stopCommand;
        state machine pumpOperation : PumpOperation;
        bind bloodInlet.blood = impeller.bloodIn.blood;
        bind impeller.bloodOut.blood = bloodOutlet.blood;
        bind powerIn.power = motor.powerIn.power;
        bind controlIn.cmd = motor.controlIn.cmd;
    }

    part def Cannula {
        port endA : BloodInPort;
        port endB : BloodOutPort;
    }
    part def CannulaSystem {
        part inletCannula : Cannula;
        part outletCannula : Cannula;
    }

    part def SensorArray {
        port dataIn : DataInPort;
        port dataOut : DataOutPort;
    }

    state machine def AlarmStates {
        initial state normal;
        state alert;
        transition from normal to alert on faultDetected;
        transition from alert to normal on faultCleared;
    }

    part def AlarmManager {
        port dataIn : DataInPort;
        port alarmOut : AlarmOutPort;
        attribute faultActive : Boolean = false;
        event occurrence faultDetected;
        event occurrence faultCleared;
        state machine alarmStates : AlarmStates;
    }

    part def Microcontroller {
        port dataIn : DataInPort;
        port cmdOut : CmdOutPort;
        action analyzeFeedback {
            in data : SensorData = dataIn.data;
            out cmd : ControlSignal = cmdOut.cmd;
        }
    }

    part def ControlSystem {
        port vitalSignsIn : DataInPort;
        port cmdOut : CmdOutPort;
        port powerIn : PowerInPort;
        part sensorArray : SensorArray;
        part microcontroller : Microcontroller;
        part alarmManager : AlarmManager;
        connect vitalSignsIn to sensorArray.dataIn;
        connect sensorArray.dataOut to microcontroller.dataIn;
        connect sensorArray.dataOut to alarmManager.dataIn;
        connect microcontroller.cmdOut to cmdOut;
    }

    part def ExternalBattery {
        port powerOut : PowerOutPort;
        attribute depleted : Boolean = false;
    }
    part def BackupBattery {
        port powerOut : PowerOutPort;
        attribute available : Boolean = true;
        attribute chargeLevel : Real;
    }
    part def PowerConverter {
        port input : PowerInPort;
        port output : PowerOutPort;
    }

    state machine def PowerStates {
        initial state primaryActive;
        state backupActive;
        state fault;
        transition from primaryActive to backupActive on primaryDepleted;
        transition from backupActive to fault on backupDepleted;
        transition from fault to primaryActive on primaryRestored;
    }

    part def PowerModule {
        port powerOut : PowerOutPort;
        part externalBattery : ExternalBattery;
        part backupBattery : BackupBattery;
        part powerConverter : PowerConverter;
        attribute switchOverTime : SwitchOverTimeValue;
        event occurrence primaryDepleted;
        event occurrence backupDepleted;
        event occurrence primaryRestored;
        state machine powerStates : PowerStates;
        connect externalBattery.powerOut to powerConverter.input;
        connect backupBattery.powerOut to powerConverter.input;
        connect powerConverter.output to powerOut;
    }

    part def Patient {
        attribute heartRate : HeartRateValue;
        attribute bloodPressure : BloodPressureValue;
        port heartOut : BloodOutPort;
        port aortaIn : BloodInPort;
        port vitalSignsOut : DataOutPort;
    }

    requirement def ContinuousFlowRequirement {
        doc /* The VAD shall maintain continuous blood flow within physiological limits. */
        subject pumpAssembly : RotaryBloodPumpAssembly;
        attribute minFlow : BloodFlowRateValue = 3.0;
        attribute maxFlow : BloodFlowRateValue = 7.0;
        require constraint { pumpAssembly.bloodOutlet.blood.flowRate >= minFlow }
        require constraint { pumpAssembly.bloodOutlet.blood.flowRate <= maxFlow }
    }
    requirement def MagneticLevitationRequirement {
        doc /* The impeller shall be levitated by magnetic bearings to minimize friction and blood damage. */
        subject pumpAssembly : RotaryBloodPumpAssembly;
        require constraint { pumpAssembly.impeller.levitated == true }
        require constraint { pumpAssembly.magneticBearings.levitationActive == true }
    }
    requirement def BiocompatibilityRequirement {
        doc /* The pump housing shall be made of biocompatible materials. */
        subject pumpAssembly : RotaryBloodPumpAssembly;
        require constraint { pumpAssembly.housing.material == 'biocompatible' }
    }
    requirement def AutomaticSpeedAdjustmentRequirement {
        doc /* The control system shall automatically adjust pump speed based on patient vital signs. */
        subject controller : ControlSystem;
        attribute vitalSigns : SensorData;
        require constraint { controller.cmdOut.cmd.pumpSpeed == ComputeDesiredSpeed(vitalSigns.bloodPressure, vitalSigns.bloodFlowRate, vitalSigns.heartRate) }
    }
    requirement def BackupPowerRequirement {
        doc /* The power module shall automatically switch to backup battery when primary power is depleted. */
        subject powerModule : PowerModule;
        attribute maxSwitchTime : SwitchOverTimeValue = 100.0;
        require constraint { powerModule.backupBattery.available == true }
        require constraint { powerModule.switchOverTime <= maxSwitchTime }
    }
    requirement def AlarmManagementRequirement {
        doc /* The control system shall detect fault conditions and alert the patient or clinician. */
        subject alarmManager : AlarmManager;
        require constraint { alarmManager.faultActive implies alarmManager.alarmOut.alarm.active }
    }

    part def VADSystem {
        part patient : Patient;
        part pump : RotaryBloodPumpAssembly;
        part cannula : CannulaSystem;
        part controller : ControlSystem;
        part power : PowerModule;
        connect patient.heartOut to cannula.inletCannula.endA;
        connect cannula.inletCannula.endB to pump.bloodInlet;
        connect pump.bloodOutlet to cannula.outletCannula.endA;
        connect cannula.outletCannula.endB to patient.aortaIn;
        connect patient.vitalSignsOut to controller.vitalSignsIn;
        connect controller.cmdOut to pump.controlIn;
        connect power.powerOut to pump.powerIn;
        connect power.powerOut to controller.powerIn;
        requirement continuousFlow : ContinuousFlowRequirement {
            subject pumpAssembly = pump;
        }
        requirement magneticLevitation : MagneticLevitationRequirement {
            subject pumpAssembly = pump;
        }
        requirement biocompatibility : BiocompatibilityRequirement {
            subject pumpAssembly = pump;
        }
        requirement automaticSpeedAdjustment : AutomaticSpeedAdjustmentRequirement {
            subject controller = controller;
        }
        requirement backupPower : BackupPowerRequirement {
            subject powerModule = power;
        }
        requirement alarmManagement : AlarmManagementRequirement {
            subject alarmManager = controller.alarmManager;
        }
    }
}
