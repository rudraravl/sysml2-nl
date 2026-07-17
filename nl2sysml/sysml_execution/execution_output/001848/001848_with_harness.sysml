package 'Roots Supercharger System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	item def Air {
		attribute pressure : PressureValue;
		attribute temperature : ThermodynamicTemperatureValue;
		attribute massFlowRate : MassFlowRateValue;
		attribute density : DensityValue;
	}

	item def MechanicalPower {
		attribute torque : TorqueValue;
		attribute rotationalSpeed : AngularVelocityValue;
		attribute power : PowerValue;
	}

	item def Lubricant {
		attribute viscosity : Real;
		attribute temperature : ThermodynamicTemperatureValue;
		attribute flowRate : VolumeFlowRateValue;
	}

	port def AirIntakePort {
		in item ambientAir : Air;
	}

	port def AirDischargePort {
		out item compressedAir : Air;
	}

	port def MechanicalDrivePort {
		in item drivePower : MechanicalPower;
	}

	port def LubricationPort {
		in item oil : Lubricant;
	}

	part def RotorProfile {
		attribute lobeCount : Integer;
		attribute helixAngle : Real;
		attribute rotorDiameter : LengthValue;
		attribute rotorLength : LengthValue;
	}

	part def Rotor {
		attribute rotorType : String;
		attribute mass : MassValue;
		attribute currentAngle : Real;
		attribute angularVelocity : AngularVelocityValue;
		attribute profile : RotorProfile;
	}

	part def BearingAssembly {
		attribute bearingType : String;
		attribute loadCapacity : ForceValue;
		part frontBearing {
			attribute innerDiameter : LengthValue;
			attribute outerDiameter : LengthValue;
		}
		part rearBearing {
			attribute innerDiameter : LengthValue;
			attribute outerDiameter : LengthValue;
		}
	}

	part def RotorAssembly {
		part maleRotor : Rotor {
			attribute :>> rotorType = "male";
		}
		part femaleRotor : Rotor {
			attribute :>> rotorType = "female";
		}
		part bearings : BearingAssembly;
	}

	part def HousingAssembly {
		attribute material : String;
		attribute wallThickness : LengthValue;
		part intakeChamber {
			attribute volume : VolumeValue;
		}
		part dischargeChamber {
			attribute volume : VolumeValue;
		}
		part rotorCavity {
			attribute clearance : LengthValue;
		}
	}

	part def DriveMechanism {
		attribute driveRatio : Real;
		attribute efficiency : Real;
		part drivePulley {
			attribute diameter : LengthValue;
			attribute numberOfGrooves : Integer;
		}
		part driveBelt {
			attribute width : LengthValue;
			attribute tensionForce : ForceValue;
		}
		part driveShaft {
			attribute diameter : LengthValue;
			attribute length : LengthValue;
			attribute material : String;
		}
	}

	part def SealingSystem {
		part rotorSeals {
			attribute sealMaterial : String;
			attribute clearance : LengthValue;
		}
		part shaftSeals {
			attribute sealType : String;
			attribute pressureRating : PressureValue;
		}
		part housingGaskets {
			attribute gasketMaterial : String;
			attribute thickness : LengthValue;
		}
	}

	action def IntakeAir {
		in attribute inletPressure : PressureValue;
		in attribute inletTemperature : ThermodynamicTemperatureValue;
		out attribute airVolume : VolumeValue;
	}

	action def TrapAir {
		in attribute trappedVolume : VolumeValue;
		in attribute rotorPosition : Real;
		out attribute sealedCavity : Boolean;
	}

	action def TransportAir {
		in attribute rotationAngle : Real;
		in attribute rotorSpeed : AngularVelocityValue;
		out attribute transportTime : TimeValue;
	}

	action def DischargeAir {
		in attribute cavityVolume : VolumeValue;
		in attribute dischargePressure : PressureValue;
		out attribute compressedAir : Air;
	}

	action def CompressAir {
		in attribute ambientPressure : PressureValue;
		in attribute ambientTemperature : ThermodynamicTemperatureValue;
		in attribute rotorSpeed : AngularVelocityValue;
		in attribute displacement : VolumeValue;
		out attribute boostedPressure : PressureValue;
		out attribute boostedTemperature : ThermodynamicTemperatureValue;
		out attribute airMassFlow : MassFlowRateValue;

		first start;
		then action intake : IntakeAir;
		then action trap : TrapAir;
		then action transport : TransportAir;
		then action discharge : DischargeAir;
		then done;
	}

	part def RootsSupercharger {
		attribute nominalDisplacement : VolumeValue;
		attribute maxBoostPressure : PressureValue;
		attribute maxRotorSpeed : AngularVelocityValue;
		attribute compressionRatio : Real;
		attribute currentRotorSpeed : AngularVelocityValue;
		attribute currentBoostLevel : PressureValue;
		attribute currentThrottlePosition : Real;
		attribute nominalSpeed : AngularVelocityValue;

		port intakePort : AirIntakePort;
		port dischargePort : AirDischargePort;
		port drivePort : MechanicalDrivePort;
		port lubricationPort : LubricationPort;

		part housing : HousingAssembly;
		part rotors : RotorAssembly;
		part drive : DriveMechanism;
		part seals : SealingSystem;

		perform action compressAir : CompressAir;
	}

	part def Engine {
		port airIntake : AirIntakePort;
		port mechanicalOutput : MechanicalDrivePort;
		attribute engineSpeed : AngularVelocityValue;
		attribute throttlePosition : Real;
		attribute displacement : VolumeValue;
	}

	part def Intercooler {
		port hotAirInlet : AirIntakePort;
		port cooledAirOutlet : AirDischargePort;
		attribute coolingEfficiency : Real;
		attribute heatTransferRate : PowerValue;
	}

	part def IntakeManifold {
		port airInlet : AirIntakePort;
		attribute volume : VolumeValue;
		attribute pressure : PressureValue;
	}

	part def LubricationSystem {
		port oilSupply : LubricationPort;
		part oilPump {
			attribute flowRate : VolumeFlowRateValue;
			attribute pressure : PressureValue;
		}
		part oilReservoir {
			attribute capacity : VolumeValue;
			attribute oilLevel : LengthValue;
		}
		part oilCooler {
			attribute coolingCapacity : PowerValue;
		}
	}

	part superchargedEngineSystem {
		part engine : Engine {
			attribute :>> engineSpeed = 3000.0[SI::rpm];
			attribute :>> throttlePosition = 60.0;
			attribute :>> displacement = 5.0[SI::L];
		}

		part supercharger : RootsSupercharger {
			attribute :>> nominalDisplacement = 2.3[SI::L];
			attribute :>> maxBoostPressure = 1.2[SI::bar];
			attribute :>> maxRotorSpeed = 15000.0[SI::rpm];
			attribute :>> compressionRatio = 2.5;
			attribute :>> nominalSpeed = 10000.0[SI::rpm];

			part :>> rotors {
				part :>> maleRotor {
					attribute :>> mass = 3.5[SI::kg];
					attribute :>> currentAngle = 0.0;
					attribute :>> profile {
						attribute :>> lobeCount = 3;
						attribute :>> helixAngle = 60.0;
						attribute :>> rotorDiameter = 120.0[SI::mm];
						attribute :>> rotorLength = 250.0[SI::mm];
					}
				}
				part :>> femaleRotor {
					attribute :>> mass = 3.2[SI::kg];
					attribute :>> currentAngle = 0.0;
					attribute :>> profile {
						attribute :>> lobeCount = 3;
						attribute :>> helixAngle = 60.0;
						attribute :>> rotorDiameter = 120.0[SI::mm];
						attribute :>> rotorLength = 250.0[SI::mm];
					}
				}
				part :>> bearings {
					attribute :>> bearingType = "roller";
					attribute :>> loadCapacity = 5000.0[SI::N];
				}
			}

			part :>> drive {
				attribute :>> driveRatio = 2.8;
				attribute :>> efficiency = 0.92;
				part :>> drivePulley {
					attribute :>> diameter = 150.0[SI::mm];
					attribute :>> numberOfGrooves = 6;
				}
				part :>> driveBelt {
					attribute :>> width = 25.0[SI::mm];
					attribute :>> tensionForce = 800.0[SI::N];
				}
			}

			part :>> housing {
				attribute :>> material = "aluminum";
				attribute :>> wallThickness = 8.0[SI::mm];
				part :>> intakeChamber {
					attribute :>> volume = 0.5[SI::L];
				}
				part :>> dischargeChamber {
					attribute :>> volume = 0.6[SI::L];
				}
				part :>> rotorCavity {
					attribute :>> clearance = 0.1[SI::mm];
				}
			}

			part :>> seals {
				part :>> rotorSeals {
					attribute :>> sealMaterial = "PTFE";
					attribute :>> clearance = 0.05[SI::mm];
				}
				part :>> shaftSeals {
					attribute :>> sealType = "lip seal";
					attribute :>> pressureRating = 2.0[SI::bar];
				}
			}
		}

		part intercooler : Intercooler {
			attribute :>> coolingEfficiency = 0.75;
			attribute :>> heatTransferRate = 15.0[SI::kW];
		}

		part intakeManifold : IntakeManifold {
			attribute :>> volume = 3.5[SI::L];
		}

		part lubricationSystem : LubricationSystem {
			part :>> oilPump {
				attribute :>> flowRate = 5.0[SI::L];
				attribute :>> pressure = 4.0[SI::bar];
			}
			part :>> oilReservoir {
				attribute :>> capacity = 2.0[SI::L];
				attribute :>> oilLevel = 150.0[SI::mm];
			}
		}

		connect supercharger.dischargePort to intercooler.hotAirInlet;
		connect intercooler.cooledAirOutlet to intakeManifold.airInlet;
		connect intakeManifold.airInlet to engine.airIntake;
		connect engine.mechanicalOutput to supercharger.drivePort;
		connect lubricationSystem.oilSupply to supercharger.lubricationPort;
	}

	requirement def PrimaryFunctionRequirement {
		doc /* 
		The Roots supercharger system shall compress ambient air to elevated pressure
		through positive displacement using counter-rotating meshing rotors, thereby
		increasing the mass flow rate of air delivered to the engine intake manifold
		to enhance volumetric efficiency and power output.
		*/

		subject system : RootsSupercharger;

		assume constraint ambientConditions {
			system.intakePort.ambientAir.pressure >= 0.9[SI::bar] and
			system.intakePort.ambientAir.pressure <= 1.1[SI::bar] and
			system.intakePort.ambientAir.temperature >= 253.15[SI::K] and
			system.intakePort.ambientAir.temperature <= 323.15[SI::K]
		}

		require constraint boostPressureRange {
			system.dischargePort.compressedAir.pressure >= 
				system.intakePort.ambientAir.pressure + 0.3[SI::bar] and
			system.dischargePort.compressedAir.pressure <= system.maxBoostPressure
		}

		require constraint rotorSpeedLimit {
			system.rotors.maleRotor.angularVelocity <= system.maxRotorSpeed and
			system.rotors.femaleRotor.angularVelocity <= system.maxRotorSpeed
		}

		require constraint massFlowIncrease {
			system.dischargePort.compressedAir.massFlowRate >= 
				system.intakePort.ambientAir.massFlowRate * 1.5
		}
	}

	requirement def PerformanceRequirement {
		doc /* The supercharger shall provide specified boost pressure across operating range. */

		subject supercharger : RootsSupercharger;

		require constraint boostPressureRange {
			supercharger.dischargePort.compressedAir.pressure >= 0.3[SI::bar] and
			supercharger.dischargePort.compressedAir.pressure <= supercharger.maxBoostPressure
		}

		require constraint rotorSpeedLimit {
			supercharger.rotors.maleRotor.angularVelocity <= supercharger.maxRotorSpeed
		}
	}

	requirement def ReliabilityRequirement {
		doc /* The supercharger shall operate reliably under continuous load conditions. */

		subject supercharger : RootsSupercharger;

		require constraint bearingLoadCapacity {
			supercharger.rotors.bearings.loadCapacity >= 5000.0[SI::N]
		}

		require constraint sealIntegrity {
			supercharger.seals.shaftSeals.pressureRating >= 
				supercharger.maxBoostPressure * 1.5
		}
	}

	requirement def EfficiencyRequirement {
		doc /* The supercharger shall maintain minimum mechanical efficiency. */

		subject supercharger : RootsSupercharger;

		require constraint driveEfficiency {
			supercharger.drive.efficiency >= 0.85
		}
	}

	requirement <'SR-001'> superchargerSystemRequirement {
		doc /* 
		The Roots supercharger system shall compress ambient air to elevated pressure
		for forced induction, providing increased engine power output through positive
		displacement of air via counter-rotating meshing rotors.
		*/

		subject system : RootsSupercharger;

		require primaryFunction : PrimaryFunctionRequirement {
			subject system = system;
		}

		require performanceReq : PerformanceRequirement {
			subject supercharger = system;
		}

		require reliabilityReq : ReliabilityRequirement {
			subject supercharger = system;
		}

		require efficiencyReq : EfficiencyRequirement {
			subject supercharger = system;
		}
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Roots Supercharger System'::*;

    action orchestrator {
        attribute testInletPressure : PressureValue;
        attribute testInletTemperature : ThermodynamicTemperatureValue;
        action actionProbe : IntakeAir {
            in inletPressure = testInletPressure;
            in inletTemperature = testInletTemperature;
        }
        first actionProbe;
    }
}
