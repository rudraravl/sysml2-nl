package CBusBuildingAutomation {
	private import ScalarValues::*;

	package Definitions {
		attribute def Temperature :> Real;
		attribute def Voltage :> Real;
		attribute def BrightnessLevel :> Real;
		attribute def RampRate :> Real;
		attribute def FanSpeed :> Real;

		enum def PriorityLevel {
			routine;
			high;
			critical;
		}

		abstract item def BusMessage {
			attribute priority : PriorityLevel;
			attribute source : String;
			attribute destination : String;
		}

		item def OccupancyFrame :> BusMessage {
			attribute occupied : Boolean;
			attribute zoneId : String;
		}

		item def LightingCommandFrame :> BusMessage {
			attribute level : BrightnessLevel;
			attribute rampRate : RampRate;
		}

		item def ClimateCommandFrame :> BusMessage {
			attribute targetTemperature : Temperature;
			attribute fanSpeed : FanSpeed;
		}

		item def SecurityAlertFrame :> BusMessage {
			attribute zoneId : String;
			attribute alarmType : String;
		}

		item def StatusFrame :> BusMessage {
			attribute statusCode : Integer;
			attribute description : String;
		}

		item def MotionEvent {
			attribute detected : Boolean;
		}

		port def CBusPort {
			out tx : BusMessage;
			in rx : BusMessage;
		}

		port def PowerPort {
			out pwr : Voltage;
		}

		port def MotionSensorPort {
			out motion : MotionEvent;
		}

		abstract part def CBusDevice {
			attribute deviceId : String;
			port cbus : ~CBusPort;
			port pwrIn : ~PowerPort;
		}

		part def PowerSupplyUnit :> CBusDevice {
			attribute outputVoltage : Voltage = 36.0;
			port powerOut : PowerPort;

			state PSUState {
				entry send new StatusFrame(PriorityLevel::high, deviceId, "broadcast", 0, "PSU online") via cbus;
				then Powered;
				state Powered;
				accept req:StatusFrame via cbus
				do action {
					first start;
					then send new StatusFrame(PriorityLevel::routine, deviceId, req.source, 0, "PSU nominal") via cbus;
				}
				then Powered;
			}
		}

		part def LightingController :> CBusDevice {
			attribute zoneId : String = "zone_1";
			attribute currentLevel : BrightnessLevel = 0.0;
			attribute configuredRampRate : RampRate = 3.0;

			state LightingState {
				entry send new StatusFrame(PriorityLevel::routine, deviceId, "broadcast", 0, "Lighting online") via cbus;
				then Idle;
				state Idle;
				accept cmd:LightingCommandFrame via cbus
				do action {
					first start;
					then send new StatusFrame(PriorityLevel::routine, deviceId, cmd.source, 0, "Lighting level set") via cbus;
				}
				then Idle;
				accept occ:OccupancyFrame via cbus
				do action {
					first start;
					then send new LightingCommandFrame(PriorityLevel::high, deviceId, "lighting_zone_1", 80.0, configuredRampRate) via cbus;
				}
				then Idle;
			}
		}

		part def ClimateController :> CBusDevice {
			attribute zoneId : String = "zone_1";
			attribute currentTemperature : Temperature = 22.0;
			attribute targetTemperature : Temperature = 21.0;
			attribute fanSpeedValue : FanSpeed = 40.0;

			state ClimateState {
				entry send new StatusFrame(PriorityLevel::routine, deviceId, "broadcast", 0, "Climate online") via cbus;
				then Idle;
				state Idle;
				accept cmd:ClimateCommandFrame via cbus
				do action {
					first start;
					then send new StatusFrame(PriorityLevel::routine, deviceId, cmd.source, 0, "Climate setpoint updated") via cbus;
				}
				then Idle;
			}
		}

		part def SecurityController :> CBusDevice {
			attribute zoneId : String = "zone_1";
			attribute armed : Boolean = true;
			attribute alarmActive : Boolean = false;

			state SecurityState {
				entry send new SecurityAlertFrame(PriorityLevel::critical, deviceId, "broadcast", zoneId, "Security online") via cbus;
				then Monitoring;
				state Monitoring;
				accept alert:SecurityAlertFrame via cbus
				do action {
					first start;
					then send new SecurityAlertFrame(PriorityLevel::critical, deviceId, "broadcast", alert.zoneId, "Alarm activated") via cbus;
				}
				then Monitoring;
			}
		}

		part def OccupancySensor :> CBusDevice {
			attribute zoneId : String = "zone_1";
			attribute occupied : Boolean = false;
			port motionSensor : ~MotionSensorPort;

			state OccupancyState {
				entry send new StatusFrame(PriorityLevel::routine, deviceId, "broadcast", 0, "Occupancy sensor online") via cbus;
				then Idle;
				state Idle;
				accept m:MotionEvent via motionSensor
				do action {
					first start;
					then send new OccupancyFrame(PriorityLevel::high, deviceId, "lighting_zone_1", m.detected, zoneId) via cbus;
				}
				then Idle;
			}
		}

		part def CBus {
			attribute busVoltage : Voltage = 36.0;
			attribute dataRate : Integer = 9600;
			port powerInput : ~PowerPort;
			port psuIF : CBusPort;
			port lightingIF : CBusPort;
			port climateIF : CBusPort;
			port securityIF : CBusPort;
			port occupancyIF : CBusPort;
			port lightingPwr : PowerPort;
			port climatePwr : PowerPort;
			port securityPwr : PowerPort;
			port occupancyPwr : PowerPort;
		}
	}

	package Requirements {
		requirement def DistributedControl {
			doc /* The system shall operate as a peer-to-peer network with no central supervisory computer. */
		}

		requirement def TwoWirePowerAndData {
			doc /* The bus shall provide low-voltage power and data communication over a shared two-wire connection. */
		}

		requirement def PriorityMessaging {
			doc /* Critical security messages shall be transmitted with precedence over routine updates. */
		}

		requirement def AutonomousDeviceStates {
			doc /* Each device shall operate autonomously through initializing, idle, listening, processing, and transmitting states. */
		}
	}

	package SystemModel {
		private import Definitions::*;
		private import Requirements::*;

		part buildingAutomation {
			requirement distributedControl : DistributedControl;
			requirement twoWirePowerAndData : TwoWirePowerAndData;
			requirement priorityMessaging : PriorityMessaging;
			requirement autonomousDeviceStates : AutonomousDeviceStates;

			part psu : PowerSupplyUnit {
				:>> deviceId = "PSU-01";
			}
			part lightingController : LightingController {
				:>> deviceId = "LC-01";
			}
			part climateController : ClimateController {
				:>> deviceId = "CC-01";
			}
			part securityController : SecurityController {
				:>> deviceId = "SC-01";
			}
			part occupancySensor : OccupancySensor {
				:>> deviceId = "OS-01";
			}
			part bus : CBus;

			connect psu.powerOut to bus.powerInput;
			connect psu.cbus to bus.psuIF;
			connect lightingController.cbus to bus.lightingIF;
			connect lightingController.pwrIn to bus.lightingPwr;
			connect climateController.cbus to bus.climateIF;
			connect climateController.pwrIn to bus.climatePwr;
			connect securityController.cbus to bus.securityIF;
			connect securityController.pwrIn to bus.securityPwr;
			connect occupancySensor.cbus to bus.occupancyIF;
			connect occupancySensor.pwrIn to bus.occupancyPwr;
		}
	}
}
