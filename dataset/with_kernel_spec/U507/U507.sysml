package 'Hydraulic Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		attribute def VoltageValue :> ScalarValues::Real;
		attribute def CurrentValue :> ScalarValues::Real;
		attribute def AngularVelocityValue :> ScalarValues::Real;
		attribute def VolumetricFlowRateValue :> ScalarValues::Real;

		item def HydraulicFluid;
		item def Contaminant;
		item def ElectricalPower;
		item def RotationalPower {
			attribute torque : TorqueValue;
			attribute speed : AngularVelocityValue;
		}
		item def SensorData {
			attribute pressure : PressureValue;
			attribute flowRate : VolumetricFlowRateValue;
			attribute temperature : TemperatureValue;
		}
		item def MotorCommand {
			attribute targetSpeed : AngularVelocityValue;
			attribute targetVoltage : VoltageValue;
		}

		attribute def StartCommand;
		attribute def StopCommand;
		attribute def ResetCommand;
		attribute def OverTempAlert;
		attribute def OverPressureAlert;

		port def FluidInPort {
			in item fluid : HydraulicFluid;
		}
		port def FluidOutPort {
			out item fluid : HydraulicFluid;
		}
		port def PowerInPort {
			in item power : ElectricalPower;
		}
		port def ShaftInPort {
			in item shaft : RotationalPower;
		}
		port def ShaftOutPort {
			out item shaft : RotationalPower;
		}
		port def ControlInPort {
			in item command : MotorCommand;
		}
		port def ControlOutPort {
			out item command : MotorCommand;
		}
		port def SensorInPort {
			in item data : SensorData;
		}
		port def SensorOutPort {
			out item data : SensorData;
		}

		action def SensePressure {
			out pressure : PressureValue;
		}
		action def SenseFlow {
			out flowRate : VolumetricFlowRateValue;
		}
		action def SenseTemperature {
			out temp : TemperatureValue;
		}
		action def ComputeMotorCommand {
			in pressure : PressureValue;
			in flowRate : VolumetricFlowRateValue;
			in temp : TemperatureValue;
			out command : MotorCommand;
		}
		action def DrivePump {
			in command : MotorCommand;
		}
		action def EmergencyShutdown;

		state def 'Control States';

		part def Gear {
			attribute teethCount : Integer;
			attribute pitchDiameter : LengthValue;
		}

		part def FluidReservoir {
			attribute capacity : VolumeValue;
			port fluidOutlet : FluidOutPort;
			port returnInlet : FluidInPort;
			port reliefReturn : FluidInPort;
		}

		part def SuctionFilter {
			attribute filterEfficiency : ScalarValues::Real;
			port fluidIn : FluidInPort;
			port fluidOut : FluidOutPort;
		}

		part def GearPump {
			attribute maxDischargePressure : PressureValue;
			attribute displacement : VolumeValue;
			part driveGear : Gear;
			part drivenGear : Gear;
			port fluidIn : FluidInPort;
			port fluidOut : FluidOutPort;
			port shaftDrive : ShaftInPort;
		}

		part def ElectricMotor {
			attribute ratedVoltage : VoltageValue;
			attribute ratedCurrent : CurrentValue;
			attribute maxSpeed : AngularVelocityValue;
			port powerIn : PowerInPort;
			port controlIn : ControlInPort;
			port shaftOut : ShaftOutPort;
		}

		part def CheckValve {
			attribute crackingPressure : PressureValue;
			port fluidIn : FluidInPort;
			port fluidOut : FluidOutPort;
		}

		part def PressureReliefValve {
			attribute setPressure : PressureValue;
			port fluidIn : FluidInPort;
			port returnOut : FluidOutPort;
		}

		part def PressureSensor {
			attribute measurementRange : PressureValue;
			port fluidTap : FluidInPort;
			port dataOut : SensorOutPort;
		}

		part def FlowMeter {
			attribute measurementRange : VolumetricFlowRateValue;
			port fluidTap : FluidInPort;
			port dataOut : SensorOutPort;
		}

		part def TemperatureSensor {
			attribute measurementRange : TemperatureValue;
			port fluidTap : FluidInPort;
			port dataOut : SensorOutPort;
		}

		part def ControlUnit {
			attribute maxSafeTemp : TemperatureValue;
			attribute maxSafePressure : PressureValue;
			attribute targetFlowRate : VolumetricFlowRateValue;
			port pressureDataIn : SensorInPort;
			port flowDataIn : SensorInPort;
			port tempDataIn : SensorInPort;
			port motorControlOut : ControlOutPort;
		}

		part def HydraulicPumpingSubsystem {
			part reservoir : FluidReservoir;
			part suctionFilter : SuctionFilter;
			part gearPump : GearPump;
			part electricMotor : ElectricMotor;
			part checkValve : CheckValve;
			part pressureReliefValve : PressureReliefValve;
			part pressureSensor : PressureSensor;
			part flowMeter : FlowMeter;
			part temperatureSensor : TemperatureSensor;
			part controlUnit : ControlUnit;
			port systemSupply : FluidOutPort;
			port systemReturn : FluidInPort;
			port externalPower : PowerInPort;
		}
	}

	package Usages {
		private import Definitions::*;

		action 'sense pressure' : 'SensePressure';
		action 'sense flow' : 'SenseFlow';
		action 'sense temperature' : 'SenseTemperature';
		action 'compute motor command' : 'ComputeMotorCommand';
		action 'drive pump' : 'DrivePump';
		action 'emergency shutdown' : 'EmergencyShutdown';

		part 'hydraulic pumping subsystem' : HydraulicPumpingSubsystem {
			connect externalPower to electricMotor.powerIn;
			connect reservoir.fluidOutlet to suctionFilter.fluidIn;
			connect suctionFilter.fluidOut to gearPump.fluidIn;
			connect gearPump.fluidOut to checkValve.fluidIn;
			connect checkValve.fluidOut to systemSupply;
			connect gearPump.fluidOut to pressureReliefValve.fluidIn;
			connect pressureReliefValve.returnOut to reservoir.reliefReturn;
			connect systemReturn to reservoir.returnInlet;
			connect electricMotor.shaftOut to gearPump.shaftDrive;
			connect controlUnit.motorControlOut to electricMotor.controlIn;
			connect checkValve.fluidOut to pressureSensor.fluidTap;
			connect checkValve.fluidOut to flowMeter.fluidTap;
			connect checkValve.fluidOut to temperatureSensor.fluidTap;
			connect pressureSensor.dataOut to controlUnit.pressureDataIn;
			connect flowMeter.dataOut to controlUnit.flowDataIn;
			connect temperatureSensor.dataOut to controlUnit.tempDataIn;

			state 'control states' : 'Control States' {
				entry; then idle;

				state idle;
				accept 'StartCommand'
					then monitoring;

				state monitoring {
					do 'sense pressure' { out pressure; }
					do 'sense flow' { out flowRate; }
					do 'sense temperature' { out temp; }
					do 'compute motor command' {
						in pressure = 'sense pressure'.pressure;
						in flowRate = 'sense flow'.flowRate;
						in temp = 'sense temperature'.temp;
						out command;
					}
					do 'drive pump' {
						in command = 'compute motor command'.command;
					}
				}

				accept when 'sense temperature'.temp > controlUnit.maxSafeTemp
					then shutdown;

				accept when 'sense pressure'.pressure > controlUnit.maxSafePressure
					then shutdown;

				accept 'StopCommand'
					then shutdown;

				state shutdown {
					entry 'emergency shutdown';
				}

				accept 'ResetCommand'
					then idle;
			}
		}
	}

	package Requirements {
		private import Definitions::*;

		requirement def 'Pressurization Requirement' {
			doc /* The gear pump shall pressurize hydraulic fluid to at least the required operating pressure. */
			attribute requiredPressure : PressureValue = 20.0e6;
			subject pump : GearPump;
			assert { pump.maxDischargePressure >= requiredPressure }
		}

		requirement def 'Filtration Requirement' {
			doc /* The suction filter shall remove contaminants before fluid enters the pump. */
			attribute minEfficiency : ScalarValues::Real = 0.99;
			subject filter : SuctionFilter;
			assert { filter.filterEfficiency >= minEfficiency }
		}

		requirement def 'Overpressure Protection Requirement' {
			doc /* The pressure relief valve shall open when pressure exceeds the safe limit. */
			subject valve : PressureReliefValve;
			subject pump : GearPump;
			assert { valve.setPressure <= pump.maxDischargePressure }
		}

		requirement def 'Backflow Prevention Requirement' {
			doc /* The check valve shall prevent reverse flow when the system is shut down. */
			subject valve : CheckValve;
			assert { valve.crackingPressure > 0 }
		}

		requirement def 'Thermal Safety Requirement' {
			doc /* The control unit shall shut down the motor if fluid temperature exceeds the safe limit. */
			subject cu : ControlUnit;
			attribute maxTemp : TemperatureValue = 350.0;
			assert { cu.maxSafeTemp <= maxTemp }
		}

		requirement def 'Flow Control Requirement' {
			doc /* The control unit shall adjust motor speed to maintain the target flow rate. */
			subject cu : ControlUnit;
			attribute requiredFlow : VolumetricFlowRateValue = 1.0e-3;
			assert { cu.targetFlowRate == requiredFlow }
		}
	}
}
