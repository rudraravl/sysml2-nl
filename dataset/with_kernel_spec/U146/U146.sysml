package 'Arctic Sun Temperature Management System' {
    private import ScalarValues::*;

    package Types {
        private import ScalarValues::*;

        attribute def TemperatureValue :> Real;
        attribute def VolumeValue :> Real;

        item def CoolingFluid;
        item def TempReading {
            attribute value : TemperatureValue;
        }
        item def LevelReading {
            attribute volume : VolumeValue;
            attribute isLow : Boolean;
        }
        item def PumpCmd {
            attribute speed : Real = 1.0;
        }
        item def HeaterCmd {
            attribute setpoint : TemperatureValue = 33.0;
        }
        item def AlarmMsg {
            attribute code : String;
            attribute text : String;
        }
        item def TherapySettings {
            attribute targetTemp : TemperatureValue;
            attribute maintenanceDuration : Integer;
        }

        attribute def StartTherapy;
        attribute def StopTherapy;
        attribute def StartRewarming;
        attribute def PrimeComplete;
        attribute def PowerLoss;
        attribute def PowerRestored;

        port def FluidOut {
            out item fluid : CoolingFluid;
        }
        port def FluidIn {
            in item fluid : CoolingFluid;
        }
        port def TempOutPort {
            out item temp : TempReading;
        }
        port def TempInPort {
            in item temp : TempReading;
        }
        port def LevelOutPort {
            out item level : LevelReading;
        }
        port def LevelInPort {
            in item level : LevelReading;
        }
        port def CmdOutPort {
            out item cmd : PumpCmd;
        }
        port def CmdInPort {
            in item cmd : PumpCmd;
        }
        port def HtrCmdOutPort {
            out item cmd : HeaterCmd;
        }
        port def HtrCmdInPort {
            in item cmd : HeaterCmd;
        }
        port def AlarmOutPort {
            out item alarm : AlarmMsg;
        }
        port def AlarmInPort {
            in item alarm : AlarmMsg;
        }
        port def UiOutPort {
            out item params : TherapySettings;
        }
        port def UiInPort {
            in item params : TherapySettings;
        }
    }

    package Components {
        private import ScalarValues::*;
        private import Types::*;

        part def FluidReservoir {
            attribute volume : VolumeValue = 2.0;
            attribute lowLevelThreshold : VolumeValue = 0.5;
            port fluidOut : FluidOut;
            port fluidReturn : FluidIn;
            port levelOut : LevelOutPort;
        }

        part def CirculationPump {
            attribute speed : Real = 0.0;
            port fluidIn : FluidIn;
            port fluidOut : FluidOut;
            port cmdIn : CmdInPort;
            exhibit state pumpStates {
                entry; then off;
                state off;
                state running;
                transition off_to_running
                    first off
                    accept cmd : PumpCmd via cmdIn
                    if cmd.speed > 0.0
                    then running;
                transition running_to_off
                    first running
                    accept cmd : PumpCmd via cmdIn
                    then off;
            }
        }

        part def HeatExchanger {
            attribute currentSetpoint : TemperatureValue = 20.0;
            port fluidIn : FluidIn;
            port fluidOut : FluidOut;
            port cmdIn : HtrCmdInPort;
            exhibit state exchangerStates {
                entry; then idle;
                state idle;
                state active;
                transition idle_to_active
                    first idle
                    accept cmd : HeaterCmd via cmdIn
                    then active;
                transition active_to_idle
                    first active
                    accept cmd : HeaterCmd via cmdIn
                    then idle;
            }
        }

        part def CoolingPad {
            attribute padId : String;
            port fluidIn : FluidIn;
            port fluidOut : FluidOut;
        }

        part def Manifold {
            port fluidIn : FluidIn;
            port fluidOut1 : FluidOut;
            port fluidOut2 : FluidOut;
            port fluidOut3 : FluidOut;
            port fluidOut4 : FluidOut;
            port fluidReturn1 : FluidIn;
            port fluidReturn2 : FluidIn;
            port fluidReturn3 : FluidIn;
            port fluidReturn4 : FluidIn;
            port fluidReturn : FluidOut;
        }

        part def Patient {
            attribute coreTemp : TemperatureValue = 37.0;
            part pad1 : CoolingPad;
            part pad2 : CoolingPad;
            part pad3 : CoolingPad;
            part pad4 : CoolingPad;
            part manifold : Manifold;
            flow f1 of CoolingFluid from manifold.fluidOut1.fluid to pad1.fluidIn.fluid;
            flow f2 of CoolingFluid from manifold.fluidOut2.fluid to pad2.fluidIn.fluid;
            flow f3 of CoolingFluid from manifold.fluidOut3.fluid to pad3.fluidIn.fluid;
            flow f4 of CoolingFluid from manifold.fluidOut4.fluid to pad4.fluidIn.fluid;
            flow r1 of CoolingFluid from pad1.fluidOut.fluid to manifold.fluidReturn1.fluid;
            flow r2 of CoolingFluid from pad2.fluidOut.fluid to manifold.fluidReturn2.fluid;
            flow r3 of CoolingFluid from pad3.fluidOut.fluid to manifold.fluidReturn3.fluid;
            flow r4 of CoolingFluid from pad4.fluidOut.fluid to manifold.fluidReturn4.fluid;
        }

        part def TempSensor {
            attribute value : TemperatureValue;
            port tempOut : TempOutPort;
        }

        part def AlarmModule {
            port alarmIn : AlarmInPort;
            exhibit state alarmStates {
                entry; then silent;
                state silent;
                state active;
                transition silent_to_active
                    first silent
                    accept a : AlarmMsg via alarmIn
                    if a.code != "CLEAR"
                    then active;
                transition active_to_silent
                    first active
                    accept a : AlarmMsg via alarmIn
                    if a.code == "CLEAR"
                    then silent;
            }
        }

        part def UserInterface {
            port uiOut : UiOutPort;
            attribute displayText : String;
        }

        part def PowerSupply {
            attribute hasAC : Boolean = true;
            attribute batteryLifeMin : Integer = 30;
            port alarmOut : AlarmOutPort;
            exhibit state powerStates {
                entry; then acPower;
                state acPower;
                state batteryBackup;
                transition ac_to_battery
                    first acPower
                    accept PowerLoss
                    then batteryBackup;
                transition battery_to_ac
                    first batteryBackup
                    accept PowerRestored
                    then acPower;
            }
        }

        part def ControlModule {
            port coreTempIn : TempInPort;
            port fluidTempIn : TempInPort;
            port levelIn : LevelInPort;
            port pumpCmdOut : CmdOutPort;
            port heaterCmdOut : HtrCmdOutPort;
            port alarmOut : AlarmOutPort;
            port uiIn : UiInPort;
            attribute targetTemp : TemperatureValue = 33.0;
            attribute currentPhase : String = "none";

            exhibit state systemStates {
                entry; then standby;
                state standby;
                state priming;
                state active {
                    do send new PumpCmd() to pumpCmdOut;
                    do send new HeaterCmd() to heaterCmdOut;
                }
                transition standby_to_priming
                    first standby
                    accept params : TherapySettings via uiIn
                    then priming;
                transition priming_to_active
                    first priming
                    accept PrimeComplete
                    then active;
                transition active_to_standby
                    first active
                    accept StopTherapy
                    do send new PumpCmd() to pumpCmdOut
                    then standby;
            }

            exhibit state therapyStates {
                entry; then induction;
                state induction;
                state maintenance;
                state rewarming;
                state complete;
                transition induction_to_maintenance
                    first induction
                    accept t : TempReading via coreTempIn
                    if t.value <= targetTemp + 0.1
                    then maintenance;
                transition maintenance_to_rewarming
                    first maintenance
                    accept StartRewarming
                    then rewarming;
                transition rewarming_to_complete
                    first rewarming
                    accept t2 : TempReading via coreTempIn
                    if t2.value >= 37.0
                    then complete;
            }

            exhibit state monitorStates {
                entry; then normal;
                state normal;
                state deviated;
                transition normal_to_deviated
                    first normal
                    accept lvl : LevelReading via levelIn
                    if lvl.isLow == true
                    then deviated;
                transition deviated_to_normal
                    first deviated
                    accept lvl2 : LevelReading via levelIn
                    if lvl2.isLow == false
                    then normal;
            }
        }
    }

    package System {
        private import ScalarValues::*;
        private import Types::*;
        private import Components::*;

        part def ArcticSunSystem {
            part controller : ControlModule;
            part reservoir : FluidReservoir;
            part pump : CirculationPump;
            part heatExchanger : HeatExchanger;
            part patient : Patient;
            part coreSensor : TempSensor;
            part fluidSensor : TempSensor;
            part alarm : AlarmModule;
            part ui : UserInterface;
            part power : PowerSupply;

            flow reservoirToPump of CoolingFluid from reservoir.fluidOut.fluid to pump.fluidIn.fluid;
            flow pumpToHeatExchanger of CoolingFluid from pump.fluidOut.fluid to heatExchanger.fluidIn.fluid;
            flow heatExchangerToPatient of CoolingFluid from heatExchanger.fluidOut.fluid to patient.manifold.fluidIn.fluid;
            flow patientToReservoir of CoolingFluid from patient.manifold.fluidReturn.fluid to reservoir.fluidReturn.fluid;

            flow coreTempFlow of TempReading from coreSensor.tempOut.temp to controller.coreTempIn.temp;
            flow fluidTempFlow of TempReading from fluidSensor.tempOut.temp to controller.fluidTempIn.temp;
            flow levelFlow of LevelReading from reservoir.levelOut.level to controller.levelIn.level;
            flow pumpCmdFlow of PumpCmd from controller.pumpCmdOut.cmd to pump.cmdIn.cmd;
            flow heaterCmdFlow of HeaterCmd from controller.heaterCmdOut.cmd to heatExchanger.cmdIn.cmd;
            flow alarmFlow1 of AlarmMsg from controller.alarmOut.alarm to alarm.alarmIn.alarm;
            flow alarmFlow2 of AlarmMsg from power.alarmOut.alarm to alarm.alarmIn.alarm;
            flow uiFlow of TherapySettings from ui.uiOut.params to controller.uiIn.params;
        }
    }

    package Requirements {
        private import ScalarValues::*;
        private import Types::*;

        requirement def TempControlRequirement {
            attribute targetTemp : TemperatureValue;
            attribute actualTemp : TemperatureValue;
            require constraint { actualTemp >= targetTemp - 0.1 and actualTemp <= targetTemp + 0.1 }
        }

        requirement def BatteryBackupRequirement {
            attribute minDurationMin : Integer;
            require constraint { minDurationMin >= 30 }
        }

        requirement def FluidLevelSafetyRequirement {
            attribute minLevel : VolumeValue;
            attribute actualLevel : VolumeValue;
            require constraint { actualLevel >= minLevel }
        }

        requirement tempControl : TempControlRequirement {
            :>> targetTemp = 33.0;
        }

        requirement batteryBackup : BatteryBackupRequirement {
            :>> minDurationMin = 30;
        }

        requirement fluidLevelSafety : FluidLevelSafetyRequirement {
            :>> minLevel = 0.5;
        }
    }
}
