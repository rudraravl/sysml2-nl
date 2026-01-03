package 'JPL Interplanetary Spacecraft System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def NavigationState {
		attribute position : LengthValue[3];
		attribute velocity : SpeedValue[3];
		attribute attitude : Real[3];
	}
	
	attribute def ScienceObservation {
		attribute timestamp : TimeValue;
		attribute instrumentId : String;
		attribute dataVolume : Real;
		attribute targetBody : String;
	}
	
	attribute def TrajectoryManeuver {
		attribute deltaV : SpeedValue;
		attribute burnDuration : TimeValue;
		attribute thrustDirection : Real[3];
	}
	
	item def PowerBus {
		attribute voltage : Real;
		attribute current : ElectricCurrentValue;
	}
	
	item def DataBus {
		attribute bandwidth : Real;
		attribute protocol : String;
	}
	
	item def TelemetryPacket {
		attribute sequenceNumber : Integer;
		attribute timestamp : TimeValue;
		attribute healthStatus : String;
		attribute scienceData : ScienceObservation[*];
	}
	
	item def CommandPacket {
		attribute commandId : Integer;
		attribute priority : Integer;
		attribute executionTime : TimeValue;
		attribute parameters : Real[*];
	}
	
	port def PowerPort {
		out item power : PowerBus;
	}
	
	port def DataPort {
		in item commands : CommandPacket;
		out item telemetry : TelemetryPacket;
	}
	
	port def InternalBusPort {
		inout item data : DataBus;
	}
	
	part def SolarArrayAssembly {
		attribute totalArea : AreaValue;
		attribute efficiency : Real;
		attribute outputPower : PowerValue;
		
		port powerOut : PowerPort;
		
		part solarPanel1 {
			attribute panelArea : AreaValue;
		}
		
		part solarPanel2 {
			attribute panelArea : AreaValue;
		}
		
		part deploymentMechanism {
			attribute deploymentAngle : Real;
		}
	}
	
	part def BatterySystem {
		attribute capacity : Real;
		attribute stateOfCharge : Real;
		attribute cellCount : Integer;
		
		port powerOut : PowerPort;
		port powerIn : PowerPort;
	}
	
	part def PowerDistributionUnit {
		attribute regulatedVoltage : Real;
		
		port solarInput : PowerPort;
		port batteryInput : PowerPort;
		port batteryOutput : PowerPort;
		port systemPower1 : PowerPort;
		port systemPower2 : PowerPort;
		port systemPower3 : PowerPort;
		port systemPower4 : PowerPort;
	}
	
	part def PropulsionSystem {
		attribute fuelMass : MassValue;
		attribute oxidizerMass : MassValue;
		attribute specificImpulse : Real;
		attribute maxThrust : ForceValue;
		
		port powerIn : PowerPort;
		port controlBus : InternalBusPort;
		
		part mainEngine {
			attribute thrustLevel : ForceValue;
		}
		
		part reactionControlThrusters {
			attribute thrusterCount : Integer;
		}
		
		part fuelTank {
			attribute volume : VolumeValue;
		}
		
		part oxidizerTank {
			attribute volume : VolumeValue;
		}
	}
	
	part def GuidanceNavigationControl {
		attribute navigationAccuracy : LengthValue;
		attribute attitudeAccuracy : Real;
		
		port powerIn : PowerPort;
		port dataBus : InternalBusPort;
		
		part starTracker {
			attribute fieldOfView : Real;
		}
		
		part inertialMeasurementUnit {
			attribute gyroAccuracy : Real;
		}
		
		part sunSensor {
			attribute accuracy : Real;
		}
		
		part flightComputer {
			attribute processingPower : Real;
			attribute memoryCapacity : Real;
		}
	}
	
	part def CommunicationsSubsystem {
		attribute transmitPower : PowerValue;
		attribute antennaGain : Real;
		attribute dataRate : Real;
		
		port powerIn : PowerPort;
		port dataBus : InternalBusPort;
		port rfInterface : DataPort;
		
		part highGainAntenna {
			attribute diameter : LengthValue;
			attribute pointingAccuracy : Real;
		}
		
		part lowGainAntenna {
			attribute beamWidth : Real;
		}
		
		part transponder {
			attribute frequency : FrequencyValue;
		}
		
		part transmitter {
			attribute outputPower : PowerValue;
		}
		
		part receiver {
			attribute sensitivity : Real;
		}
	}
	
	part def ScienceInstrumentSuite {
		attribute totalMass : MassValue;
		attribute powerConsumption : PowerValue;
		
		port powerIn : PowerPort;
		port dataBus : InternalBusPort;
		
		part imagingSpectrometer {
			attribute spectralRange : Real[2];
			attribute resolution : LengthValue;
		}
		
		part infraredCamera {
			attribute detectorSize : Integer[2];
			attribute thermalSensitivity : TemperatureValue;
		}
		
		part magnetometer {
			attribute sensitivity : Real;
		}
		
		part particleDetector {
			attribute energyRange : Real[2];
		}
	}
	
	part def CommandDataHandling {
		attribute storageCapacity : Real;
		attribute processingRate : Real;
		
		port powerIn : PowerPort;
		port dataBus : InternalBusPort;
		
		part mainProcessor {
			attribute clockSpeed : FrequencyValue;
		}
		
		part solidStateRecorder {
			attribute capacity : Real;
		}
		
		part dataCompressor {
			attribute compressionRatio : Real;
		}
	}
	
	part def ThermalControlSystem {
		attribute operatingTemperature : TemperatureValue;
		
		port powerIn : PowerPort;
		
		part radiators {
			attribute surfaceArea : AreaValue;
		}
		
		part heaters {
			attribute heaterPower : PowerValue;
		}
		
		part multiLayerInsulation {
			attribute layers : Integer;
		}
	}
	
	action def ExecuteTrajectoryCorrection {
		in currentState : NavigationState;
		in targetState : NavigationState;
		out maneuver : TrajectoryManeuver;
		out fuelConsumed : MassValue;
	}
	
	action def AcquireScienceData {
		in targetBody : String;
		in observationDuration : TimeValue;
		out observations : ScienceObservation[*];
		out dataVolume : Real;
	}
	
	action def TransmitToEarth {
		in telemetryData : TelemetryPacket[*];
		in transmitDuration : TimeValue;
		out dataSent : Real;
		out linkQuality : Real;
	}
	
	action def ReceiveCommands {
		in acquisitionWindow : TimeValue;
		out commands : CommandPacket[*];
		out commandsReceived : Integer;
	}
	
	action def ManagePower {
		in solarPower : PowerValue;
		in batteryCharge : Real;
		in loadDemand : PowerValue;
		out powerMode : String;
	}
	
	action def InterplanetaryMissionOperation {
		in missionPhase : String;
		in targetPlanet : String;
		out missionData : ScienceObservation[*];
		out healthTelemetry : TelemetryPacket[*];
		
		first start;
		then merge missionLoop;
		
		action receiveGroundCommands : ReceiveCommands {
			in acquisitionWindow = 3600.0[s];
			out commands;
			out commandsReceived;
		}
		
		then decide;
			if receiveGroundCommands.commandsReceived > 0 then processCommands;
			else continueNominal;
		
		action processCommands {
			then continueNominal;
		}
		
		action continueNominal {
			action managePowerSystem : ManagePower {
				in solarPower;
				in batteryCharge;
				in loadDemand;
				out powerMode;
			}
			
			then action navigation {
				action determinePosition;
				then decide;
					if correctionNeeded then executeCorrection;
					else maintainCourse;
				
				action executeCorrection : ExecuteTrajectoryCorrection {
					in currentState;
					in targetState;
					out maneuver;
					out fuelConsumed;
				}
				
				action maintainCourse;
			}
			
			then action scienceOperations {
				action collectData : AcquireScienceData {
					in targetBody = targetPlanet;
					in observationDuration = 7200.0[s];
					out observations;
					out dataVolume;
				}
				
				then assign missionData := missionData->including(collectData.observations);
			}
			
			then action transmitData : TransmitToEarth {
				in telemetryData;
				in transmitDuration = 1800.0[s];
				out dataSent;
				out linkQuality;
			}
		}
		
		then missionLoop;
		
		attribute correctionNeeded : Boolean;
		attribute currentState : NavigationState;
		attribute targetState : NavigationState;
		attribute solarPower : PowerValue;
		attribute batteryCharge : Real;
		attribute loadDemand : PowerValue;
		attribute telemetryData : TelemetryPacket[*];
	}
	
	state def SpacecraftOperationalStates {
		entry; then launch;
		
		state launch {
			entry assign mode = "Launch";
		}
		
		transition launch_to_cruise
			first launch
			accept separationEvent
			then cruise;
		
		state cruise {
			entry assign mode = "Cruise";
			do action cruiseOps : InterplanetaryMissionOperation;
		}
		
		transition cruise_to_approach
			first cruise
			if distanceToTarget < 1000000.0
			then approach;
		
		state approach {
			entry assign mode = "Approach";
			do action approachOps : InterplanetaryMissionOperation;
		}
		
		transition approach_to_orbit
			first approach
			accept orbitInsertionComplete
			then orbit;
		
		state orbit {
			entry assign mode = "Orbital Operations";
			do action orbitalOps : InterplanetaryMissionOperation;
		}
		
		state parallel safeMode {
			entry assign mode = "Safe Mode";
			
			state powerSafe {
				entry assign powerStatus = "Minimum Load";
			}
			
			state commsSafe {
				entry assign commsStatus = "Low Gain Only";
			}
			
			state attitudeSafe {
				entry assign attitudeStatus = "Sun Pointing";
			}
		}
		
		transition any_to_safe
			accept anomalyDetected
			then safeMode;
		
		transition safe_to_cruise
			first safeMode
			accept recoveryComplete
			then cruise;
		
		attribute mode : String;
		attribute distanceToTarget : Real;
		attribute powerStatus : String;
		attribute commsStatus : String;
		attribute attitudeStatus : String;
		event separationEvent;
		event orbitInsertionComplete;
		event anomalyDetected;
		event recoveryComplete;
	}
	
	requirement def InterplanetaryMissionRequirements {
		doc /* The interplanetary spacecraft system shall conduct scientific 
		       exploration of planetary bodies in the solar system and transmit 
		       findings to Earth. */
		
		requirement missionDurationRequirement {
			doc /* The spacecraft shall operate for a minimum mission duration 
			       of 5 years in the deep space environment. */
		}
		
		requirement scienceDataRequirement {
			doc /* The spacecraft shall collect and return a minimum of 500 GB 
			       of science data over the primary mission. */
			
			subject instruments : ScienceInstrumentSuite;
			
			require constraint {
				instruments.totalMass.num <= 150.0
			}
		}
		
		requirement communicationRequirement {
			doc /* The spacecraft shall maintain communication with Earth at 
			       distances up to 5 AU with data rates of at least 1 kbps. */
			
			subject comms : CommunicationsSubsystem;
			
			require constraint {
				comms.dataRate >= 1000.0
			}
		}
		
		requirement navigationRequirement {
			doc /* The spacecraft shall determine its position with accuracy 
			       better than 100 km and attitude better than 0.1 degrees. */
			
			subject gnc : GuidanceNavigationControl;
			
			require constraint {
				gnc.navigationAccuracy.num <= 100000.0 and
				gnc.attitudeAccuracy <= 0.1
			}
		}
		
		requirement powerRequirement {
			doc /* The power system shall provide at least 300 W at beginning 
			       of life and maintain 200 W at end of mission. */
			
			subject solarArray : SolarArrayAssembly;
			
			require constraint {
				solarArray.outputPower.num >= 300.0
			}
		}
		
		requirement propulsionRequirement {
			doc /* The propulsion system shall provide a total delta-V capability 
			       of at least 2000 m/s for trajectory corrections and orbit insertion. */
			
			subject propulsion : PropulsionSystem;
		}
	}
	
	part def InterplanetarySpacecraft {
		doc /* An interplanetary spacecraft system designed and operated by JPL 
		       for deep space exploration missions. The primary function is to 
		       travel to distant planetary bodies, conduct comprehensive scientific 
		       observations using advanced instruments, and relay discoveries back 
		       to Earth through the Deep Space Network. */
		
		attribute totalMass : MassValue;
		attribute launchMass : MassValue;
		attribute dryMass : MassValue;
		
		part powerSystem {
			part solarArrays : SolarArrayAssembly {
				attribute totalArea = 25.0[m^2];
				attribute efficiency = 0.29;
				attribute outputPower = 350.0[W];
			}
			
			part batteries : BatterySystem {
				attribute capacity = 50.0;
				attribute stateOfCharge = 0.8;
				attribute cellCount = 96;
			}
			
			part pdu : PowerDistributionUnit {
				attribute regulatedVoltage = 28.0;
			}
			
			connect solarArrays.powerOut to pdu.solarInput;
			connect batteries.powerOut to pdu.batteryInput;
			connect pdu.batteryOutput to batteries.powerIn;
		}
		
		part propulsion : PropulsionSystem {
			attribute fuelMass = 450.0[kg];
			attribute oxidizerMass = 550.0[kg];
			attribute specificImpulse = 320.0;
			attribute maxThrust = 445.0[N];
		}
		
		part gnc : GuidanceNavigationControl {
			attribute navigationAccuracy = 50000.0[m];
			attribute attitudeAccuracy = 0.05;
		}
		
		part communications : CommunicationsSubsystem {
			attribute transmitPower = 25.0[W];
			attribute antennaGain = 48.0;
			attribute dataRate = 2000.0;
		}
		
		part sciencePayload : ScienceInstrumentSuite {
			attribute totalMass = 120.0[kg];
			attribute powerConsumption = 85.0[W];
		}
		
		part cdh : CommandDataHandling {
			attribute storageCapacity = 8000000000.0;
			attribute processingRate = 100000000.0;
		}
		
		part thermal : ThermalControlSystem {
			attribute operatingTemperature = 293.0[K];
		}
		
		connect powerSystem.pdu.systemPower1 to propulsion.powerIn;
		connect powerSystem.pdu.systemPower2 to gnc.powerIn;
		connect powerSystem.pdu.systemPower3 to communications.powerIn;
		connect powerSystem.pdu.systemPower4 to sciencePayload.powerIn;
		
		connect gnc.dataBus to cdh.dataBus;
		connect communications.dataBus to cdh.dataBus;
		connect sciencePayload.dataBus to cdh.dataBus;
		connect propulsion.controlBus to cdh.dataBus;
		
		perform action missionOps : InterplanetaryMissionOperation[*] {
			in missionPhase;
			in targetPlanet;
		}
		
		exhibit state operationalStates : SpacecraftOperationalStates;
		
		satisfy missionReqs : InterplanetaryMissionRequirements;
		
		attribute missionPhase : String;
		attribute targetPlanet : String;
	}
	
	part jplInterplanetaryMission : InterplanetarySpacecraft {
		attribute totalMass = 2500.0[kg];
		attribute launchMass = 2500.0[kg];
		attribute dryMass = 1500.0[kg];
		attribute missionPhase = "Cruise";
		attribute targetPlanet = "Jupiter";
	}
}
