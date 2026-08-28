package PortableOxygenConcentrator {
    private import ScalarValues::*;
    public import Definitions::*;

    package Definitions {
        item def AmbientAir;
        item def ConcentratedOxygen;
        item def ElectricalPower;

        attribute def OxygenPurity :> Real;
        attribute def FlowRateValue :> Real;
        attribute def PressureValue :> Real;
        attribute def TemperatureValue :> Real;
        attribute def SoundLevelValue :> Real;
        attribute def ChargeLevelValue :> Real;
        attribute def MassValue :> Real;

        attribute def PowerOn;
        attribute def PowerOff;
        attribute def SelfTestPassed;
        attribute def SelfTestFailed;
        attribute def LowOxygenPurity;
        attribute def LowBattery;
        attribute def HighPressure;
        attribute def SystemFault;
        attribute def AlarmCleared;
        attribute def Reset;

        port def AirIntakePort {
            in item air : AmbientAir;
        }
        port def PressurizedAirPort {
            out item air : AmbientAir;
        }
        port def OxygenFlowPort {
            out item oxygen : ConcentratedOxygen;
        }
        port def ExhaustPort {
            out item exhaust : AmbientAir;
        }
        port def PowerInputPort {
            in item power : ElectricalPower;
        }
        port def DCPowerPort {
            out item power : ElectricalPower;
        }
        port def BatteryPowerPort {
            inout item power : ElectricalPower;
        }

        action def CompressAir {
            in item air : AmbientAir;
            out item pressurizedAir : AmbientAir;
        }
        action def SeparateOxygen {
            in item pressurizedAir : AmbientAir;
            out item oxygen : ConcentratedOxygen;
            out item nitrogenWaste : AmbientAir;
        }
        action def AccumulateOxygen {
            in item oxygen : ConcentratedOxygen;
            out item storedOxygen : ConcentratedOxygen;
        }
        action def RegulateFlow {
            in item oxygen : ConcentratedOxygen;
            in flowSetting : FlowRateValue;
            out item regulatedOxygen : ConcentratedOxygen;
        }
        action def DeliverOxygen {
            in item oxygen : ConcentratedOxygen;
        }
        action def MonitorSensors;
        action def TriggerAlarm;
        action def PerformSelfTest;
        action def ShutDown;
        action def ChargeBattery;
        action def ManagePower;
        action def OperateDevice;

        part def SieveBed {
            attribute material : String = "Zeolite";
        }

        part def Compressor {
            port airIn : AirIntakePort;
            port airOut : PressurizedAirPort;
            perform action compressAir : CompressAir;
        }

        part def MolecularSieveUnit {
            port airIn : ~PressurizedAirPort;
            port oxygenOut : OxygenFlowPort;
            port nitrogenOut : ExhaustPort;
            part bed1 : SieveBed;
            part bed2 : SieveBed;
            perform action separateOxygen : SeparateOxygen;
        }

        part def AccumulatorTank {
            port oxygenIn : ~OxygenFlowPort;
            port oxygenOut : OxygenFlowPort;
            perform action accumulateOxygen : AccumulateOxygen;
        }

        part def FlowRegulator {
            port oxygenIn : ~OxygenFlowPort;
            port oxygenOut : OxygenFlowPort;
            attribute flowSetting : FlowRateValue;
            perform action regulateFlow : RegulateFlow;
        }

        part def BatteryPack {
            attribute chargeLevel : ChargeLevelValue;
            port powerPort : BatteryPowerPort;
            perform action chargeBattery : ChargeBattery;
        }

        part def ChargingController {
            port batteryPort : BatteryPowerPort;
        }

        part def ACAdapter {
            port acIn : PowerInputPort;
            port dcOut : DCPowerPort;
        }

        part def PowerSystem {
            port acInput : PowerInputPort;
            port powerOutput : DCPowerPort;
            part acAdapter : ACAdapter;
            part battery : BatteryPack;
            part charger : ChargingController;
            perform action managePower : ManagePower;
            connect acInput to acAdapter.acIn;
            connect acAdapter.dcOut to powerOutput;
            connect battery.powerPort to charger.batteryPort;
        }

        part def SensorArray {
            attribute oxygenPurity : OxygenPurity;
            attribute flowRate : FlowRateValue;
            attribute internalPressure : PressureValue;
            attribute temperature : TemperatureValue;
            attribute batteryCharge : ChargeLevelValue;
            perform action monitorSensors : MonitorSensors;
        }

        part def LCD;
        part def Button;

        part def UserInterface {
            part lcd : LCD;
            part buttons : Button;
        }

        part def AlarmSubsystem {
            attribute audibleEnabled : Boolean = true;
            attribute visualEnabled : Boolean = true;
            perform action triggerAlarm : TriggerAlarm;
        }

        part def ControllerBoard {
            port powerIn : ~DCPowerPort;
            perform action monitorSensors : MonitorSensors;
            perform action triggerAlarm : TriggerAlarm;
            perform action selfTest : PerformSelfTest;
            perform action shutDown : ShutDown;
        }

        part def OxygenConcentrator {
            attribute mass : MassValue;
            attribute soundLevel : SoundLevelValue;
            attribute deliveredOxygenPurity : OxygenPurity;
            attribute targetFlowRate : FlowRateValue;

            port airIntake : AirIntakePort;
            port oxygenOutput : OxygenFlowPort;
            port acInput : PowerInputPort;

            part compressor : Compressor;
            part sieveUnit : MolecularSieveUnit;
            part accumulator : AccumulatorTank;
            part flowRegulator : FlowRegulator;
            part powerSystem : PowerSystem;
            part controller : ControllerBoard;
            part sensors : SensorArray;
            part ui : UserInterface;
            part alarm : AlarmSubsystem;

            perform action deliverOxygen : DeliverOxygen;
            perform action monitorSensors : MonitorSensors;
            perform action selfTest : PerformSelfTest;
            perform action triggerAlarm : TriggerAlarm;
            perform action shutDown : ShutDown;
            perform action operateDevice : OperateDevice;

            connect airIntake to compressor.airIn;
            connect compressor.airOut to sieveUnit.airIn;
            connect sieveUnit.oxygenOut to accumulator.oxygenIn;
            connect accumulator.oxygenOut to flowRegulator.oxygenIn;
            connect flowRegulator.oxygenOut to oxygenOutput;
            connect acInput to powerSystem.acInput;
            connect powerSystem.powerOutput to controller.powerIn;

            exhibit state concentratorStates {
                entry; then off;
                state off;
                state standby {
                    entry selfTest;
                }
                state operational {
                    do operateDevice;
                }
                state alarm {
                    do triggerAlarm;
                }
                state fault {
                    do shutDown;
                }

                transition off_to_standby
                    first off
                    accept PowerOn
                    then standby;
                transition standby_to_operational
                    first standby
                    accept SelfTestPassed
                    then operational;
                transition standby_to_fault
                    first standby
                    accept SelfTestFailed
                    then fault;
                transition operational_to_alarm_purity
                    first operational
                    accept LowOxygenPurity
                    then alarm;
                transition operational_to_alarm_battery
                    first operational
                    accept LowBattery
                    then alarm;
                transition operational_to_alarm_pressure
                    first operational
                    accept HighPressure
                    then alarm;
                transition operational_to_fault
                    first operational
                    accept SystemFault
                    then fault;
                transition alarm_to_operational
                    first alarm
                    accept AlarmCleared
                    then operational;
                transition operational_to_off
                    first operational
                    accept PowerOff
                    then off;
                transition alarm_to_off
                    first alarm
                    accept PowerOff
                    then off;
                transition fault_to_off
                    first fault
                    accept Reset
                    then off;
            }
        }

        requirement def LightweightRequirement {
            doc /* The device shall weigh less than 3 kg. */
            subject device : OxygenConcentrator;
            constraint { device.mass < 3.0 }
        }

        requirement def QuietOperationRequirement {
            doc /* The device shall operate quietly to minimize disruption. */
            subject device : OxygenConcentrator;
            constraint { device.soundLevel < 45.0 }
        }

        requirement def OxygenPurityRequirement {
            doc /* The delivered oxygen shall have a purity of at least 90 percent. */
            subject device : OxygenConcentrator;
            constraint { device.deliveredOxygenPurity >= 90.0 }
        }

        requirement def FlowRateRangeRequirement {
            doc /* The flow regulator shall allow adjustment from 0.5 to 5.0 liters per minute. */
            subject regulator : FlowRegulator;
            constraint { regulator.flowSetting >= 0.5 and regulator.flowSetting <= 5.0 }
        }

        requirement def DualPowerRequirement {
            doc /* The device shall operate from AC mains or a rechargeable battery pack. */
            subject device : OxygenConcentrator;
        }

        requirement def AlarmSafetyRequirement {
            doc /* The device shall provide audible and visual alarms for safety conditions. */
            subject alarmSub : AlarmSubsystem;
            constraint { alarmSub.audibleEnabled and alarmSub.visualEnabled }
        }
    }

    package Usages {
        private import Definitions::*;

        part concentrator : OxygenConcentrator {
            mass = 2.8;
            soundLevel = 42.0;
            deliveredOxygenPurity = 93.0;
            targetFlowRate = 2.0;
        }

        requirement lightweightReq : LightweightRequirement {
            subject device = concentrator;
        }
        satisfy lightweightReq by concentrator;

        requirement quietReq : QuietOperationRequirement {
            subject device = concentrator;
        }
        satisfy quietReq by concentrator;

        requirement purityReq : OxygenPurityRequirement {
            subject device = concentrator;
        }
        satisfy purityReq by concentrator;

        requirement flowRateReq : FlowRateRangeRequirement {
            subject regulator = concentrator.flowRegulator;
        }
        satisfy flowRateReq by concentrator.flowRegulator;

        requirement dualPowerReq : DualPowerRequirement {
            subject device = concentrator;
        }
        satisfy dualPowerReq by concentrator;

        requirement alarmSafetyReq : AlarmSafetyRequirement {
            subject alarmSub = concentrator.alarm;
        }
        satisfy alarmSafetyReq by concentrator.alarm;
    }
}
