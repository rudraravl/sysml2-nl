package 'Automated Lighting Control System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	value def Illuminance :> ISQ::illuminance;
	value def Brightness :> ScalarValues::Real;
	value def Power :> ISQ::power;
	value def Voltage :> ISQ::voltage;
	value def Duration :> ISQ::time;

	item def OccupancyStatus {
		attribute isPresent : Boolean;
	}

	item def IlluminanceReading {
		attribute level : Illuminance;
	}

	item def BrightnessCommand {
		attribute level : Brightness;
		attribute powerOn : Boolean;
	}

	item def UserCommand {
		attribute turnOn : Boolean;
		attribute turnOff : Boolean;
		attribute setBrightness : Boolean;
		attribute brightnessLevel : Brightness;
		attribute setAuto : Boolean;
	}

	item def PowerSignal {
		attribute voltage : Voltage;
	}

	port def OccupancyOutPort {
		out occupancy : OccupancyStatus;
	}

	port def OccupancyInPort {
		in occupancy : OccupancyStatus;
	}

	port def LightOutPort {
		out illuminance : IlluminanceReading;
	}

	port def LightInPort {
		in illuminance : IlluminanceReading;
	}

	port def UserOutPort {
		out command : UserCommand;
	}

	port def UserInPort {
		in command : UserCommand;
	}

	port def FixtureControlOutPort {
		out brightnessCmd : BrightnessCommand;
	}

	port def FixtureControlInPort {
		in brightnessCmd : BrightnessCommand;
	}

	port def PowerOutPort {
		out power : PowerSignal;
	}

	port def PowerInPort {
		in power : PowerSignal;
	}

	part def OccupancySensor {
		port occupancyOut : OccupancyOutPort;
		perform action senseOccupancy;
	}

	part def LightSensor {
		port lightOut : LightOutPort;
		perform action senseLight;
	}

	part def UserPanel {
		port commandOut : UserOutPort;
		perform action receiveUserInput;
	}

	part def LightingFixture {
		port controlIn : FixtureControlInPort;
		port powerIn : PowerInPort;
		attribute currentBrightness : Brightness;
		perform action emitLight;
	}

	part def PowerSupply {
		attribute inputVoltage : Voltage = 120 [SI::V];
		attribute outputVoltage : Voltage = 24 [SI::V];
		port powerOut1 : PowerOutPort;
		port powerOut2 : PowerOutPort;
		perform action convertPower;
	}

	part def LightingController {
		port occupancyIn : OccupancyInPort;
		port lightIn : LightInPort;
		port userIn : UserInPort;
		port fixture1Out : FixtureControlOutPort;
		port fixture2Out : FixtureControlOutPort;

		attribute vacancyTimeout : Duration = 5 [SI::min];
		attribute daylightThreshold : Illuminance = 300 [SI::lx];
		attribute lowLightBrightness : Brightness = 0.2;
		attribute fullBrightness : Brightness = 0.8;

		exhibit state controllerStates {
			entry; then AutoMode;

			state AutoMode {
				entry; then LightsOff;

				state LightsOff;
				accept occ : OccupancyStatus via occupancyIn
					if occ.isPresent
					then CheckDaylight;

				state CheckDaylight;
				accept light : IlluminanceReading via lightIn
					if light.level >= daylightThreshold
					then LightsDim;
				accept light : IlluminanceReading via lightIn
					if light.level < daylightThreshold
					then LightsOn;

				state LightsOn;
				accept occ : OccupancyStatus via occupancyIn
					if not occ.isPresent
					then WaitingTimeout;

				state LightsDim;
				accept occ : OccupancyStatus via occupancyIn
					if not occ.isPresent
					then WaitingTimeout;

				state WaitingTimeout;
				accept after vacancyTimeout
					then LightsOff;
				accept occ : OccupancyStatus via occupancyIn
					if occ.isPresent
					then CheckDaylight;
			}

			accept cmd : UserCommand via userIn
				if cmd.turnOn or cmd.turnOff or cmd.setBrightness
				then ManualMode;

			state ManualMode;
			accept cmd : UserCommand via userIn
				if cmd.setAuto
				then AutoMode;
		}
	}

	requirement def EnergyEfficiency {
		doc /* The system shall minimize energy consumption by turning off lights when unoccupied and dimming when sufficient daylight is available. */
		attribute maxPowerConsumption : Power = 150 [SI::W];
	}

	requirement def UserComfort {
		doc /* The system shall maintain adequate illumination levels for occupant comfort when the room is occupied. */
		attribute minIlluminance : Illuminance = 300 [SI::lx];
	}

	requirement def Responsiveness {
		doc /* The system shall respond to occupancy changes and user inputs within 2 seconds. */
		attribute maxResponseTime : Duration = 2 [SI::s];
	}

	part lightingSystem {
		part controller : LightingController;
		part occupancySensor : OccupancySensor;
		part lightSensor : LightSensor;
		part userPanel : UserPanel;
		part fixture1 : LightingFixture;
		part fixture2 : LightingFixture;
		part powerSupply : PowerSupply;

		flow occupancyFlow of OccupancyStatus
			from occupancySensor.occupancyOut.occupancy to controller.occupancyIn.occupancy;
		flow lightFlow of IlluminanceReading
			from lightSensor.lightOut.illuminance to controller.lightIn.illuminance;
		flow userCmdFlow of UserCommand
			from userPanel.commandOut.command to controller.userIn.command;
		flow fixture1CmdFlow of BrightnessCommand
			from controller.fixture1Out.brightnessCmd to fixture1.controlIn.brightnessCmd;
		flow fixture2CmdFlow of BrightnessCommand
			from controller.fixture2Out.brightnessCmd to fixture2.controlIn.brightnessCmd;
		flow powerFlow1 of PowerSignal
			from powerSupply.powerOut1.power to fixture1.powerIn.power;
		flow powerFlow2 of PowerSignal
			from powerSupply.powerOut2.power to fixture2.powerIn.power;

		satisfy EnergyEfficiency;
		satisfy UserComfort;
		satisfy Responsiveness;
	}
}
