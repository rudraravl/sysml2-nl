package VehicleTransportSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PassengerCount :> Integer;
	attribute def CargoMass :> MassValue;
	attribute def FuelLevel :> Real;
	
	item def Passenger {
		attribute id : String;
		attribute mass :> ISQ::mass;
	}
	
	item def Cargo {
		attribute mass :> ISQ::mass;
		attribute volume :> ISQ::volume;
	}
	
	item def Fuel {
		attribute level : FuelLevel;
		attribute capacity : FuelLevel;
		attribute energyDensity :> ISQ::specificEnergy;
	}
	
	item def NavigationCommand {
		attribute targetSpeed :> ISQ::speed;
		attribute targetDirection : Real;
	}
	
	item def RouteData {
		attribute origin :> ISQ::length[3];
		attribute destination :> ISQ::length[3];
		attribute distance :> ISQ::length;
	}
	
	item def StartCommand;
	item def SlowDownCommand;
	item def AccelerateCommand;
	
	port def MechanicalPowerPort {
		attribute torque :> ISQ::torque;
		attribute angularVelocity :> ISQ::angularVelocity;
	}
	
	port def ControlSignalPort {
		attribute throttle : Real;
		attribute brake : Real;
		attribute steering : Real;
	}
	
	port def FuelFlowPort {
		attribute flowRate :> ISQ::volumeFlowRate;
	}
	
	part def Engine {
		port fuelInput : FuelFlowPort;
		port powerOutput : MechanicalPowerPort;
		attribute displacement :> ISQ::volume;
		attribute maxPower :> ISQ::power;
		attribute currentPower :> ISQ::power;
		attribute fuelConsumptionRate :> ISQ::volumeFlowRate;
	}
	
	part def Transmission {
		port powerInput : MechanicalPowerPort;
		port powerOutput : MechanicalPowerPort;
		attribute gearRatio : Real;
		attribute currentGear : Integer;
		attribute efficiency : Real;
	}
	
	part def Drivetrain {
		port powerInput : MechanicalPowerPort;
		port wheelOutput1 : MechanicalPowerPort;
		port wheelOutput2 : MechanicalPowerPort;
		attribute differentialRatio : Real;
	}
	
	part def Wheel {
		port powerInput : MechanicalPowerPort;
		attribute radius :> ISQ::length;
		attribute rotationalSpeed :> ISQ::angularVelocity;
		attribute contactForce :> ISQ::force;
	}
	
	part def FuelTank {
		attribute fuel : Fuel;
		port fuelOutput : FuelFlowPort;
		attribute capacity :> ISQ::volume;
		attribute currentLevel :> ISQ::volume;
	}
	
	part def PassengerCompartment {
		attribute maxCapacity : PassengerCount;
		attribute currentOccupancy : PassengerCount;
		ref item passengers : Passenger[*];
		attribute totalPassengerMass :> ISQ::mass;
	}
	
	part def CargoCompartment {
		attribute maxCapacity :> ISQ::mass;
		attribute maxVolume :> ISQ::volume;
		attribute currentLoad :> ISQ::mass;
		ref item cargo : Cargo[*];
	}
	
	part def NavigationSystem {
		attribute currentPosition :> ISQ::length[3];
		attribute currentVelocity :> ISQ::speed[3];
		attribute destination :> ISQ::length[3];
		attribute routeDistance :> ISQ::length;
		attribute estimatedTimeRemaining :> ISQ::time;
	}
	
	part def ControlSystem {
		port navigationInput;
		port controlOutput : ControlSignalPort;
		attribute targetSpeed :> ISQ::speed;
		attribute currentSpeed :> ISQ::speed;
	}
	
	part def Vehicle {
		attribute totalMass :> ISQ::mass;
		attribute emptyMass :> ISQ::mass;
		attribute currentSpeed :> ISQ::speed;
		attribute currentPosition :> ISQ::length[3];
		attribute maxSpeed :> ISQ::speed;
		
		part engine : Engine {
			:>> maxPower = 150.0 [kW];
			:>> displacement = 2.0 [L];
		}
		
		part transmission : Transmission {
			:>> efficiency = 0.95;
		}
		
		part drivetrain : Drivetrain {
			:>> differentialRatio = 3.73;
		}
		
		part frontLeftWheel : Wheel {
			:>> radius = 0.35 [m];
		}
		
		part frontRightWheel : Wheel {
			:>> radius = 0.35 [m];
		}
		
		part rearLeftWheel : Wheel {
			:>> radius = 0.35 [m];
		}
		
		part rearRightWheel : Wheel {
			:>> radius = 0.35 [m];
		}
		
		part fuelTank : FuelTank {
			:>> capacity = 60.0 [L];
		}
		
		part passengerCompartment : PassengerCompartment {
			:>> maxCapacity = 5;
		}
		
		part cargoCompartment : CargoCompartment {
			:>> maxCapacity = 500.0 [kg];
			:>> maxVolume = 1.5 [m^3];
		}
		
		part navigationSystem : NavigationSystem;
		
		part controlSystem : ControlSystem;
		
		port controlInterface : ControlSignalPort;
		
		connection engineToTransmission connect engine.powerOutput to transmission.powerInput;
		connection transmissionToDrivetrain connect transmission.powerOutput to drivetrain.powerInput;
		connection drivetrainToFrontLeft connect drivetrain.wheelOutput1 to frontLeftWheel.powerInput;
		connection drivetrainToFrontRight connect drivetrain.wheelOutput2 to frontRightWheel.powerInput;
		connection fuelTankToEngine connect fuelTank.fuelOutput to engine.fuelInput;
		connection navigationToControl connect navigationSystem to controlSystem.navigationInput;
		connection controlToInterface connect controlSystem.controlOutput to controlInterface;
	}
	
	requirement def PrimaryFunctionRequirement {
		doc /* The vehicle shall transport passengers and cargo from an origin location to a destination location safely and efficiently. */
		
		subject vehicle : Vehicle;
		
		require constraint passengerCapacityConstraint {
			vehicle.passengerCompartment.currentOccupancy <= vehicle.passengerCompartment.maxCapacity
		}
		
		require constraint cargoCapacityConstraint {
			vehicle.cargoCompartment.currentLoad <= vehicle.cargoCompartment.maxCapacity
		}
		
		require constraint fuelAvailabilityConstraint {
			vehicle.fuelTank.currentLevel > 0.0 [L]
		}
		
		require constraint speedLimitConstraint {
			vehicle.currentSpeed <= vehicle.maxSpeed
		}
	}
	
	requirement def SafetyRequirement {
		doc /* The vehicle shall operate within safe mass and speed limits. */
		
		subject vehicle : Vehicle;
		
		require constraint totalMassLimit {
			vehicle.totalMass <= 2500.0 [kg]
		}
		
		require constraint operationalSpeedLimit {
			vehicle.currentSpeed <= 130.0 [km/h]
		}
	}
	
	requirement def EfficiencyRequirement {
		doc /* The vehicle shall achieve minimum fuel efficiency targets. */
		
		subject vehicle : Vehicle;
		
		require constraint fuelEfficiency {
			doc /* Fuel consumption shall not exceed 8.0 L/100km under normal operation. */
		}
	}
	
	action def LoadPassengers {
		in vehicle : Vehicle;
		in passengers : Passenger[*];
		out updatedVehicle : Vehicle;
		out loadSuccess : Boolean;
	}
	
	action def LoadCargo {
		in vehicle : Vehicle;
		in cargo : Cargo[*];
		out updatedVehicle : Vehicle;
		out loadSuccess : Boolean;
	}
	
	action def PlanRoute {
		in origin :> ISQ::length[3];
		in destination :> ISQ::length[3];
		out routeData : RouteData;
		out planSuccess : Boolean;
	}
	
	action def ConsumeFuel {
		in currentFuelLevel :> ISQ::volume;
		in consumptionRate :> ISQ::volumeFlowRate;
		in duration :> ISQ::time;
		out remainingFuel :> ISQ::volume;
	}
	
	action def UpdatePosition {
		in currentPosition :> ISQ::length[3];
		in velocity :> ISQ::speed[3];
		in deltaTime :> ISQ::time;
		out newPosition :> ISQ::length[3];
	}
	
	action def CheckArrival {
		in currentPosition :> ISQ::length[3];
		in destination :> ISQ::length[3];
		in threshold :> ISQ::length;
		out arrived : Boolean;
	}
	
	action def TransportPayload {
		doc /* Primary vehicle function: Transport passengers and cargo from origin to destination. */
		
		in originLocation :> ISQ::length[3];
		in destinationLocation :> ISQ::length[3];
		in passengers : Passenger[*];
		in cargo : Cargo[*];
		out deliverySuccess : Boolean;
		out finalPosition :> ISQ::length[3];
		
		first start;
		
		then action loadPassengers : LoadPassengers {
			in vehicle;
			in passengers = TransportPayload::passengers;
			out updatedVehicle;
			out loadSuccess;
		}
		
		then action loadCargo : LoadCargo {
			in vehicle = loadPassengers.updatedVehicle;
			in cargo = TransportPayload::cargo;
			out updatedVehicle;
			out loadSuccess;
		}
		
		then action planRoute : PlanRoute {
			in origin = originLocation;
			in destination = destinationLocation;
			out routeData;
			out planSuccess;
		}
		
		then merge travelLoop;
		
		then action checkArrival : CheckArrival {
			in currentPosition;
			in destination = destinationLocation;
			in threshold = 10.0 [m];
			out arrived;
		}
		
		then decide;
			if checkArrival.arrived then unloadPayload;
			if not checkArrival.arrived then continueTravel;
		
		action continueTravel {
			action consumeFuel : ConsumeFuel {
				in currentFuelLevel;
				in consumptionRate;
				in duration = 1.0 [s];
				out remainingFuel;
			}
			
			then action updatePosition : UpdatePosition {
				in currentPosition;
				in velocity;
				in deltaTime = 1.0 [s];
				out newPosition;
			}
		}
		then travelLoop;
		
		action unloadPayload {
			action unloadPassengers;
			then action unloadCargo;
		}
		
		then assign deliverySuccess := true;
		then assign finalPosition := checkArrival.currentPosition;
		then done;
	}
	
	state def VehicleOperationalStates {
		entry; then parked;
		
		state parked {
			entry assign vehicle.currentSpeed := 0.0 [km/h];
		}
		
		transition parked_to_starting
			first parked
			accept startCmd : StartCommand
			then starting;
		
		state starting {
			entry action startEngine;
		}
		
		transition starting_to_accelerating
			first starting
			if vehicle.engine.currentPower > 0.0 [W]
			then accelerating;
		
		state accelerating {
			entry action increaseThrottle;
			do action monitorSpeed;
		}
		
		transition accelerating_to_cruising
			first accelerating
			if vehicle.currentSpeed >= vehicle.controlSystem.targetSpeed
			then cruising;
		
		state cruising {
			entry action maintainSpeed;
			do action monitorRoute;
		}
		
		transition cruising_to_decelerating
			first cruising
			accept slowCmd : SlowDownCommand
			then decelerating;
		
		state decelerating {
			entry action applyBrakes;
		}
		
		transition decelerating_to_parked
			first decelerating
			if vehicle.currentSpeed == 0.0 [km/h]
			then parked;
		
		transition cruising_to_accelerating
			first cruising
			accept accelCmd : AccelerateCommand
			then accelerating;
	}
	
	requirement vehicleTransportMission {
		doc /* The vehicle shall successfully transport payload from origin to destination while satisfying all operational constraints. */
		
		subject vehicle : Vehicle;
		
		assume constraint validRoute {
			doc /* Origin and destination must be defined and reachable. */
		}
		
		assume constraint sufficientFuel {
			vehicle.fuelTank.currentLevel >= 5.0 [L]
		}
		
		require constraint primaryFunctionSatisfied {
			doc /* Primary function requirement must be satisfied. */
		}
		
		require constraint safetySatisfied {
			doc /* Safety requirement must be satisfied. */
		}
		
		require constraint efficiencySatisfied {
			doc /* Efficiency requirement must be satisfied. */
		}
	}
	
	part operationalVehicle : Vehicle {
		:>> totalMass = 1800.0 [kg];
		:>> emptyMass = 1500.0 [kg];
		:>> currentSpeed = 0.0 [km/h];
		:>> maxSpeed = 180.0 [km/h];
		:>> currentPosition = (0.0, 0.0, 0.0) [m];
		
		part :>> passengerCompartment {
			:>> currentOccupancy = 0;
		}
		
		part :>> cargoCompartment {
			:>> currentLoad = 0.0 [kg];
		}
		
		part :>> fuelTank {
			:>> currentLevel = 50.0 [L];
			attribute :>> fuel {
				:>> level = 50.0;
				:>> capacity = 60.0;
				:>> energyDensity = 34.2 [MJ/L];
			}
		}
		
		part :>> navigationSystem {
			:>> currentPosition = (0.0, 0.0, 0.0) [m];
			:>> destination = (100000.0, 50000.0, 0.0) [m];
		}
	}
	
	action transportMission : TransportPayload {
		in originLocation = (0.0, 0.0, 0.0) [m];
		in destinationLocation = (100000.0, 50000.0, 0.0) [m];
		in passengers : Passenger[3];
		in cargo : Cargo[2];
		out deliverySuccess;
		out finalPosition;
	}
}
