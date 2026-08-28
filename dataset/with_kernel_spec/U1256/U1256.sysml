package 'WashingMachineSystem' {
	private import ScalarValues::Real;
	private import ScalarValues::Integer;
	private import ScalarValues::Boolean;
	private import ScalarValues::String;

	package Definitions {
		item def CleanWater;
		item def DirtyWater;
		item def Detergent;
		item def Laundry;
		item def ElectricalPower;

		attribute def VolumeValue :> Real;
		attribute def TempValue :> Real;
		attribute def RPMValue :> Real;

		attribute def StartCycleSignal;
		attribute def WaterLevelReachedSignal;
		attribute def TargetTempReachedSignal;
		attribute def WashCompleteSignal;
		attribute def DrumEmptySignal;
		attribute def RinseCompleteSignal;
		attribute def SpinCompleteSignal;
		attribute def CycleCompleteSignal;

		attribute def WashProgram :> String;

		port def WaterPort {
			out item water : CleanWater;
		}
		port def DirtyWaterPort {
			out item dirtyWater : DirtyWater;
		}
		port def PowerPort {
			out item power : ElectricalPower;
		}
		port def MotorCommandPort {
			out attribute speed : RPMValue;
		}
		port def HeaterCommandPort {
			out attribute targetTemp : TempValue;
		}
		port def ValveCommandPort {
			out attribute isOpen : Boolean;
		}
		port def PumpCommandPort {
			out attribute isPumping : Boolean;
		}
		port def LockCommandPort {
			out attribute isLocked : Boolean;
		}
		port def ProgramSelectPort {
			out attribute program : WashProgram;
		}
		port def LevelSensorPort {
			out attribute level : VolumeValue;
		}
		port def TempSensorPort {
			out attribute temp : TempValue;
		}

		part def WaterSupply {
			port waterOut : WaterPort;
		}
		part def SewerDrain {
			port waterIn : ~DirtyWaterPort;
		}
		part def ElectricalGrid {
			port powerOut : PowerPort;
		}

		part def DrumAssembly {
			port waterIn : ~WaterPort;
			port drainOut : DirtyWaterPort;
			port motorIn : ~MotorCommandPort;
			item laundry : Laundry;
			item detergent : Detergent;
			item water : CleanWater;
			attribute capacity : VolumeValue;
			attribute currentLoad : VolumeValue;
			attribute currentSpeed : RPMValue;
		}

		part def DriveMotor {
			port controlIn : ~MotorCommandPort;
			port shaftOut : MotorCommandPort;
			attribute speed : RPMValue;
		}

		part def WaterInletValve {
			port waterIn : ~WaterPort;
			port waterOut : WaterPort;
			port controlIn : ~ValveCommandPort;
			attribute isOpen : Boolean;
		}

		part def DrainPump {
			port waterIn : ~DirtyWaterPort;
			port waterOut : DirtyWaterPort;
			port controlIn : ~PumpCommandPort;
			attribute isPumping : Boolean;
		}

		part def WaterHeater {
			port waterIn : ~WaterPort;
			port waterOut : WaterPort;
			port controlIn : ~HeaterCommandPort;
			port powerIn : ~PowerPort;
			attribute isHeating : Boolean;
			attribute currentTemp : TempValue;
		}

		part def WaterLevelSensor {
			port levelOut : LevelSensorPort;
			attribute level : VolumeValue;
		}

		part def TemperatureSensor {
			port tempOut : TempSensorPort;
			attribute temp : TempValue;
		}

		part def DoorLock {
			port controlIn : ~LockCommandPort;
			attribute isLocked : Boolean;
		}

		part def DetergentDispenser {
			port controlIn : ~ValveCommandPort;
			item detergent : Detergent;
			attribute isDispensing : Boolean;
		}

		part def ControlModule {
			port powerIn : ~PowerPort;
			port programSelect : ~ProgramSelectPort;
			port motorControl : MotorCommandPort;
			port valveControl : ValveCommandPort;
			port pumpControl : PumpCommandPort;
			port heaterControl : HeaterCommandPort;
			port lockControl : LockCommandPort;
			port detergentControl : ValveCommandPort;
			port levelFeedback : ~LevelSensorPort;
			port tempFeedback : ~TempSensorPort;
			attribute selectedProgram : WashProgram;
			attribute targetWaterLevel : VolumeValue;
			attribute targetTemp : TempValue;
			attribute washDuration : Real;
			attribute rinseCount : Integer;
			attribute spinSpeed : RPMValue;
		}

		part def WashingMachine {
			port waterIn : ~WaterPort;
			port waterOut : DirtyWaterPort;
			port powerIn : ~PowerPort;
			port programSelect : ~ProgramSelectPort;

			part drum : DrumAssembly;
			part motor : DriveMotor;
			part inletValve : WaterInletValve;
			part drainPump : DrainPump;
			part heater : WaterHeater;
			part control : ControlModule;
			part levelSensor : WaterLevelSensor;
			part tempSensor : TemperatureSensor;
			part doorLock : DoorLock;
			part detergentDispenser : DetergentDispenser;
		}

		action def LockDoorAction {
			out isLocked : Boolean;
		}
		action def UnlockDoorAction {
			out isUnlocked : Boolean;
		}
		action def OpenValveAction {
			out isOpen : Boolean;
		}
		action def CloseValveAction {
			out isClosed : Boolean;
		}
		action def EnableHeaterAction {
			in targetTemp : TempValue;
			out isHeating : Boolean;
		}
		action def DisableHeaterAction {
			out isHeating : Boolean;
		}
		action def TumbleAction {
			in duration : Real;
			in speed : RPMValue;
		}
		action def EnablePumpAction {
			out isPumping : Boolean;
		}
		action def DisablePumpAction {
			out isPumping : Boolean;
		}
		action def SpinAction {
			in speed : RPMValue;
			in duration : Real;
		}
		action def DispenseDetergentAction {
			out isDispensing : Boolean;
		}

		state def WashCycleStates {
			entry; then idle;

			state idle;
			accept StartCycleSignal
				do action lockDoor : LockDoorAction { out isLocked = true; }
				then filling;

			state filling {
				do action openValve : OpenValveAction { out isOpen = true; }
			}
			accept WaterLevelReachedSignal
				do action closeValve : CloseValveAction { out isClosed = true; }
				then heating;

			state heating {
				do action enableHeater : EnableHeaterAction {
					in targetTemp = 60.0;
					out isHeating = true;
				}
			}
			accept TargetTempReachedSignal
				do action disableHeater : DisableHeaterAction { out isHeating = false; }
				then addingDetergent;

			state addingDetergent {
				do action dispenseDetergent : DispenseDetergentAction { out isDispensing = true; }
			}
			accept WashCompleteSignal
				then washing;

			state washing {
				do action tumble : TumbleAction {
					in duration = 1800.0;
					in speed = 50.0;
				}
			}
			accept WashCompleteSignal
				do action enablePump : EnablePumpAction { out isPumping = true; }
				then draining;

			state draining;
			accept DrumEmptySignal
				do action disablePump : DisablePumpAction { out isPumping = false; }
				then rinsing;

			state rinsing {
				do action openValveRinse : OpenValveAction { out isOpen = true; }
			}
			accept RinseCompleteSignal
				do action closeValveRinse : CloseValveAction { out isClosed = true; }
				then spinning;

			state spinning {
				do action spin : SpinAction {
					in speed = 1200.0;
					in duration = 600.0;
				}
			}
			accept SpinCompleteSignal
				do action stopMotor : DisablePumpAction { out isPumping = false; }
				then finished;

			state finished {
				do action unlockDoor : UnlockDoorAction { out isUnlocked = true; }
			}
			accept CycleCompleteSignal
				then idle;
		}

		requirement def CleanLaundryReq {
			subject washingMachine : WashingMachine;
			doc /* The washing machine shall clean laundry effectively using selectable wash programs including Cotton Heavy, Delicate, and Quick Wash. */
		}

		requirement def SafetyInterlockReq {
			subject doorLock : DoorLock;
			doc /* The door shall remain locked during operation whenever the drum contains water or is rotating above 10 RPM. */
		}

		requirement def ProgramExecutionReq {
			subject controlModule : ControlModule;
			doc /* The control module shall execute predefined wash programs as ordered sequences of fill, heat, wash, rinse, and spin actions. */
		}
	}

	package Usages {
		private import Definitions::*;

		requirement cleanLaundryReq : CleanLaundryReq;
		requirement safetyInterlockReq : SafetyInterlockReq;
		requirement programExecutionReq : ProgramExecutionReq;

		part context {
			part waterSupply : WaterSupply;
			part sewerDrain : SewerDrain;
			part electricalGrid : ElectricalGrid;

			part washingMachine : WashingMachine {
				satisfy cleanLaundryReq;
				satisfy safetyInterlockReq;
				satisfy programExecutionReq;

				bind waterIn = inletValve.waterIn;
				bind waterOut = drainPump.waterOut;
				bind powerIn = control.powerIn;
				bind programSelect = control.programSelect;

				flow of CleanWater from inletValve.waterOut.water to heater.waterIn.water;
				flow of CleanWater from heater.waterOut.water to drum.waterIn.water;
				flow of DirtyWater from drum.drainOut.dirtyWater to drainPump.waterIn.dirtyWater;

				flow of ElectricalPower from powerIn.power to heater.powerIn.power;

				flow of RPMValue from control.motorControl.speed to motor.controlIn.speed;
				flow of RPMValue from motor.shaftOut.speed to drum.motorIn.speed;

				flow of Boolean from control.valveControl.isOpen to inletValve.controlIn.isOpen;
				flow of Boolean from control.pumpControl.isPumping to drainPump.controlIn.isPumping;
				flow of TempValue from control.heaterControl.targetTemp to heater.controlIn.targetTemp;
				flow of Boolean from control.lockControl.isLocked to doorLock.controlIn.isLocked;
				flow of Boolean from control.detergentControl.isOpen to detergentDispenser.controlIn.isOpen;

				flow of VolumeValue from levelSensor.levelOut.level to control.levelFeedback.level;
				flow of TempValue from tempSensor.tempOut.temp to control.tempFeedback.temp;

				exhibit washCycleStates : WashCycleStates;
			}

			flow of CleanWater from waterSupply.waterOut.water to washingMachine.waterIn.water;
			flow of DirtyWater from washingMachine.waterOut.dirtyWater to sewerDrain.waterIn.dirtyWater;
			flow of ElectricalPower from electricalGrid.powerOut.power to washingMachine.powerIn.power;
		}
	}
}
