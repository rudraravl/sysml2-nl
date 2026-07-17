package RotaryEngineSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	item def AirFuelMixture {
		attribute airMassFlow : MassFlowRateValue;
		attribute fuelMassFlow : MassFlowRateValue;
		attribute temperature : ThermodynamicTemperatureValue;
		attribute pressure : PressureValue;
	}
	
	item def ExhaustGas {
		attribute massFlow : MassFlowRateValue;
		attribute temperature : ThermodynamicTemperatureValue;
		attribute pressure : PressureValue;
	}
	
	item def CoolantFluid {
		attribute massFlow : MassFlowRateValue;
		attribute inletTemperature : ThermodynamicTemperatureValue;
		attribute outletTemperature : ThermodynamicTemperatureValue;
	}
	
	item def IgnitionCommand;
	item def StartCommand;
	item def StopCommand;
	
	port def IntakePort {
		in item mixture : AirFuelMixture;
	}
	
	port def ExhaustPort {
		out item exhaust : ExhaustGas;
	}
	
	port def PowerPort {
		out attribute torque : TorqueValue;
		out attribute speed : AngularVelocityValue;
	}
	
	port def CoolantPort {
		in item coolantIn : CoolantFluid;
		out item coolantOut : CoolantFluid;
	}
	
	part def Rotor {
		attribute mass : MassValue;
		attribute eccentricity : LengthValue;
		attribute currentAngle : AngularPositionValue;
		attribute inertia : MomentOfInertiaValue;
	}
	
	part def Housing {
		attribute epitrochoidMajorRadius : LengthValue;
		attribute epitrochoidMinorRadius : LengthValue;
		attribute chamberVolume : VolumeValue;
		attribute wallThickness : LengthValue;
		
		port intake : IntakePort;
		port exhaust : ExhaustPort;
		port cooling : CoolantPort;
	}
	
	part def EccentricShaft {
		attribute diameter : LengthValue;
		attribute eccentricity : LengthValue;
		attribute torsionalStiffness : Real;
		
		port output : PowerPort;
	}
	
	part def IgnitionSystem {
		attribute sparkTiming : TimeValue;
		attribute sparkEnergy : EnergyValue;
		
		out attribute ignitionSignal : IgnitionCommand;
	}
	
	part def CoolingSystem {
		attribute coolantCapacity : VolumeValue;
		attribute pumpFlowRate : VolumeFlowRateValue;
		attribute radiatorEfficiency : Real;
		
		port circulation : CoolantPort;
	}
	
	action def IntakeStroke {
		in mixture : AirFuelMixture;
		out chamberFilled : Boolean;
		out intakeVolume : VolumeValue;
	}
	
	action def CompressionStroke {
		in chamberFilled : Boolean;
		in initialVolume : VolumeValue;
		out compressed : Boolean;
		out compressionRatio : Real;
		out compressedPressure : PressureValue;
	}
	
	action def CombustionStroke {
		in compressed : Boolean;
		in ignition : IgnitionCommand;
		in compressedPressure : PressureValue;
		out combusted : Boolean;
		out peakPressure : PressureValue;
		out peakTemperature : ThermodynamicTemperatureValue;
	}
	
	action def ExpansionStroke {
		in combusted : Boolean;
		in peakPressure : PressureValue;
		out rotorTorque : TorqueValue;
		out expandedGas : ExhaustGas;
	}
	
	action def ExhaustStroke {
		in expandedGas : ExhaustGas;
		out exhaustComplete : Boolean;
		out exhaustOutput : ExhaustGas;
	}
	
	action def TransmitPower {
		in rotorTorque : TorqueValue;
		in rotorInertia : MomentOfInertiaValue;
		out shaftTorque : TorqueValue;
		out shaftSpeed : AngularVelocityValue;
	}
	
	action def RotaryEngineCycle {
		in mixtureInput : AirFuelMixture;
		in ignitionTrigger : IgnitionCommand;
		out outputTorque : TorqueValue;
		out outputSpeed : AngularVelocityValue;
		out exhaustGas : ExhaustGas;
		
		first start;
		then merge cycleLoop;
		
		then action intake : IntakeStroke {
			in mixture = mixtureInput;
			out chamberFilled : Boolean;
			out intakeVolume : VolumeValue;
		}
		
		flow intake.chamberFilled to compression.chamberFilled;
		flow intake.intakeVolume to compression.initialVolume;
		
		then action compression : CompressionStroke {
			in chamberFilled : Boolean;
			in initialVolume : VolumeValue;
			out compressed : Boolean;
			out compressionRatio : Real;
			out compressedPressure : PressureValue;
		}
		
		flow compression.compressed to combustion.compressed;
		flow compression.compressedPressure to combustion.compressedPressure;
		
		then action combustion : CombustionStroke {
			in compressed : Boolean;
			in ignition = ignitionTrigger;
			in compressedPressure : PressureValue;
			out combusted : Boolean;
			out peakPressure : PressureValue;
			out peakTemperature : ThermodynamicTemperatureValue;
		}
		
		flow combustion.combusted to expansion.combusted;
		flow combustion.peakPressure to expansion.peakPressure;
		
		then action expansion : ExpansionStroke {
			in combusted : Boolean;
			in peakPressure : PressureValue;
			out rotorTorque : TorqueValue;
			out expandedGas : ExhaustGas;
		}
		
		flow expansion.expandedGas to exhaustAction.expandedGas;
		flow expansion.rotorTorque to powerTransmit.rotorTorque;
		
		then action exhaustAction : ExhaustStroke {
			in expandedGas : ExhaustGas;
			out exhaustComplete : Boolean;
			out exhaustOutput = exhaustGas;
		}
		
		then action powerTransmit : TransmitPower {
			in rotorTorque : TorqueValue;
			in rotorInertia = 0.08 [kg*m^2];
			out shaftTorque = outputTorque;
			out shaftSpeed = outputSpeed;
		}
		
		then cycleLoop;
	}
	
	state def EngineOperatingStates {
		in torqueOutput : TorqueValue;
		in speedOutput : AngularVelocityValue;
		
		entry; then off;
		
		state off;
		
		transition off_to_starting
			first off
			accept startCommand : StartCommand
			then starting;
		
		state starting;
		
		transition starting_to_running
			first starting
			then running;
		
		state running {
			do action cycleAction : RotaryEngineCycle;
		}
		
		transition running_to_stopping
			first running
			accept stopCommand : StopCommand
			then stopping;
		
		state stopping;
		
		transition stopping_to_off
			first stopping
			then off;
	}
	
	part def RotaryEngine {
		attribute displacement : VolumeValue;
		attribute compressionRatio : Real;
		attribute maxTorque : TorqueValue;
		attribute maxSpeed : AngularVelocityValue;
		attribute currentTorque : TorqueValue;
		attribute currentSpeed : AngularVelocityValue;
		attribute operatingTemperature : ThermodynamicTemperatureValue;
		
		part rotor : Rotor[3] {
			attribute :>> mass = 2.8 [kg];
			attribute :>> eccentricity = 15.0 [mm];
			attribute :>> inertia = 0.027 [kg*m^2];
		}
		
		part housing : Housing {
			attribute :>> epitrochoidMajorRadius = 105.0 [mm];
			attribute :>> epitrochoidMinorRadius = 15.0 [mm];
			attribute :>> chamberVolume = 654.0 [cm^3];
			attribute :>> wallThickness = 8.0 [mm];
		}
		
		part eccentricShaft : EccentricShaft {
			attribute :>> diameter = 54.0 [mm];
			attribute :>> eccentricity = 15.0 [mm];
			attribute :>> torsionalStiffness = 1.2e6;
		}
		
		part ignitionSystem : IgnitionSystem {
			attribute :>> sparkTiming = 0.0015 [s];
			attribute :>> sparkEnergy = 0.05 [J];
		}
		
		part coolingSystem : CoolingSystem {
			attribute :>> coolantCapacity = 8.0 [L];
			attribute :>> pumpFlowRate = 0.002 [m^3/s];
			attribute :>> radiatorEfficiency = 0.85;
		}
		
		port intakePort : IntakePort;
		port exhaustPort : ExhaustPort;
		port powerOutputPort : PowerPort;
		port coolantPort : CoolantPort;
		
		connect housing.intake to intakePort;
		connect housing.exhaust to exhaustPort;
		connect housing.cooling to coolingSystem.circulation;
		connect coolingSystem.circulation to coolantPort;
		connect eccentricShaft.output to powerOutputPort;
		
		perform action engineOperation : RotaryEngineCycle;
	}
	
	requirement def PowerOutputRequirement {
		doc /* The rotary engine shall deliver continuous power output of at least 180 kW at 8000 rpm. */
		
		attribute minPower : PowerValue = 180.0 [kW];
		attribute targetSpeed : AngularVelocityValue = 8000.0 [rpm];
		
		require constraint {
			outputPower : PowerValue;
			outputSpeed : AngularVelocityValue;
			outputPower >= minPower and outputSpeed >= targetSpeed
		}
	}
	
	requirement def ThermalManagementRequirement {
		doc /* The engine cooling system shall maintain operating temperature below 393 K during continuous operation. */
		
		attribute maxTemperature : ThermodynamicTemperatureValue = 393.0 [K];
		
		require constraint {
			engineTemp : ThermodynamicTemperatureValue;
			engineTemp <= maxTemperature
		}
	}
	
	requirement def EfficiencyRequirement {
		doc /* The rotary engine shall achieve thermal efficiency of at least 28% under rated conditions. */
		
		attribute minEfficiency : Real = 0.28;
		
		require constraint {
			thermalEfficiency : Real;
			thermalEfficiency >= minEfficiency
		}
	}
	
	requirement def DurabilityRequirement {
		doc /* The engine shall operate for at least 5000 hours before major overhaul. */
		
		attribute minOperatingHours : TimeValue = 5000.0 [h];
	}
	
	part rotaryEngineSystem : RotaryEngine {
		attribute :>> displacement = 1308.0 [cm^3];
		attribute :>> compressionRatio = 9.7;
		attribute :>> maxTorque = 220.0 [N*m];
		attribute :>> maxSpeed = 9000.0 [rpm];
		attribute :>> currentTorque = 0.0 [N*m];
		attribute :>> currentSpeed = 0.0 [rpm];
		attribute :>> operatingTemperature = 363.0 [K];
		
		satisfy powerReq : PowerOutputRequirement by rotaryEngineSystem;
		satisfy thermalReq : ThermalManagementRequirement by coolingSystem;
		satisfy efficiencyReq : EfficiencyRequirement by rotaryEngineSystem;
		satisfy durabilityReq : DurabilityRequirement by rotaryEngineSystem;
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import RotaryEngineSystem::*;

    part testSubject : Rotor {
        exhibit state sm : EngineOperatingStates;
    }

    action orchestrator {
        item testMixture : AirFuelMixture {
            attribute airMassFlow : MassFlowRateValue;
            attribute fuelMassFlow : MassFlowRateValue;
            attribute temperature : ThermodynamicTemperatureValue;
            attribute pressure : PressureValue;
        }
        action actionProbe : IntakeStroke {
            in mixture = testMixture;
        }
        first actionProbe;
    }
}
