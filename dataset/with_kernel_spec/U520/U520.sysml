package 'Hydristor Hydraulic Drive System' {
	private import ISQ::*;
	private import ScalarValues::*;
	
	alias Torque for ISQ::TorqueValue;
	alias RotationalSpeed for ISQ::AngularVelocityValue;
	alias Pressure for ISQ::PressureValue;
	alias VolumeFlowRate for ISQ::VolumeFlowRateValue;
	alias Volume for ISQ::VolumeValue;
	
	item def HydraulicFluid;
	item def ControlSignal;
	
	port def MechanicalPort {
		inout torque : Torque;
		inout speed : RotationalSpeed;
	}
	port def HydraulicPort {
		inout fluid : HydraulicFluid;
		inout pressure : Pressure;
		inout flowRate : VolumeFlowRate;
	}
	port def ControlPort {
		in signal : ControlSignal;
	}
	port def PressureSensorPort {
		out pressureReading : Pressure;
	}
	port def SpeedSensorPort {
		out speedReading : RotationalSpeed;
	}
	
	part def PrimeDriver {
		port mechanicalOut : MechanicalPort;
		attribute nominalSpeed : RotationalSpeed;
		
		action driveBehavior {
			out torque : Torque = mechanicalOut.torque;
			out speed : RotationalSpeed = mechanicalOut.speed;
		}
	}
	
	part def HydraulicPump {
		port mechanicalIn : MechanicalPort;
		port hydraulicOut : HydraulicPort;
		port fluidIn : HydraulicPort;
		
		action pumpBehavior {
			in returnFluid : HydraulicFluid = fluidIn.fluid;
			in mechanicalTorque : Torque = mechanicalIn.torque;
			in mechanicalSpeed : RotationalSpeed = mechanicalIn.speed;
			out highPressureFluid : HydraulicFluid = hydraulicOut.fluid;
			out pressure : Pressure = hydraulicOut.pressure;
			out flowRate : VolumeFlowRate = hydraulicOut.flowRate;
		}
	}
	
	part def Reservoir {
		port fluidOut : HydraulicPort;
		port fluidIn : HydraulicPort;
	}
	
	part def Hydristor {
		port hydraulicIn : HydraulicPort;
		port hydraulicOut : HydraulicPort;
		port mechanicalOut : MechanicalPort;
		port controlIn : ControlPort;
		attribute displacement : Volume;
		
		action hydristorBehavior {
			loop {
				accept signal : ControlSignal via controlIn;
				action convert {
					in highPressureFluid : HydraulicFluid = hydraulicIn.fluid;
					in pressure : Pressure = hydraulicIn.pressure;
					in displacement : Volume = Hydristor::displacement;
					out torque : Torque = mechanicalOut.torque;
					out speed : RotationalSpeed = mechanicalOut.speed;
					out lowPressureFluid : HydraulicFluid = hydraulicOut.fluid;
				}
			}
		}
	}
	
	part def MechanicalLoad {
		port mechanicalIn : MechanicalPort;
	}
	
	part def PressureSensor {
		port hydraulicIn : HydraulicPort;
		port dataOut : PressureSensorPort;
		
		action sensePressure {
			in pressure : Pressure = hydraulicIn.pressure;
			out pressureReading : Pressure = dataOut.pressureReading;
		}
	}
	
	part def SpeedSensor {
		port mechanicalIn : MechanicalPort;
		port dataOut : SpeedSensorPort;
		
		action senseSpeed {
			in speed : RotationalSpeed = mechanicalIn.speed;
			out speedReading : RotationalSpeed = dataOut.speedReading;
		}
	}
	
	part def DisplacementController {
		port pressureDataIn : ~PressureSensorPort;
		port speedDataIn : ~SpeedSensorPort;
		port controlOut : ~ControlPort;
		attribute targetSpeed : RotationalSpeed;
		
		action controlBehavior {
			loop {
				accept sensedPressure : Pressure via pressureDataIn;
				accept sensedSpeed : RotationalSpeed via speedDataIn;
				action computeError {
					in actualSpeed : RotationalSpeed = sensedSpeed;
					in targetSpeed : RotationalSpeed = DisplacementController::targetSpeed;
					out error : Real;
				}
				action adjustDisplacement {
					in error : Real = computeError.error;
					in pressure : Pressure = sensedPressure;
					out signal : ControlSignal;
				}
				send adjustDisplacement.signal via controlOut;
			}
		}
	}
	
	part def HydraulicDriveSystem {
		part primeDriver : PrimeDriver;
		part pump : HydraulicPump;
		part reservoir : Reservoir;
		part hydristor : Hydristor;
		part load : MechanicalLoad;
		part pressureSensor : PressureSensor;
		part speedSensor : SpeedSensor;
		part controller : DisplacementController;
		
		flow mechanicalFlow1 of Torque from primeDriver.mechanicalOut.torque to pump.mechanicalIn.torque;
		flow mechanicalFlow2 of RotationalSpeed from primeDriver.mechanicalOut.speed to pump.mechanicalIn.speed;
		
		flow fluidFlow1 of HydraulicFluid from reservoir.fluidOut.fluid to pump.fluidIn.fluid;
		
		flow fluidFlow2 of HydraulicFluid from pump.hydraulicOut.fluid to hydristor.hydraulicIn.fluid;
		flow pressureFlow1 of Pressure from pump.hydraulicOut.pressure to hydristor.hydraulicIn.pressure;
		
		flow fluidFlow3 of HydraulicFluid from hydristor.hydraulicOut.fluid to reservoir.fluidIn.fluid;
		
		flow mechanicalFlow3 of Torque from hydristor.mechanicalOut.torque to load.mechanicalIn.torque;
		flow mechanicalFlow4 of RotationalSpeed from hydristor.mechanicalOut.speed to load.mechanicalIn.speed;
		
		flow pressureFlow2 of Pressure from pump.hydraulicOut.pressure to pressureSensor.hydraulicIn.pressure;
		flow pressureData of Pressure from pressureSensor.dataOut.pressureReading to controller.pressureDataIn.pressureReading;
		
		flow speedFlow1 of RotationalSpeed from hydristor.mechanicalOut.speed to speedSensor.mechanicalIn.speed;
		flow speedData of RotationalSpeed from speedSensor.dataOut.speedReading to controller.speedDataIn.speedReading;
		
		flow controlFlow of ControlSignal from controller.controlOut.signal to hydristor.controlIn.signal;
	}
	
	requirement def 'Maintain Target Speed Requirement' {
		subject driveSystem : HydraulicDriveSystem;
		attribute targetSpeed : RotationalSpeed;
		attribute tolerance : RotationalSpeed;
		doc /* The system shall maintain the output speed within tolerance of the target speed. */
	}
}
