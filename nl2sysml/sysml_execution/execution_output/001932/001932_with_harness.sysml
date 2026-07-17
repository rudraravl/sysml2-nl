package SpaceflightSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def MissionPhase;
	attribute def TelemetryPacket;
	attribute def GroundCommand;
	attribute def NavigationSolution;
	
	attribute def OrbitalAltitude :> ISQ::length;
	attribute def OrbitalVelocity :> ISQ::speed;
	attribute def PropellantMass :> ISQ::mass;
	attribute def ThrustLevel :> ISQ::force;
	attribute def SpecificImpulse :> ISQ::time;
	attribute def DeltaVelocity :> ISQ::speed;
	attribute def BatteryCharge :> Real;
	
	port def CommunicationPort {
		in item uplinkCommand : GroundCommand;
		out item downlinkTelemetry : TelemetryPacket;
	}
	
	port def PowerBusPort {
		out item voltage : ISQ::electricPotential;
		out item current : ISQ::electricCurrent;
		in item powerDemand : ISQ::power;
	}
	
	port def ThrustPort {
		in item commandedThrust : ThrustLevel;
		out item actualThrust : ThrustLevel;
		out item propellantRemaining : PropellantMass;
	}
	
	part def ElectricalPowerSubsystem {
		port powerBus : PowerBusPort;
		attribute solarArrayArea : ISQ::area;
		attribute batteryCapacity : ISQ::energy;
		attribute currentBatteryCharge : BatteryCharge;
		attribute totalPowerGenerated : ISQ::power;
		
		action def GenerateSolarPower {
			in sunAngle : Real;
			in arrayArea : ISQ::area;
			out powerOutput : ISQ::power;
		}
		
		action def ManageBattery {
			in powerGenerated : ISQ::power;
			in powerConsumed : ISQ::power;
			in currentCharge : BatteryCharge;
			out newCharge : BatteryCharge;
		}
	}
	
	part def CommunicationsSubsystem {
		port commLink : CommunicationPort;
		attribute transmitterPower : ISQ::power;
		attribute antennaGain : Real;
		attribute linkMargin : Real;
		attribute dataRateKbps : Real;
		
		action def TransmitTelemetry {
			in telemetryData : TelemetryPacket;
			in linkQuality : Real;
			out transmitSuccess : Boolean;
		}
		
		action def ReceiveCommand {
			out receivedCommand : GroundCommand;
			out commandValid : Boolean;
		}
	}
	
	part def GuidanceNavigationControlSubsystem {
		attribute currentPosition : ISQ::length[3];
		attribute currentVelocity : ISQ::speed[3];
		attribute currentAttitude : Real[3];
		attribute targetOrbit : OrbitalAltitude;
		
		action def DeterminePosition {
			in sensorData : NavigationSolution;
			out position : ISQ::length[3];
			out velocity : ISQ::speed[3];
		}
		
		action def ComputeManeuver {
			in currentOrbit : OrbitalAltitude;
			in targetOrbit : OrbitalAltitude;
			in availableDeltaV : DeltaVelocity;
			out requiredThrust : ThrustLevel;
			out burnDuration : ISQ::time;
		}
		
		action def ControlAttitude {
			in desiredAttitude : Real[3];
			in currentAttitude : Real[3];
			out thrusterCommands : ThrustLevel;
		}
	}
	
	part def PropulsionSubsystem {
		port thrustControl : ThrustPort;
		attribute maxThrust : ThrustLevel;
		attribute totalPropellantMass : PropellantMass;
		attribute remainingPropellant : PropellantMass;
		attribute specificImpulse : SpecificImpulse;
		
		action def ExecuteBurn {
			in commandedThrust : ThrustLevel;
			in burnDuration : ISQ::time;
			in availablePropellant : PropellantMass;
			out thrustDelivered : ThrustLevel;
			out propellantConsumed : PropellantMass;
			out deltaVAchieved : DeltaVelocity;
		}
	}
	
	part def PayloadSubsystem {
		attribute payloadMass : ISQ::mass;
		attribute operatingPower : ISQ::power;
		attribute dataGenerationRate : Real;
		
		action def PerformMission {
			in missionPhase : MissionPhase;
			out missionData : TelemetryPacket;
			out missionComplete : Boolean;
		}
	}
	
	requirement def SpaceflightMissionRequirements {
		doc /* The spaceflight system shall execute a complete orbital mission from launch through payload deployment and operations. */
		
		requirement <'SYS-001'> achieveTargetOrbit {
			doc /* The spacecraft shall achieve and maintain the target orbital altitude with specified accuracy. */
			attribute targetAltitude : OrbitalAltitude;
			attribute altitudeTolerance : ISQ::length;
		}
		
		requirement <'SYS-002'> provideSufficientDeltaV {
			doc /* The propulsion subsystem shall provide sufficient delta-V for all mission maneuvers. */
			attribute minimumDeltaV : DeltaVelocity;
		}
		
		requirement <'SYS-003'> maintainCommunications {
			doc /* The spacecraft shall maintain reliable communication with ground stations throughout the mission. */
			attribute minimumLinkMargin : Real;
		}
		
		requirement <'SYS-004'> sustainPowerGeneration {
			doc /* The electrical power subsystem shall generate and store sufficient power for all mission phases. */
			attribute minimumPowerLevel : ISQ::power;
		}
		
		requirement <'SYS-005'> completeMissionObjectives {
			doc /* The payload subsystem shall successfully complete all mission objectives. */
		}
	}
	
	action def LaunchPhase {
		in launchVehicleSeparation : Boolean;
		out initialOrbitAchieved : Boolean;
	}
	
	action def OrbitRaisingPhase {
		in currentAltitude : OrbitalAltitude;
		in targetAltitude : OrbitalAltitude;
		in availablePropellant : PropellantMass;
		out finalOrbitAchieved : Boolean;
		out propellantUsed : PropellantMass;
	}
	
	action def OnOrbitOperations {
		in missionDuration : ISQ::time;
		in payloadActive : Boolean;
		out operationsComplete : Boolean;
	}
	
	action def ExecuteSpaceflightMission {
		doc /* 
		Primary mission execution sequence coordinating all spacecraft subsystems
		to achieve orbital insertion, perform on-orbit operations, and complete mission objectives.
		*/
		
		in missionStartCommand : GroundCommand;
		in targetOrbitAltitude : OrbitalAltitude;
		in missionDuration : ISQ::time;
		out missionSuccess : Boolean;
		
		private attribute orbitAchieved : Boolean := false;
		private attribute payloadDeployed : Boolean := false;
		private attribute operationsComplete : Boolean := false;
		
		first start;
		then accept missionStart : GroundCommand;
		
		then action launch : LaunchPhase {
			in launchVehicleSeparation = true;
			out initialOrbitAchieved;
		}
		
		then action orbitRaising : OrbitRaisingPhase {
			in currentAltitude = 200.0 [km];
			in targetAltitude = targetOrbitAltitude;
			in availablePropellant = 150.0 [kg];
			out finalOrbitAchieved;
			out propellantUsed;
		}
		
		then assign orbitAchieved := orbitRaising.finalOrbitAchieved;
		
		then decide;
			if orbitAchieved then deployPayload;
			if not orbitAchieved then abortMission;
		
		action deployPayload {
			then assign payloadDeployed := true;
			then operations;
		}
		
		action operations : OnOrbitOperations {
			in missionDuration = ExecuteSpaceflightMission::missionDuration;
			in payloadActive = payloadDeployed;
			out operationsComplete;
		}
		then assign operationsComplete := operations.operationsComplete;
		
		then decide;
			if operationsComplete then missionComplete;
			if not operationsComplete then extendMission;
		
		action extendMission {
			then operations;
		}
		
		action abortMission {
			then assign missionSuccess := false;
			then done;
		}
		
		action missionComplete {
			then assign missionSuccess := true;
			then done;
		}
	}
	
	part def Spacecraft {
		doc /* 
		The spacecraft is an autonomous orbital vehicle designed to execute a complete spaceflight mission.
		Its primary function is to achieve a designated orbit, deploy and operate a scientific or commercial payload,
		and maintain continuous communication with ground control while managing all onboard systems including
		power generation, propulsion, navigation, and attitude control throughout the mission lifecycle.
		*/
		
		attribute dryMass : ISQ::mass;
		attribute totalMass : ISQ::mass;
		attribute missionLifetime : ISQ::time;
		
		perform action primaryMission : ExecuteSpaceflightMission;
		
		part eps : ElectricalPowerSubsystem {
			:>> solarArrayArea = 12.0 [m^2];
			:>> batteryCapacity = 400.0 [W*h];
			:>> currentBatteryCharge = 100.0;
			:>> totalPowerGenerated = 750.0 [W];
			
			perform action generatePower : GenerateSolarPower;
			perform action manageBattery : ManageBattery;
		}
		
		part comms : CommunicationsSubsystem {
			:>> transmitterPower = 40.0 [W];
			:>> antennaGain = 22.0;
			:>> linkMargin = 3.5;
			:>> dataRateKbps = 500.0;
			
			perform action transmit : TransmitTelemetry;
			perform action receive : ReceiveCommand;
		}
		
		part gnc : GuidanceNavigationControlSubsystem {
			:>> targetOrbit = 550.0 [km];
			
			perform action determinePosition : DeterminePosition;
			perform action computeManeuver : ComputeManeuver;
			perform action controlAttitude : ControlAttitude;
		}
		
		part propulsion : PropulsionSubsystem {
			:>> maxThrust = 450.0 [N];
			:>> totalPropellantMass = 180.0 [kg];
			:>> remainingPropellant = 180.0 [kg];
			:>> specificImpulse = 320.0 [s];
			
			perform action executeBurn : ExecuteBurn;
		}
		
		part payload : PayloadSubsystem {
			:>> payloadMass = 75.0 [kg];
			:>> operatingPower = 120.0 [W];
			:>> dataGenerationRate = 100.0;
			
			perform action performMission : PerformMission;
		}
		
		connection powerToComms connect eps.powerBus to comms.commLink;
		connection powerToGNC connect eps.powerBus to gnc;
		connection powerToPropulsion connect eps.powerBus to propulsion.thrustControl;
		connection powerToPayload connect eps.powerBus to payload;
		connection gncToPropulsion connect gnc to propulsion.thrustControl;
		connection commsToGround connect comms.commLink to groundControl.groundLink;
	}
	
	part groundControl {
		port groundLink : CommunicationPort;
		
		action def SendMissionCommands {
			out commands : GroundCommand;
		}
		
		action def ProcessTelemetry {
			in telemetry : TelemetryPacket;
			out missionStatus : Boolean;
		}
		
		perform action sendCommands : SendMissionCommands;
		perform action processTelemetry : ProcessTelemetry;
	}
	
	part orbitalVehicle : Spacecraft {
		:>> dryMass = 450.0 [kg];
		:>> totalMass = 630.0 [kg];
		:>> missionLifetime = 31536000.0 [s];
		
		perform primaryMission {
			in missionStartCommand;
			in targetOrbitAltitude = 550.0 [km];
			in missionDuration = 31536000.0 [s];
			out missionSuccess;
		}
	}
	
	requirement missionRequirements : SpaceflightMissionRequirements {
		require achieveTargetOrbit {
			:>> targetAltitude = 550.0 [km];
			:>> altitudeTolerance = 5.0 [km];
		}
		require provideSufficientDeltaV {
			:>> minimumDeltaV = 3500.0 [m/s];
		}
		require maintainCommunications {
			:>> minimumLinkMargin = 3.0;
		}
		require sustainPowerGeneration {
			:>> minimumPowerLevel = 600.0 [W];
		}
		require completeMissionObjectives;
	}
	
	satisfy missionRequirements.achieveTargetOrbit by orbitalVehicle.gnc;
	satisfy missionRequirements.provideSufficientDeltaV by orbitalVehicle.propulsion;
	satisfy missionRequirements.maintainCommunications by orbitalVehicle.comms;
	satisfy missionRequirements.sustainPowerGeneration by orbitalVehicle.eps;
	satisfy missionRequirements.completeMissionObjectives by orbitalVehicle.payload;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SpaceflightSystem::*;

    action orchestrator {
        attribute testMissionDuration : ISQ::time;
        action operationsProbe : OnOrbitOperations {
            in missionDuration = testMissionDuration;
            in payloadActive = false;
        }
        first operationsProbe;
    }
}
