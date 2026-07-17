package 'Nutating Disc Engine System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import NumericalFunctions::*;
	
	attribute def PressureValue :> ISQ::PressureValue;
	attribute def VolumeValue :> ISQ::VolumeValue;
	attribute def AngularVelocityValue :> ISQ::AngularVelocityValue;
	attribute def TorqueValue :> ISQ::TorqueValue;
	attribute def FlowRateValue :> ISQ::VolumeFlowRateValue;
	attribute def NutationAngleValue :> ISQ::PlaneAngleValue;
	attribute def EfficiencyValue :> ScalarValues::Real;
	
	item def FluidInput {
		attribute pressure : PressureValue;
		attribute flowRate : FlowRateValue;
		attribute temperature : ThermodynamicTemperatureValue;
	}
	
	item def FluidOutput {
		attribute pressure : PressureValue;
		attribute flowRate : FlowRateValue;
		attribute temperature : ThermodynamicTemperatureValue;
	}
	
	item def MechanicalPower {
		attribute torque : TorqueValue;
		attribute angularVelocity : AngularVelocityValue;
		attribute power : PowerValue;
	}
	
	port def FluidInletPort {
		in item fluidIn : FluidInput;
	}
	
	port def FluidOutletPort {
		out item fluidOut : FluidOutput;
	}
	
	port def PowerOutputPort {
		out item mechanicalPower : MechanicalPower;
	}
	
	part def NutatingDisc {
		attribute nutationAngle : NutationAngleValue;
		attribute discDiameter : LengthValue;
		attribute discThickness : LengthValue;
		attribute mass : MassValue;
		attribute wobbleRate : AngularVelocityValue;
	}
	
	part def HousingChamber {
		attribute chamberVolume : VolumeValue;
		attribute inletArea : AreaValue;
		attribute outletArea : AreaValue;
		attribute wallThickness : LengthValue;
	}
	
	part def OutputShaft {
		attribute shaftDiameter : LengthValue;
		attribute shaftLength : LengthValue;
		attribute outputTorque : TorqueValue;
		attribute rotationalSpeed : AngularVelocityValue;
		attribute inertia : MomentOfInertiaValue;
	}
	
	part def SphereSupport {
		attribute sphereDiameter : LengthValue;
		attribute contactAngle : NutationAngleValue;
		attribute bearingLoad : ForceValue;
	}
	
	part def IntakeValve {
		attribute valveArea : AreaValue;
		attribute openingPressure : PressureValue;
	}
	
	part def ExhaustValve {
		attribute valveArea : AreaValue;
		attribute closingPressure : PressureValue;
	}
	
	action def AdmitFluid {
		in fluidInput : FluidInput;
		out chamberPressure : PressureValue;
		out chamberVolume : VolumeValue;
	}
	
	action def NutateDisc {
		in chamberPressure : PressureValue;
		in chamberVolume : VolumeValue;
		out nutationMotion : NutationAngleValue;
		out discForce : ForceValue;
	}
	
	action def ConvertToRotation {
		in nutationMotion : NutationAngleValue;
		in discForce : ForceValue;
		out shaftTorque : TorqueValue;
		out shaftSpeed : AngularVelocityValue;
	}
	
	action def TransmitPower {
		in shaftTorque : TorqueValue;
		in shaftSpeed : AngularVelocityValue;
		out mechanicalPower : MechanicalPower;
	}
	
	action def ExpelFluid {
		in chamberVolume : VolumeValue;
		in chamberPressure : PressureValue;
		out exhaustFlow : FluidOutput;
	}
	
	action def OperateNutatingDiscEngine {
		in fluidInput : FluidInput;
		out mechanicalPower : MechanicalPower;
		out exhaustFlow : FluidOutput;
		
		first start;
		then merge continuousOperation;
		
		then action admitFluid : AdmitFluid {
			in fluidInput = OperateNutatingDiscEngine::fluidInput;
			out chamberPressure : PressureValue;
			out chamberVolume : VolumeValue;
		}
		
		flow admitFluid.chamberPressure to nutateDisc.chamberPressure;
		flow admitFluid.chamberVolume to nutateDisc.chamberVolume;
		
		then action nutateDisc : NutateDisc {
			in chamberPressure : PressureValue;
			in chamberVolume : VolumeValue;
			out nutationMotion : NutationAngleValue;
			out discForce : ForceValue;
		}
		
		flow nutateDisc.nutationMotion to convertToRotation.nutationMotion;
		flow nutateDisc.discForce to convertToRotation.discForce;
		
		then action convertToRotation : ConvertToRotation {
			in nutationMotion : NutationAngleValue;
			in discForce : ForceValue;
			out shaftTorque : TorqueValue;
			out shaftSpeed : AngularVelocityValue;
		}
		
		flow convertToRotation.shaftTorque to transmitPower.shaftTorque;
		flow convertToRotation.shaftSpeed to transmitPower.shaftSpeed;
		
		then action transmitPower : TransmitPower {
			in shaftTorque : TorqueValue;
			in shaftSpeed : AngularVelocityValue;
			out mechanicalPower = OperateNutatingDiscEngine::mechanicalPower;
		}
		
		then action expelFluid : ExpelFluid {
			in chamberVolume = admitFluid.chamberVolume;
			in chamberPressure = admitFluid.chamberPressure;
			out exhaustFlow = OperateNutatingDiscEngine::exhaustFlow;
		}
		
		then continuousOperation;
	}
	
	attribute def StartCommand;
	attribute def StopCommand;
	attribute def ResetCommand;
	
	state def EngineOperatingStates {
		entry; then idle;
		
		state idle;
		
		transition idle_to_starting
			first idle
			accept startCommand : StartCommand
			then starting;
		
		state starting;
		
		transition starting_to_running
			first starting
			then running;
		
		state running;
		
		transition running_to_stopping
			first running
			accept stopCommand : StopCommand
			then stopping;
		
		transition running_to_fault
			first running
			then fault;
		
		state stopping;
		
		transition stopping_to_idle
			first stopping
			then idle;
		
		state fault;
		
		transition fault_to_idle
			first fault
			accept resetCommand : ResetCommand
			then idle;
	}
	
	part def NutatingDiscEngine {
		attribute engineEfficiency : EfficiencyValue;
		attribute maxPressure : PressureValue;
		attribute maxTorque : TorqueValue;
		attribute displacementVolume : VolumeValue;
		attribute operatingTemperature : ThermodynamicTemperatureValue;
		
		port fluidInlet : FluidInletPort;
		port fluidOutlet : FluidOutletPort;
		port powerOutput : PowerOutputPort;
		
		part nutatingDisc : NutatingDisc {
			attribute :>> nutationAngle = 23.0 [deg];
			attribute :>> discDiameter = 150.0 [mm];
			attribute :>> discThickness = 20.0 [mm];
			attribute :>> mass = 2.5 [kg];
			attribute :>> wobbleRate : AngularVelocityValue;
		}
		
		part housingChamber : HousingChamber {
			attribute :>> chamberVolume = 1500.0 [mm^3];
			attribute :>> inletArea = 500.0 [mm^2];
			attribute :>> outletArea = 500.0 [mm^2];
			attribute :>> wallThickness = 8.0 [mm];
		}
		
		part outputShaft : OutputShaft {
			attribute :>> shaftDiameter = 25.0 [mm];
			attribute :>> shaftLength = 200.0 [mm];
			attribute :>> outputTorque : TorqueValue;
			attribute :>> rotationalSpeed : AngularVelocityValue;
			attribute :>> inertia = 0.05 [kg*m^2];
		}
		
		part sphereSupport : SphereSupport {
			attribute :>> sphereDiameter = 80.0 [mm];
			attribute :>> contactAngle = 23.0 [deg];
			attribute :>> bearingLoad : ForceValue;
		}
		
		part intakeValve : IntakeValve {
			attribute :>> valveArea = 400.0 [mm^2];
			attribute :>> openingPressure = 150000.0 [Pa];
		}
		
		part exhaustValve : ExhaustValve {
			attribute :>> valveArea = 400.0 [mm^2];
			attribute :>> closingPressure = 100000.0 [Pa];
		}
		
		connection fluidToIntake connect fluidInlet to intakeValve;
		connection intakeToChamber connect intakeValve to housingChamber;
		connection discToSphere connect nutatingDisc to sphereSupport;
		connection discToShaft connect nutatingDisc to outputShaft;
		connection chamberToExhaust connect housingChamber to exhaustValve;
		connection exhaustToOutlet connect exhaustValve to fluidOutlet;
		connection shaftToPowerOutput connect outputShaft to powerOutput;
	}
	
	requirement def EnginePerformanceRequirement {
		doc /* The nutating disc engine shall convert pressurized fluid energy 
		       into continuous rotational mechanical power with specified efficiency 
		       and torque output characteristics. */
		
		subject engine : NutatingDiscEngine;
		
		require minEfficiency : EfficiencyRequirement {
			attribute requiredEfficiency : EfficiencyValue = 0.75;
		}
		
		require torqueOutput : TorqueRequirement {
			attribute minTorque : TorqueValue = 50.0 [N*m];
		}
		
		require pressureRange : PressureRequirement {
			attribute minPressure : PressureValue = 200000.0 [Pa];
			attribute maxPressure : PressureValue = 1000000.0 [Pa];
		}
		
		require speedRange : SpeedRequirement {
			attribute minSpeed : AngularVelocityValue = 100.0 [rad/s];
			attribute maxSpeed : AngularVelocityValue = 500.0 [rad/s];
		}
	}
	
	requirement def EfficiencyRequirement {
		attribute requiredEfficiency : EfficiencyValue;
		require constraint { engineEfficiency >= requiredEfficiency }
	}
	
	requirement def TorqueRequirement {
		attribute minTorque : TorqueValue;
		require constraint { outputTorque >= minTorque }
	}
	
	requirement def PressureRequirement {
		attribute minPressure : PressureValue;
		attribute maxPressure : PressureValue;
		require constraint { 
			inputPressure >= minPressure and inputPressure <= maxPressure 
		}
	}
	
	requirement def SpeedRequirement {
		attribute minSpeed : AngularVelocityValue;
		attribute maxSpeed : AngularVelocityValue;
		require constraint {
			rotationalSpeed >= minSpeed and rotationalSpeed <= maxSpeed
		}
	}
	
	constraint def PowerCalculation {
		in torque : TorqueValue;
		in angularVelocity : AngularVelocityValue;
		out power : PowerValue;
		power == torque * angularVelocity
	}
	
	constraint def EfficiencyCalculation {
		in outputPower : PowerValue;
		in inputPower : PowerValue;
		out efficiency : EfficiencyValue;
		efficiency == outputPower / inputPower
	}
	
	part nutatingDiscEngineSystem : NutatingDiscEngine {
		attribute :>> engineEfficiency = 0.82;
		attribute :>> maxPressure = 1000000.0 [Pa];
		attribute :>> maxTorque = 120.0 [N*m];
		attribute :>> displacementVolume = 0.0015 [m^3];
		attribute :>> operatingTemperature = 350.0 [K];
		
		assert requirement enginePerformance : EnginePerformanceRequirement {
			subject nutatingDiscEngineSystem;
			
			require :>> minEfficiency {
				attribute :>> requiredEfficiency = 0.80;
			}
			
			require :>> torqueOutput {
				attribute :>> minTorque = 50.0 [N*m];
			}
			
			require :>> pressureRange {
				attribute :>> minPressure = 200000.0 [Pa];
				attribute :>> maxPressure = 1000000.0 [Pa];
			}
			
			require :>> speedRange {
				attribute :>> minSpeed = 100.0 [rad/s];
				attribute :>> maxSpeed = 500.0 [rad/s];
			}
		}
		
		assert constraint powerCalc : PowerCalculation {
			in torque = outputShaft.outputTorque;
			in angularVelocity = outputShaft.rotationalSpeed;
			out power = powerOutput.mechanicalPower.power;
		}
	}
	
	comment about nutatingDiscEngineSystem
	/* This nutating disc engine system converts pressurized fluid energy into 
	   continuous rotational mechanical power through a wobbling disc mechanism. 
	   The primary function operates by admitting pressurized fluid into a spherical 
	   chamber containing a nutating disc mounted on a central sphere support. 
	   As fluid pressure acts on the disc, it causes the disc to nutate (wobble) 
	   around the sphere in a complex motion that combines rotation and precession. 
	   This nutating motion is mechanically coupled to an output shaft through 
	   a linkage that converts the wobbling motion into smooth, continuous rotation. 
	   The disc simultaneously acts as a moving seal, creating expanding and 
	   contracting chambers that sequentially intake pressurized fluid and expel 
	   it after energy extraction. The continuous cycle of fluid admission, disc 
	   nutation, rotational conversion, and fluid expulsion produces steady 
	   mechanical power output suitable for driving generators, pumps, or other 
	   rotating machinery. */
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;
    private import 'Nutating Disc Engine System'::*;

    part testSubject : NutatingDisc {
        exhibit state sm : EngineOperatingStates;
    }

    action orchestrator {
        item testFluidInput : FluidInput {
            attribute pressure : PressureValue;
            attribute flowRate : FlowRateValue;
            attribute temperature : ThermodynamicTemperatureValue;
        }
        action actionProbe : AdmitFluid {
            in fluidInput = testFluidInput;
        }
        first actionProbe;
    }
}
