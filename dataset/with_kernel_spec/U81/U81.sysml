package LUCAS {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		attribute def PowerOn;
		attribute def StartCPR;
		attribute def PauseCPR;
		attribute def ResumeCPR;
		attribute def EmergencyStop;

		item def LowBatteryAlert;

		attribute def Depth :> ISQ::LengthValue;
		attribute def Force :> ISQ::ForceValue;
		attribute def CompressionRate :> Real;

		part def BatteryPack {
			attribute capacity : Real = 45 [min];
			attribute chargeLevel : Real;
			port powerOut;
		}

		part def ElectricMotor {
			port powerIn;
			port controlIn;
			port mechanicalOut;
		}

		part def ControlProcessor {
			attribute targetDepth : Depth = 52.5 [mm];
			attribute targetRate : CompressionRate = 102;
			port powerIn;
			port sensorIn;
			port motorControlOut;
			port uiIn;
		}

		part def CompressionPiston {
			port mechanicalIn;
			port pistonOut;
		}

		part def SuctionCupAssembly {
			port pistonIn;
		}

		part def DepthSensor {
			port depthOut;
		}

		part def ForceSensor {
			port forceOut;
		}

		part def UserInterface {
			port uiIn;
			port uiOut;
		}

		action def Compress {
			in targetDepth : Depth;
			out actualDepth : Depth;
			out appliedForce : Force;
		}

		action def Decompress;

		action def PerformCPR {
			in targetDepth : Depth = 52.5 [mm];
			in targetRate : CompressionRate = 102;
			first start;
			then loop action compressionCycle {
				action compress : Compress {
					in targetDepth = targetDepth;
				}
				then action decompress : Decompress;
			} until false;
			then done;
		}

		state def LUCASStates;
	}

	package Usages {
		private import Definitions::*;

		part def LUCASDevice {
			part battery : BatteryPack;
			part motor : ElectricMotor;
			part processor : ControlProcessor;
			part piston : CompressionPiston;
			part suctionCup : SuctionCupAssembly;
			part depthSensor : DepthSensor;
			part forceSensor : ForceSensor;
			part ui : UserInterface;

			connect battery.powerOut to motor.powerIn;
			connect battery.powerOut to processor.powerIn;
			connect processor.motorControlOut to motor.controlIn;
			connect motor.mechanicalOut to piston.mechanicalIn;
			connect piston.pistonOut to suctionCup.pistonIn;
			connect depthSensor.depthOut to processor.sensorIn;
			connect forceSensor.forceOut to processor.sensorIn;
			connect ui.uiOut to processor.uiIn;

			exhibit state lucasStates : LUCASStates parallel {
				state operationalStates {
					entry; then off;
					state off;
					accept PowerOn then standby;
					state standby;
					accept StartCPR then active;
					state active {
						do action performCPR : PerformCPR {
							in targetDepth = processor.targetDepth;
							in targetRate = processor.targetRate;
						}
					}
					accept PauseCPR then paused;
					accept EmergencyStop then emergencyStop;
					state paused;
					accept ResumeCPR then active;
					accept EmergencyStop then emergencyStop;
					state emergencyStop;
					accept PowerOn then off;
				}
				state healthStates {
					entry; then normal;
					state normal;
					accept when battery.chargeLevel < 20
						do send new LowBatteryAlert() to ui
						then lowBattery;
					state lowBattery;
					accept when battery.chargeLevel >= 20 then normal;
				}
			}
		}

		requirement def LUCASRequirements {
			subject device : LUCASDevice;
			requirement batteryLife {
				subject battery : BatteryPack;
				doc /* Battery shall provide power for at least 45 minutes of continuous operation. */
				constraint { battery.capacity >= 45 [min]; }
			}
			requirement compressionDepth {
				subject device : LUCASDevice;
				doc /* Compression depth shall be 50-55 mm. */
				constraint { device.processor.targetDepth >= 50 [mm] and device.processor.targetDepth <= 55 [mm]; }
			}
			requirement compressionRate {
				subject device : LUCASDevice;
				doc /* Compression rate shall be around 102 per minute. */
				constraint { device.processor.targetRate == 102; }
			}
		}
	}
}
