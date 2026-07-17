package 'Reciprocating Engine System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		
		attribute def RPM :> Real;
		attribute def CompressionRatio :> Real;
		attribute def AirFuelRatio :> Real;
		
		item def FuelAirMixture {
			attribute fuelMass : MassValue;
			attribute airMass : MassValue;
			attribute temperature : ThermodynamicTemperatureValue;
			attribute pressure : PressureValue;
		}
		
		item def CombustionGases {
			attribute temperature : ThermodynamicTemperatureValue;
			attribute pressure : PressureValue;
			attribute massFlow : MassFlowRateValue;
		}
		
		port def AirIntakePort;
		port def FuelInjectionPort;
		port def ExhaustPort;
		port def CrankshaftPort;
		port def CoolantPort;
		
		interface def IntakeInterface {
			end airIn : AirIntakePort;
			end fuelIn : FuelInjectionPort;
		}
		
		interface def ExhaustInterface {
			end exhaustOut : ExhaustPort;
		}
		
		part def Cylinder {
			attribute bore : LengthValue;
			attribute stroke : LengthValue;
			attribute displacement : VolumeValue = 3.14159 * (bore ** 2) / 4.0 * stroke;
			
			part piston : Piston;
			part intakeValve : Valve;
			part exhaustValve : Valve;
			part sparkPlug : IgnitionDevice;
		}
		
		part def Piston {
			attribute position : LengthValue;
			attribute speed : SpeedValue;
		}
		
		part def Valve {
			attribute isOpen : Boolean;
			attribute liftHeight : LengthValue;
		}
		
		part def IgnitionDevice {
			attribute firingAngle : Real;
		}
		
		part def Crankshaft {
			attribute angularPosition : Real;
			attribute angularVelocity : AngularVelocityValue;
			attribute outputTorque : TorqueValue;
			port crankPort : CrankshaftPort;
		}
		
		part def CamshaftAssembly {
			attribute rotationalSpeed : RPM;
			attribute phaseAngle : Real;
		}
		
		part def LubricationSystem {
			attribute oilPressure : PressureValue;
			attribute oilTemperature : ThermodynamicTemperatureValue;
			attribute oilFlowRate : VolumeFlowRateValue;
		}
		
		part def CoolingSystem {
			attribute coolantTemperature : ThermodynamicTemperatureValue;
			attribute coolantFlowRate : VolumeFlowRateValue;
			port coolantIn : CoolantPort;
			port coolantOut : CoolantPort;
		}
		
		part def FuelSystem {
			attribute fuelPressure : PressureValue;
			attribute fuelFlowRate : MassFlowRateValue;
			port fuelDelivery : FuelInjectionPort;
		}
		
		state def EngineCycleStates {
			entry; then intake;
			
			state intake {
				doc /* Intake valve opens, piston moves down, drawing in fuel-air mixture */
			}
			then compression;
			
			state compression {
				doc /* Both valves closed, piston moves up, compressing mixture */
			}
			then power;
			
			state power {
				doc /* Spark ignites mixture, expanding gases drive piston down */
			}
			then exhaust;
			
			state exhaust {
				doc /* Exhaust valve opens, piston moves up, expelling combustion gases */
			}
			then intake;
		}
		
		action def IntakeStroke {
			in airMass : MassValue;
			in fuelMass : MassValue;
			out mixture : FuelAirMixture;
		}
		
		action def CompressionStroke {
			in mixture : FuelAirMixture;
			in compressionRatio : CompressionRatio;
			out compressedMixture : FuelAirMixture;
		}
		
		action def PowerStroke {
			in compressedMixture : FuelAirMixture;
			out torque : TorqueValue;
			out combustionGases : CombustionGases;
		}
		
		action def ExhaustStroke {
			in combustionGases : CombustionGases;
			out exhaustGases : CombustionGases;
		}
		
		action def ConvertChemicalToMechanicalEnergy {
			doc /* 
			 * Primary Function: Convert chemical energy stored in fuel into mechanical 
			 * rotational energy through a four-stroke combustion cycle. The reciprocating 
			 * linear motion of pistons within cylinders is transformed into continuous 
			 * rotational motion of the crankshaft, producing usable mechanical power.
			 */
			
			in fuelInput : MassFlowRateValue;
			in airInput : MassFlowRateValue;
			in compressionRatio : CompressionRatio;
			out mechanicalTorque : TorqueValue;
			out rotationalSpeed : RPM;
			out exhaustOutput : CombustionGases;
			
			first start;
			then merge continuousCycle;
			
			action admitCharge : IntakeStroke {
				in airMass : MassValue;
				in fuelMass : MassValue;
				out mixture : FuelAirMixture;
			}
			
			flow admitCharge.mixture to compressCharge.mixture;
			
			action compressCharge : CompressionStroke {
				in mixture : FuelAirMixture;
				in compressionRatio = ConvertChemicalToMechanicalEnergy::compressionRatio;
				out compressedMixture : FuelAirMixture;
			}
			
			flow compressCharge.compressedMixture to extractWork.compressedMixture;
			
			action extractWork : PowerStroke {
				in compressedMixture : FuelAirMixture;
				out torque = mechanicalTorque;
				out combustionGases : CombustionGases;
			}
			
			flow extractWork.combustionGases to expelGases.combustionGases;
			
			action expelGases : ExhaustStroke {
				in combustionGases : CombustionGases;
				out exhaustGases = exhaustOutput;
			}
			
			then continuousCycle;
		}
		
		part def ReciprocatingEngine {
			attribute numberOfCylinders : Integer;
			attribute totalDisplacement : VolumeValue;
			attribute compressionRatio : CompressionRatio;
			attribute operatingSpeed : RPM;
			attribute outputTorque : TorqueValue;
			attribute outputPower : PowerValue;
			attribute operatingTemperature : ThermodynamicTemperatureValue;
			
			port airIntake : AirIntakePort;
			port fuelIntake : FuelInjectionPort;
			port exhaustOutput : ExhaustPort;
			port powerOutput : CrankshaftPort;
			port coolantIn : CoolantPort;
			port coolantOut : CoolantPort;
			
			part cylinders : Cylinder[numberOfCylinders];
			part crankshaft : Crankshaft {
				port :>> crankPort;
			}
			part camshaft : CamshaftAssembly;
			part lubrication : LubricationSystem;
			part cooling : CoolingSystem {
				port :>> coolantIn;
				port :>> coolantOut;
			}
			part fuelSystem : FuelSystem {
				port :>> fuelDelivery;
			}
			
			interface intakeConnection : IntakeInterface
				connect airIntake to intakeConnection.airIn;
				connect fuelIntake to intakeConnection.fuelIn;
			
			interface exhaustConnection : ExhaustInterface
				connect exhaustOutput to exhaustConnection.exhaustOut;
			
			perform action primaryFunction : ConvertChemicalToMechanicalEnergy;
			
			assert constraint powerCalculation {
				outputPower == outputTorque * crankshaft.angularVelocity
			}
		}
	}
	
	package Usages {
		public import Definitions::*;
		
		part inlineFourEngine : ReciprocatingEngine {
			attribute :>> numberOfCylinders = 4;
			attribute :>> totalDisplacement = 2.0 [L];
			attribute :>> compressionRatio = 10.5;
			attribute :>> operatingSpeed = 3000.0;
			attribute :>> outputTorque = 200.0 [N * m];
			attribute :>> outputPower = 62.8 [kW];
			attribute :>> operatingTemperature = 363.15 [K];
			
			part :>> cylinders : Cylinder[4] {
				attribute :>> bore = 86.0 [mm];
				attribute :>> stroke = 86.0 [mm];
				attribute :>> displacement = 0.5 [L];
			}
			
			part :>> crankshaft : Crankshaft {
				attribute :>> angularVelocity = 314.16 [rad / s];
				attribute :>> outputTorque = 200.0 [N * m];
			}
			
			part :>> lubrication : LubricationSystem {
				attribute :>> oilPressure = 400.0 [kPa];
				attribute :>> oilTemperature = 363.15 [K];
				attribute :>> oilFlowRate = 5.0 [L / min];
			}
			
			part :>> cooling : CoolingSystem {
				attribute :>> coolantTemperature = 358.15 [K];
				attribute :>> coolantFlowRate = 50.0 [L / min];
			}
			
			part :>> fuelSystem : FuelSystem {
				attribute :>> fuelPressure = 350.0 [kPa];
				attribute :>> fuelFlowRate = 0.008 [kg / s];
			}
			
			perform action :>> primaryFunction : ConvertChemicalToMechanicalEnergy {
				in fuelInput = 0.008 [kg / s];
				in airInput = 0.112 [kg / s];
				in compressionRatio = 10.5;
				out mechanicalTorque = 200.0 [N * m];
				out rotationalSpeed = 3000.0;
			}
		}
		
		part v6Engine : ReciprocatingEngine {
			attribute :>> numberOfCylinders = 6;
			attribute :>> totalDisplacement = 3.5 [L];
			attribute :>> compressionRatio = 11.0;
			attribute :>> operatingSpeed = 4000.0;
			attribute :>> outputTorque = 350.0 [N * m];
			attribute :>> outputPower = 146.6 [kW];
			attribute :>> operatingTemperature = 368.15 [K];
		}
	}
	
	package Requirements {
		public import Definitions::*;
		
		requirement def PowerOutputRequirement {
			doc /* The engine shall deliver specified minimum power output. */
			
			attribute requiredPower : PowerValue;
			attribute actualPower : PowerValue;
			
			require constraint {
				actualPower >= requiredPower
			}
		}
		
		requirement def TorqueRequirement {
			doc /* The engine shall produce specified minimum torque. */
			
			attribute requiredTorque : TorqueValue;
			attribute actualTorque : TorqueValue;
			attribute operatingRPM : RPM;
			
			require constraint {
				actualTorque >= requiredTorque
			}
		}
		
		requirement def EfficiencyRequirement {
			doc /* The engine shall achieve minimum thermal efficiency. */
			
			attribute thermalEfficiency : Real;
			attribute minimumEfficiency : Real;
			
			require constraint {
				thermalEfficiency >= minimumEfficiency
			}
		}
		
		requirement def OperatingTemperatureRequirement {
			doc /* The engine operating temperature shall remain within safe limits. */
			
			attribute operatingTemp : ThermodynamicTemperatureValue;
			attribute maxTemp : ThermodynamicTemperatureValue;
			attribute minTemp : ThermodynamicTemperatureValue;
			
			require constraint {
				operatingTemp >= minTemp and operatingTemp <= maxTemp
			}
		}
		
		requirement def LubricationRequirement {
			doc /* The lubrication system shall maintain minimum oil pressure. */
			
			attribute oilPressure : PressureValue;
			attribute minOilPressure : PressureValue;
			
			require constraint {
				oilPressure >= minOilPressure
			}
		}
		
		requirement <'ENG-REQ-001'> enginePowerOutput : PowerOutputRequirement {
			doc /* The reciprocating engine shall produce minimum 60 kW at 3000 RPM. */
			
			subject engine : ReciprocatingEngine;
			
			attribute :>> requiredPower = 60.0 [kW];
			attribute :>> actualPower = engine.outputPower;
		}
		
		requirement <'ENG-REQ-002'> engineTorque : TorqueRequirement {
			doc /* The engine shall produce minimum 180 N*m torque at 3000 RPM. */
			
			subject engine : ReciprocatingEngine;
			
			attribute :>> requiredTorque = 180.0 [N * m];
			attribute :>> actualTorque = engine.outputTorque;
			attribute :>> operatingRPM = 3000.0;
		}
		
		requirement <'ENG-REQ-003'> engineEfficiency : EfficiencyRequirement {
			doc /* The engine thermal efficiency shall be at least 30 percent. */
			
			subject engine : ReciprocatingEngine;
			
			attribute :>> minimumEfficiency = 0.30;
			attribute :>> thermalEfficiency : Real;
		}
		
		requirement <'ENG-REQ-004'> engineTemperature : OperatingTemperatureRequirement {
			doc /* Engine operating temperature shall be between 80°C and 110°C. */
			
			subject engine : ReciprocatingEngine;
			
			attribute :>> operatingTemp = engine.operatingTemperature;
			attribute :>> maxTemp = 383.15 [K];
			attribute :>> minTemp = 353.15 [K];
		}
		
		requirement <'ENG-REQ-005'> lubricationPressure : LubricationRequirement {
			doc /* Oil pressure shall be maintained above 300 kPa during operation. */
			
			subject engine : ReciprocatingEngine;
			
			attribute :>> oilPressure = engine.lubrication.oilPressure;
			attribute :>> minOilPressure = 300.0 [kPa];
		}
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Reciprocating Engine System'::*;

    part testSubject : Cylinder {
        exhibit state sm : EngineCycleStates;
    }

    action orchestrator {
        attribute testAirMass : MassValue;
        attribute testFuelMass : MassValue;
        action admitChargeProbe : IntakeStroke {
            in airMass = testAirMass;
            in fuelMass = testFuelMass;
        }
        first admitChargeProbe;
    }
}
