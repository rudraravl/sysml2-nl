package 'Axial Flow Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		attribute def FlowRate :> ISQ::VolumeFlowRateValue;
		attribute def RotationalSpeed :> ISQ::AngularVelocityValue;
		attribute def PumpEfficiency :> Real;
		attribute def Head :> ISQ::LengthValue;
		attribute def NPSH :> ISQ::LengthValue;

		item def Fluid {
			attribute density : ISQ::MassDensityValue;
			attribute viscosity : ISQ::DynamicViscosityValue;
			attribute temperature : ISQ::TemperatureValue;
			attribute pressure : ISQ::PressureValue;
			attribute flowRate : FlowRate;
		}

		port def FluidInletPort {
			attribute inletPressure : ISQ::PressureValue;
			attribute inletTemperature : ISQ::TemperatureValue;
			in item fluidIn : Fluid;
		}

		port def FluidOutletPort {
			attribute outletPressure : ISQ::PressureValue;
			attribute outletTemperature : ISQ::TemperatureValue;
			out item fluidOut : Fluid;
		}

		port def PowerPort {
			attribute voltage : Real;
			attribute current : Real;
			attribute power : ISQ::PowerValue;
		}

		port def MechanicalPort {
			attribute torque : ISQ::TorqueValue;
			attribute speed : RotationalSpeed;
		}

		part def ImpellerBlade {
			attribute bladeAngle : Real;
			attribute chordLength : ISQ::LengthValue;
			attribute thickness : ISQ::LengthValue;
		}

		part def Impeller {
			attribute numberOfBlades : Integer;
			attribute outerDiameter : ISQ::LengthValue;
			attribute hubDiameter : ISQ::LengthValue;
			attribute bladeAngle : Real;
			part blades : ImpellerBlade[4..12];
		}

		part def Shaft {
			attribute diameter : ISQ::LengthValue;
			attribute length : ISQ::LengthValue;
			attribute material : String;
		}

		part def Bearing {
			attribute bearingType : String;
			attribute innerDiameter : ISQ::LengthValue;
			attribute outerDiameter : ISQ::LengthValue;
			attribute loadCapacity : ISQ::ForceValue;
		}

		part def MechanicalSeal {
			attribute sealType : String;
			attribute maxPressure : ISQ::PressureValue;
			attribute maxTemperature : ISQ::TemperatureValue;
		}

		part def Casing {
			attribute inletDiameter : ISQ::LengthValue;
			attribute outletDiameter : ISQ::LengthValue;
			attribute casingLength : ISQ::LengthValue;
			attribute wallThickness : ISQ::LengthValue;
			attribute material : String;
			port inlet : FluidInletPort;
			port outlet : FluidOutletPort;
		}

		part def Motor {
			attribute ratedPower : ISQ::PowerValue;
			attribute ratedVoltage : Real;
			attribute ratedCurrent : Real;
			attribute ratedSpeed : RotationalSpeed;
			attribute efficiency : Real;
			port powerInput : PowerPort;
			port shaftOutput : MechanicalPort;
		}

		calc def PumpHeadCalculation {
			in flowRate : FlowRate;
			in speed : RotationalSpeed;
			in impellerDiameter : ISQ::LengthValue;
			in efficiency : PumpEfficiency;
			return head : Head = (speed * impellerDiameter * 0.8 - flowRate * 0.05) * efficiency;
		}

		calc def PowerRequirement {
			in flowRate : FlowRate;
			in head : Head;
			in fluidDensity : ISQ::MassDensityValue;
			in efficiency : PumpEfficiency;
			return power : ISQ::PowerValue = (fluidDensity * 9.81 [m/s^2] * flowRate * head) / efficiency;
		}

		action def PumpingAction {
			in fluidInput : Fluid;
			in operatingSpeed : RotationalSpeed;
			out fluidOutput : Fluid;

			action accelerateFluid {
				doc /* Impeller accelerates fluid axially */
			}
			then action increaseFluidPressure {
				doc /* Convert velocity to pressure in diffuser */
			}
		}

		action def StartCommand;
		action def StopCommand;
		action def ResetCommand;

		state def PumpOperationalStates {
			entry; then off;

			state off {
				doc /* Pump is not operating */
			}

			accept StartCommand
			then state starting {
				doc /* Pump is accelerating to operating speed */
			}

			then state running {
				doc /* Pump is operating at steady state */
				entry; do action pumpingOp : PumpingAction;
			}

			accept StopCommand
			then state stopping {
				doc /* Pump is decelerating */
			}

			then off;

			state fault {
				doc /* Pump has encountered a fault */
			}

			accept ResetCommand
			then off;
		}

		part def AxialFlowPump {
			doc /*
				Axial-flow pump moves fluid parallel to the shaft axis.
				Fluid enters axially and exits axially with increased pressure.
			*/

			attribute designFlowRate : FlowRate;
			attribute designHead : Head;
			attribute operatingSpeed : RotationalSpeed;
			attribute hydraulicEfficiency : PumpEfficiency;
			attribute npshRequired : NPSH;

			port inlet : FluidInletPort;
			port outlet : FluidOutletPort;
			port driveConnection : ~MechanicalPort;

			part casing : Casing {
				bind inlet = AxialFlowPump::inlet;
				bind outlet = AxialFlowPump::outlet;
			}

			part impeller : Impeller;
			part shaft : Shaft;
			part frontBearing : Bearing;
			part rearBearing : Bearing;
			part seal : MechanicalSeal;

			state operatingStates : PumpOperationalStates;

			perform action pumpOperation : PumpingAction {
				in fluidInput = inlet.fluidIn;
				in operatingSpeed = driveConnection.speed;
				out fluidOutput = outlet.fluidOut;
			}

			calc headCalc : PumpHeadCalculation {
				in flowRate = inlet.fluidIn.flowRate;
				in speed = operatingSpeed;
				in impellerDiameter = impeller.outerDiameter;
				in efficiency = hydraulicEfficiency;
			}
		}

		part def SuctionPiping {
			attribute length : ISQ::LengthValue;
			attribute diameter : ISQ::LengthValue;
			attribute material : String;
			port inlet : FluidInletPort;
			port outlet : FluidOutletPort;
		}

		part def DischargePiping {
			attribute length : ISQ::LengthValue;
			attribute diameter : ISQ::LengthValue;
			attribute material : String;
			port inlet : FluidInletPort;
			port outlet : FluidOutletPort;
		}

		part def FlowMeter {
			attribute measuredFlowRate : FlowRate;
			attribute accuracy : Real;
			port measurementPoint : FluidInletPort;
		}

		part def PressureTransmitter {
			attribute measuredPressure : ISQ::PressureValue;
			attribute accuracy : Real;
			port sensingPort;
		}

		part def TemperatureTransmitter {
			attribute measuredTemperature : ISQ::TemperatureValue;
			attribute accuracy : Real;
			port sensingPort;
		}

		part def IsolationValve {
			attribute valvePosition : Real;
			attribute maxPressure : ISQ::PressureValue;
			port inlet : FluidInletPort;
			port outlet : FluidOutletPort;
		}

		part def CheckValve {
			attribute crackingPressure : ISQ::PressureValue;
			port inlet : FluidInletPort;
			port outlet : FluidOutletPort;
		}

		part def PumpingSubsystem {
			doc /*
				Complete axial-flow pumping subsystem including pump,
				motor, piping, instrumentation, and control components.
			*/

			attribute systemFlowRate : FlowRate;
			attribute systemHead : Head;
			attribute totalEfficiency : Real;

			port systemInlet : FluidInletPort;
			port systemOutlet : FluidOutletPort;
			port powerSupply : PowerPort;

			part suctionPipe : SuctionPiping {
				doc /* Piping from source to pump inlet */
			}

			part suctionValve : IsolationValve {
				doc /* Isolation valve on suction side */
			}

			part pump : AxialFlowPump {
				perform action operation : PumpingAction {
					in fluidInput = inlet.fluidIn;
					in operatingSpeed = driveConnection.speed;
					out fluidOutput = outlet.fluidOut;
				}
			}

			part driveMotor : Motor;

			part dischargeCheckValve : CheckValve {
				doc /* Prevents backflow when pump stops */
			}

			part dischargeValve : IsolationValve {
				doc /* Isolation valve on discharge side */
			}

			part dischargePipe : DischargePiping {
				doc /* Piping from pump outlet to destination */
			}

			part suctionFlowMeter : FlowMeter;
			part dischargePressureTransmitter : PressureTransmitter;
			part suctionPressureTransmitter : PressureTransmitter;
			part dischargeTemperatureTransmitter : TemperatureTransmitter;

			flow of Fluid from systemInlet.fluidIn to suctionPipe.inlet.fluidIn;
			flow of Fluid from suctionPipe.outlet.fluidOut to suctionValve.inlet.fluidIn;
			flow of Fluid from suctionValve.outlet.fluidOut to pump.inlet.fluidIn;
			flow of Fluid from pump.outlet.fluidOut to dischargeCheckValve.inlet.fluidIn;
			flow of Fluid from dischargeCheckValve.outlet.fluidOut to dischargeValve.inlet.fluidIn;
			flow of Fluid from dischargeValve.outlet.fluidOut to dischargePipe.inlet.fluidIn;
			flow of Fluid from dischargePipe.outlet.fluidOut to systemOutlet.fluidOut;

			bind driveMotor.shaftOutput = pump.driveConnection;
			bind driveMotor.powerInput = powerSupply;
			bind suctionFlowMeter.measurementPoint = suctionPipe.outlet;
		}
	}

	package Requirements {
		requirement def HydraulicPerformanceRequirement {
			doc /* Requirements for pump hydraulic performance */

			subject pump : Definitions::AxialFlowPump;

			require minimumFlowRate {
				doc /* Pump shall deliver minimum flow rate at design head */
				pump.designFlowRate >= 200.0 [m^3/h]
			}

			require minimumHead {
				doc /* Pump shall develop minimum head at design flow */
				pump.designHead >= 15.0 [m]
			}

			require minimumEfficiency {
				doc /* Pump shall achieve minimum efficiency at best efficiency point */
				pump.hydraulicEfficiency >= 0.80
			}

			require npshMargin {
				doc /* Available NPSH shall exceed required NPSH by safety margin */
				pump.npshRequired <= 4.0 [m]
			}
		}

		requirement def MechanicalReliabilityRequirement {
			doc /* Requirements for mechanical reliability */

			require bearingLife {
				doc /* Bearing L10 life shall exceed 50000 hours */
			}

			require sealLife {
				doc /* Mechanical seal life shall exceed 10000 hours */
			}

			require vibrationLimit {
				doc /* Vibration levels shall not exceed ISO 10816 limits */
			}
		}

		requirement def OperationalRequirement {
			doc /* Requirements for operational capability */

			require startupTime {
				doc /* Pump shall reach operating speed within 30 seconds */
			}

			require continuousOperation {
				doc /* Pump shall operate continuously for 8760 hours per year */
			}

			require temperatureRange {
				doc /* Pump shall operate with fluid temperature from 5 to 80 degC */
			}
		}

		requirement def SafetyRequirement {
			doc /* Safety requirements for pumping subsystem */

			require overpressureProtection {
				doc /* System shall include overpressure protection devices */
			}

			require emergencyStop {
				doc /* System shall provide emergency stop capability */
			}

			require leakDetection {
				doc /* System shall detect and alarm on seal leakage */
			}
		}
	}

	package Usages {
		part waterPumpingSystem : Definitions::PumpingSubsystem {
			doc /* Water pumping system for industrial application */

			attribute redefines systemFlowRate = 250.0 [m^3/h];
			attribute redefines systemHead = 18.0 [m];
			attribute redefines totalEfficiency = 0.75;

			part redefines pump : Definitions::AxialFlowPump {
				attribute redefines designFlowRate = 250.0 [m^3/h];
				attribute redefines designHead = 18.0 [m];
				attribute redefines operatingSpeed = 1450.0 [1/min];
				attribute redefines hydraulicEfficiency = 0.83;
				attribute redefines npshRequired = 3.5 [m];

				part redefines impeller : Definitions::Impeller {
					attribute redefines numberOfBlades = 6;
					attribute redefines outerDiameter = 300.0 [mm];
					attribute redefines hubDiameter = 120.0 [mm];
					attribute redefines bladeAngle = 25.0;
				}

				part redefines shaft : Definitions::Shaft {
					attribute redefines diameter = 60.0 [mm];
					attribute redefines length = 900.0 [mm];
					attribute redefines material = "Stainless Steel 316";
				}

				part redefines casing : Definitions::Casing {
					attribute redefines inletDiameter = 200.0 [mm];
					attribute redefines outletDiameter = 200.0 [mm];
					attribute redefines casingLength = 700.0 [mm];
					attribute redefines wallThickness = 10.0 [mm];
					attribute redefines material = "Cast Iron";
				}
			}

			part redefines driveMotor : Definitions::Motor {
				attribute redefines ratedPower = 15.0 [kW];
				attribute redefines ratedVoltage = 400.0;
				attribute redefines ratedCurrent = 30.0;
				attribute redefines ratedSpeed = 1450.0 [1/min];
				attribute redefines efficiency = 0.92;
			}

			part redefines suctionPipe : Definitions::SuctionPiping {
				attribute redefines length = 8.0 [m];
				attribute redefines diameter = 200.0 [mm];
				attribute redefines material = "Carbon Steel";
			}

			part redefines dischargePipe : Definitions::DischargePiping {
				attribute redefines length = 25.0 [m];
				attribute redefines diameter = 150.0 [mm];
				attribute redefines material = "Carbon Steel";
			}

			satisfy Requirements::HydraulicPerformanceRequirement by pump;
			satisfy Requirements::MechanicalReliabilityRequirement by pump;
			satisfy Requirements::OperationalRequirement by waterPumpingSystem;
			satisfy Requirements::SafetyRequirement by waterPumpingSystem;
		}
	}
}
