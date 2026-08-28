package MedicalInfusionPumpSystem {
    private import ScalarValues::*;

    attribute def FlowRateValue :> Real;
    attribute def VolumeValue :> Real;
    attribute def PressureValue :> Real;
    attribute def DurationValue :> Real;
    attribute def BatteryLevelValue :> Real;

    item def TherapeuticFluid;
    item def Medication :> TherapeuticFluid;
    item def Nutrient :> TherapeuticFluid;

    attribute def PowerOn;
    attribute def PowerOff;
    attribute def SelfTestPass;
    attribute def SelfTestFail;
    attribute def ProgramDelivery;
    attribute def PrimeComplete;
    attribute def PauseCommand;
    attribute def ResumeCommand;
    attribute def StopCommand;
    attribute def OcclusionDetected;
    attribute def AirInLineDetected;
    attribute def EmptyReservoirDetected;
    attribute def LowBatteryDetected;
    attribute def ResetAlarm;

    port def FluidPort {
        ref item fluid : TherapeuticFluid;
    }
    port def SignalPort;
    port def PowerPort;

    action def PerformSelfTest;
    action def PrimeTubing;
    action def DeliverFluid {
        in rate : FlowRateValue;
        out deliveredVolume : VolumeValue;
    }
    action def StopDelivery;
    action def TriggerAlarm;
    action def SoundAudibleAlarm;
    action def FlashVisualAlarm;
    action def ActivateAlarm {
        action soundAlarm : SoundAudibleAlarm;
        action flashAlarm : FlashVisualAlarm;
    }
    action def AdjustPumpSpeed {
        in currentFlow : FlowRateValue;
        in targetFlow : FlowRateValue;
        out speed : Real;
    }
    action def SensePressure { out pressure : PressureValue; }
    action def SenseFlow { out flowRate : FlowRateValue; }
    action def DetectAir { out airDetected : Boolean; }
    action def SenseLevel { out volume : VolumeValue; }
    action def ManagePower { out batteryLevel : BatteryLevelValue; }
    action def UpdateUserInterface;

    part def FluidReservoir {
        attribute capacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        port fluidOut : FluidPort;
        port levelSignalOut : SignalPort;
        perform action senseLevel : SenseLevel;
    }

    part def PumpingMechanism {
        attribute currentSpeed : Real;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port controlIn : SignalPort;
        perform action deliverFluid : DeliverFluid;
        perform action adjustPumpSpeed : AdjustPumpSpeed;
    }

    part def PressureSensor {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port signalOut : SignalPort;
        attribute occlusionThreshold : PressureValue;
        perform action sensePressure : SensePressure;
    }

    part def FlowSensor {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port signalOut : SignalPort;
        perform action senseFlow : SenseFlow;
    }

    part def AirDetector {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port signalOut : SignalPort;
        perform action detectAir : DetectAir;
    }

    part def ControlProcessor {
        attribute targetFlowRate : FlowRateValue;
        attribute targetVolume : VolumeValue;
        attribute deliveredVolume : VolumeValue;
        attribute maxPressure : PressureValue;

        port sensorInput : SignalPort;
        port pumpControl : SignalPort;
        port alarmControl : SignalPort;
        port uiOutput : SignalPort;
        port powerInput : PowerPort;

        perform action adjustPumpSpeed : AdjustPumpSpeed;
        perform action updateUI : UpdateUserInterface;
    }

    part def AlarmSubsystem {
        port alarmControl : SignalPort;
        perform action soundAudibleAlarm : SoundAudibleAlarm;
        perform action flashVisualAlarm : FlashVisualAlarm;
    }

    part def PowerManagementUnit {
        attribute batteryLevel : BatteryLevelValue;
        attribute mainsPresent : Boolean;
        port mainPower : PowerPort;
        port batteryPower : PowerPort;
        port powerOut : PowerPort;
        port statusOut : SignalPort;
        perform action managePower : ManagePower;
    }

    part def Battery {
        attribute chargeLevel : BatteryLevelValue;
        port powerOut : PowerPort;
    }

    part def UserInterface {
        port controlOut : SignalPort;
        port statusIn : SignalPort;
    }

    requirement def FlowRateAccuracy {
        doc /* The pump shall maintain flow rate within ±5% of the programmed target. */
    }
    requirement def OcclusionSafety {
        doc /* The pump shall detect occlusions and halt delivery when line pressure exceeds the threshold. */
    }
    requirement def AirDetectionSafety {
        doc /* The pump shall detect air bubbles in the fluid line and halt delivery immediately. */
    }
    requirement def EmptyReservoirSafety {
        doc /* The pump shall detect an empty reservoir and halt delivery before air enters the line. */
    }
    requirement def BatteryBackupDuration {
        doc /* The battery shall provide at least 4 hours of continuous operation at maximum flow rate. */
    }
    requirement def AlarmPersistence {
        doc /* Alarms shall remain active until acknowledged and cleared by the user. */
    }

    part def InfusionPump {
        attribute targetFlowRate : FlowRateValue;
        attribute targetVolume : VolumeValue;
        attribute deliveredVolume : VolumeValue;
        attribute batteryLevel : BatteryLevelValue;
        attribute alarmActive : Boolean;

        port patientPort : FluidPort;
        port userPort : SignalPort;
        port mainPowerPort : PowerPort;

        part reservoir : FluidReservoir;
        part pump : PumpingMechanism;
        part pressureSensor : PressureSensor;
        part flowSensor : FlowSensor;
        part airDetector : AirDetector;
        part controller : ControlProcessor;
        part alarm : AlarmSubsystem;
        part power : PowerManagementUnit;
        part battery : Battery;
        part ui : UserInterface;

        connect reservoir.fluidOut to pump.fluidIn;
        connect pump.fluidOut to pressureSensor.fluidIn;
        connect pressureSensor.fluidOut to flowSensor.fluidIn;
        connect flowSensor.fluidOut to airDetector.fluidIn;
        connect airDetector.fluidOut to patientPort;

        connect reservoir.levelSignalOut to controller.sensorInput;
        connect pressureSensor.signalOut to controller.sensorInput;
        connect flowSensor.signalOut to controller.sensorInput;
        connect airDetector.signalOut to controller.sensorInput;

        connect controller.pumpControl to pump.controlIn;
        connect controller.alarmControl to alarm.alarmControl;
        connect controller.uiOutput to ui.statusIn;
        connect ui.controlOut to userPort;

        connect mainPowerPort to power.mainPower;
        connect battery.powerOut to power.batteryPower;
        connect power.powerOut to controller.powerInput;
        connect power.statusOut to controller.sensorInput;

        requirement req1 : FlowRateAccuracy;
        requirement req2 : OcclusionSafety;
        requirement req3 : AirDetectionSafety;
        requirement req4 : EmptyReservoirSafety;
        requirement req5 : BatteryBackupDuration;
        requirement req6 : AlarmPersistence;

        satisfy req1;
        satisfy req2;
        satisfy req3;
        satisfy req4;
        satisfy req5;
        satisfy req6;

        exhibit state pumpStates {
            entry; then off;

            state off;
            accept PowerOn
                do action startSelfTest : PerformSelfTest
                then selfTest;

            state selfTest;
            accept SelfTestPass
                then standby;
            accept SelfTestFail
                do action raiseFault : TriggerAlarm
                then alarmState;

            state standby;
            accept ProgramDelivery
                then priming;
            accept PowerOff
                then off;

            state priming {
                entry action primeTubing : PrimeTubing;
            }
            accept PrimeComplete
                then active;

            state active {
                do action deliver : DeliverFluid {
                    in rate = targetFlowRate;
                }
            }
            accept PauseCommand
                then paused;
            accept OcclusionDetected
                do action raiseOcclusion : TriggerAlarm
                then alarmState;
            accept AirInLineDetected
                do action raiseAir : TriggerAlarm
                then alarmState;
            accept EmptyReservoirDetected
                do action raiseEmpty : TriggerAlarm
                then alarmState;
            accept LowBatteryDetected
                do action raiseLowBattery : TriggerAlarm
                then alarmState;
            accept StopCommand
                then standby;

            state paused;
            accept ResumeCommand
                then active;
            accept StopCommand
                then standby;

            state alarmState {
                entry action stopDelivery : StopDelivery;
                do action activateAlarm : ActivateAlarm;
            }
            accept ResetAlarm
                then standby;
            accept PowerOff
                then off;
        }
    }
}
