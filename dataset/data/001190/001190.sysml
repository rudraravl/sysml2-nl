package 'Pickup Truck System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ThrottleCommand;
	attribute def BrakeCommand;
	attribute def SteeringCommand;
	attribute def IgnitionCommand;
	
	item def Cargo {
		attribute mass :> ISQ::mass;
		attribute volume :> ISQ::volume;
		attribute description : String;
	}
	
	port def MechanicalPowerPort {
		attribute torque :> ISQ::torque;
		attribute rotationalSpeed : Real;
	}
	
	port def ControlSignalPort {
		attribute throttle : ThrottleCommand;
		attribute brake : BrakeCommand;
	}
	
	part def Engine {
		attribute displacement :> ISQ::volume;
		attribute maxPower :> ISQ::power;
		attribute currentRPM : Real;
		port crankshaft : MechanicalPowerPort;
		port controlInput : ControlSignalPort;
		port fuelSupply;
		
		action def ProduceTorque {
			in throttleLevel : Real;
			in rpm : Real;
			out engineTorque :> ISQ::torque;
		}
	}
	
	part def Transmission {
		attribute gearRatios : Real[*];
		attribute currentGear : Integer;
		port inputShaft : MechanicalPowerPort;
		port outputShaft : MechanicalPowerPort;
		
		action def TransferPower {
			in inputTorque :> ISQ::torque;
			in gearRatio : Real;
			out outputTorque :> ISQ::torque;
		}
	}
	
	part def Driveshaft {
		port powerInput : MechanicalPowerPort;
		port powerOutput : MechanicalPowerPort;
	}
	
	part def DifferentialAssembly {
		port driveInput : MechanicalPowerPort;
		port leftAxle : MechanicalPowerPort;
		port rightAxle : MechanicalPowerPort;
		
		action def DistributePower {
			in inputTorque :> ISQ::torque;
			out leftTorque :> ISQ::torque;
			out rightTorque :> ISQ::torque;
		}
	}
	
	part def Wheel {
		attribute diameter :> ISQ::length;
		attribute tirePressure :> ISQ::pressure;
		port axleInput : MechanicalPowerPort;
	}
	
	part def CargoBed {
		attribute bedLength :> ISQ::length;
		attribute bedWidth :> ISQ::length;
		attribute bedDepth :> ISQ::length;
		attribute maxPayloadCapacity :> ISQ::mass;
		attribute currentLoad :> ISQ::mass;
		item loadedCargo : Cargo[0..*];
	}
	
	part def FuelSystem {
		attribute tankCapacity :> ISQ::volume;
		attribute currentFuelLevel :> ISQ::volume;
		port fuelDelivery;
	}
	
	part def Chassis {
		attribute frameStrength :> ISQ::force;
		attribute grossVehicleWeightRating :> ISQ::mass;
	}
	
	part def Cabin {
		attribute passengerCapacity : Integer;
		port driverControls;
	}
	
	part def PickupTruck {
		attribute curbWeight :> ISQ::mass;
		attribute totalWeight :> ISQ::mass;
		
		part engine : Engine {
			attribute displacement = 5.0 [L];
			attribute maxPower = 298 [kW];
			attribute currentRPM = 0.0;
		}
		
		part transmission : Transmission {
			attribute gearRatios = (3.2, 2.1, 1.4, 1.0, 0.75, 0.62);
			attribute currentGear = 1;
		}
		
		part driveshaft : Driveshaft;
		
		part rearDifferential : DifferentialAssembly;
		
		part rearLeftWheel : Wheel {
			attribute diameter = 0.82 [m];
			attribute tirePressure = 240000 [Pa];
		}
		
		part rearRightWheel : Wheel {
			attribute diameter = 0.82 [m];
			attribute tirePressure = 240000 [Pa];
		}
		
		part frontLeftWheel : Wheel {
			attribute diameter = 0.82 [m];
			attribute tirePressure = 240000 [Pa];
		}
		
		part frontRightWheel : Wheel {
			attribute diameter = 0.82 [m];
			attribute tirePressure = 240000 [Pa];
		}
		
		part cargoBed : CargoBed {
			attribute bedLength = 2.4 [m];
			attribute bedWidth = 1.6 [m];
			attribute bedDepth = 0.55 [m];
			attribute maxPayloadCapacity = 1200 [kg];
			attribute currentLoad = 0 [kg];
		}
		
		part fuelSystem : FuelSystem {
			attribute tankCapacity = 110 [L];
			attribute currentFuelLevel = 85 [L];
		}
		
		part chassis : Chassis {
			attribute frameStrength = 60000 [N];
			attribute grossVehicleWeightRating = 3500 [kg];
		}
		
		part cabin : Cabin {
			attribute passengerCapacity = 5;
		}
		
		connect engine.crankshaft to transmission.inputShaft;
		connect transmission.outputShaft to driveshaft.powerInput;
		connect driveshaft.powerOutput to rearDifferential.driveInput;
		connect rearDifferential.leftAxle to rearLeftWheel.axleInput;
		connect rearDifferential.rightAxle to rearRightWheel.axleInput;
		connect fuelSystem.fuelDelivery to engine.fuelSupply;
		
		perform action primaryMission;
	}
	
	action def LoadCargoAction {
		in cargoItem : Cargo;
		in availableCapacity :> ISQ::mass;
		in currentLoad :> ISQ::mass;
		out loadSuccessful : Boolean;
		out updatedLoad :> ISQ::mass;
	}
	
	action def UnloadCargoAction {
		in cargoItem : Cargo;
		in currentLoad :> ISQ::mass;
		out unloadSuccessful : Boolean;
		out updatedLoad :> ISQ::mass;
	}
	
	action def GenerateDrivingPower {
		in throttleInput : ThrottleCommand;
		in currentGear : Integer;
		in fuelAvailable :> ISQ::volume;
		out driveTorque :> ISQ::torque;
		
		first start;
		then action produceTorque {
			doc /* Engine produces torque based on throttle input */
		}
		then action amplifyTorque {
			doc /* Transmission amplifies torque based on gear ratio */
		}
		then action transferTorque {
			doc /* Driveshaft transfers torque to differential */
		}
		then action distributeTorque {
			doc /* Differential distributes torque to rear wheels */
		}
		then done;
	}
	
	action def TransportPayload {
		in originLocation : String;
		in destinationLocation : String;
		in payload : Cargo;
		out missionComplete : Boolean;
		private attribute atDestination : Boolean;
		
		first start;
		then action loadCargo : LoadCargoAction {
			in cargoItem = payload;
			in availableCapacity = 1200 [kg];
			in currentLoad = 0 [kg];
		}
		then decide;
			if loadCargo.loadSuccessful then proceedToDrive;
			else abortMissionAction;
		
		action proceedToDrive {
			then driveToDestination;
		}
		
		action driveToDestination {
			first merge loopStart;
			then action generatePower : GenerateDrivingPower {
				in throttleInput;
				in currentGear = 3;
				in fuelAvailable = 85 [L];
			}
			then action monitorProgress {
				then assign atDestination := true;
			}
			then decide;
				if atDestination then exitLoop;
				else loopStart;
			action exitLoop;
			then unloadCargoAction;
		}
		
		action unloadCargoAction : UnloadCargoAction {
			in cargoItem = payload;
			in currentLoad = payload.mass;
		}
		then action completeMission {
			then assign missionComplete := true;
		}
		then done;
		
		action abortMissionAction {
			then assign missionComplete := false;
			then done;
		}
	}
	
	action primaryMission : TransportPayload {
		in originLocation = "Distribution Center";
		in destinationLocation = "Construction Site";
		in payload : Cargo {
			mass = 950 [kg];
			volume = 3.2 [m^3];
			description = "Building Materials";
		}
		out missionComplete;
	}
	
	requirement def PayloadCapabilityRequirement {
		doc /* The pickup truck shall be capable of transporting cargo within specified mass and volume limits. */
		
		attribute requiredPayloadMass :> ISQ::mass;
		attribute requiredPayloadVolume :> ISQ::volume;
	}
	
	requirement def PowertrainPerformanceRequirement {
		doc /* The pickup truck powertrain shall deliver sufficient power for cargo transport operations. */
		
		attribute minimumPower :> ISQ::power;
	}
	
	requirement def StructuralIntegrityRequirement {
		doc /* The pickup truck chassis shall support the combined weight of vehicle and payload. */
		
		attribute minimumGVWR :> ISQ::mass;
	}
	
	requirement <'REQ-001'> payloadCapability : PayloadCapabilityRequirement {
		attribute requiredPayloadMass = 1200 [kg];
		attribute requiredPayloadVolume = 4.0 [m^3];
		
		subject truck : PickupTruck;
		
		require constraint {
			truck.cargoBed.maxPayloadCapacity >= requiredPayloadMass
		}
		
		require constraint {
			truck.cargoBed.bedLength * truck.cargoBed.bedWidth * truck.cargoBed.bedDepth >= requiredPayloadVolume
		}
	}
	
	requirement <'REQ-002'> powertrainPerformance : PowertrainPerformanceRequirement {
		attribute minimumPower = 250 [kW];
		
		subject truck : PickupTruck;
		
		require constraint {
			truck.engine.maxPower >= minimumPower
		}
	}
	
	requirement <'REQ-003'> structuralIntegrity : StructuralIntegrityRequirement {
		attribute minimumGVWR = 3500 [kg];
		
		subject truck : PickupTruck;
		
		require constraint {
			truck.chassis.grossVehicleWeightRating >= minimumGVWR
		}
	}
	
	requirement <'REQ-PRIMARY'> primaryFunctionRequirement {
		doc /* The primary function of the Pickup Truck system is to transport cargo and materials from an origin location to a destination location, utilizing its cargo bed to carry payloads while providing mobility through its powertrain system. */
		
		subject missionTruck : PickupTruck;
		
		require payloadCapability;
		require powertrainPerformance;
		require structuralIntegrity;
		
		require constraint {
			doc /* The pickup truck shall successfully complete transport payload missions. */
			missionTruck.primaryMission.missionComplete == true
		}
	}
}
