package SpaceExplorationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MissionPhase;
    attribute def NavigationData;
    attribute def ScienceData;
    attribute def SystemHealth;
    attribute def CommandSignal;
    attribute def TelemetryData;
    
    attribute def Distance :> ISQ::LengthValue;
    attribute def Velocity :> ISQ::SpeedValue;
    attribute def DataVolume :> Real;
    attribute def PowerLevel :> ISQ::PowerValue;
    attribute def Temperature :> ISQ::ThermodynamicTemperatureValue;
    attribute def Percentage :> Real;
    
    item def ScienceSample {
        attribute sampleId : String;
        attribute collectionTime : ISQ::TimeValue;
        attribute mass : ISQ::MassValue;
        attribute composition : String;
    }
    
    port def CommandPort {
        in item command : CommandSignal;
        out item acknowledgment : TelemetryData;
    }
    
    port def DataPort {
        out item telemetry : TelemetryData;
        out item scienceData : ScienceData;
    }
    
    port def PowerPort {
        out attribute powerOutput : PowerLevel;
        in attribute powerDemand : PowerLevel;
    }
    
    part def GroundStation {
        port commandPort : CommandPort;
        port dataPort : ~DataPort;
        
        attribute location : String;
        attribute antennaSize : ISQ::LengthValue;
        
        action def SendCommand {
            out command : CommandSignal;
        }
        
        action def ReceiveData {
            in telemetry : TelemetryData;
            in science : ScienceData;
        }
    }
    
    part def PropulsionSystem {
        port powerIn : ~PowerPort;
        
        attribute fuelMass : ISQ::MassValue;
        attribute maxThrust : ISQ::ForceValue;
        attribute specificImpulse : Real;
        attribute currentThrust : ISQ::ForceValue;
        
        action def GenerateThrust {
            in thrustCommand : Real;
            in availablePower : PowerLevel;
            out thrustForce : ISQ::ForceValue;
            out fuelConsumed : ISQ::MassValue;
        }
        
        action def PerformManeuver {
            in deltaV : Velocity;
            in currentMass : ISQ::MassValue;
            out burnDuration : ISQ::TimeValue;
            out fuelUsed : ISQ::MassValue;
        }
    }
    
    part def PowerSystem {
        port powerOut : PowerPort;
        
        attribute solarPanelArea : ISQ::AreaValue;
        attribute batteryCapacity : ISQ::EnergyValue;
        attribute currentCharge : ISQ::EnergyValue;
        attribute chargeLevel : Percentage;
        
        action def GeneratePower {
            in sunExposure : Real;
            in solarEfficiency : Real;
            out powerGenerated : PowerLevel;
        }
        
        action def DistributePower {
            in totalDemand : PowerLevel;
            in availablePower : PowerLevel;
            out allocatedPower : PowerLevel;
        }
        
        action def ManageBattery {
            in powerGenerated : PowerLevel;
            in powerConsumed : PowerLevel;
            inout chargeLevel : Percentage;
        }
    }
    
    part def NavigationSystem {
        port powerIn : ~PowerPort;
        
        attribute currentPosition : Distance[3];
        attribute currentVelocity : Velocity[3];
        attribute targetPosition : Distance[3];
        attribute positionError : Distance;
        
        action def DeterminePosition {
            in sensorData : NavigationData;
            out position : Distance[3];
            out velocity : Velocity[3];
            out accuracy : Distance;
        }
        
        action def CalculateTrajectory {
            in currentPos : Distance[3];
            in currentVel : Velocity[3];
            in targetPos : Distance[3];
            out requiredThrust : ISQ::ForceValue;
            out burnDuration : ISQ::TimeValue;
            out arrivalTime : ISQ::TimeValue;
        }
        
        action def UpdateGuidance {
            in measuredPos : Distance[3];
            in targetPos : Distance[3];
            out correctionThrust : ISQ::ForceValue;
        }
    }
    
    part def CommunicationSystem {
        port commandPort : ~CommandPort;
        port dataPort : DataPort;
        port powerIn : ~PowerPort;
        
        attribute antennaGain : Real;
        attribute transmitPower : PowerLevel;
        attribute dataRate : Real;
        attribute linkQuality : Real;
        
        action def TransmitData {
            in data : ScienceData;
            in distance : Distance;
            out transmissionTime : ISQ::TimeValue;
            out powerRequired : PowerLevel;
            out success : Boolean;
        }
        
        action def ReceiveCommand {
            in signalStrength : Real;
            out command : CommandSignal;
            out valid : Boolean;
        }
        
        action def EstablishLink {
            in earthDistance : Distance;
            out linkEstablished : Boolean;
            out signalDelay : ISQ::TimeValue;
        }
    }
    
    part def ScienceInstrumentSuite {
        port powerIn : ~PowerPort;
        
        attribute instrumentCount : Integer;
        attribute dataStorageCapacity : DataVolume;
        attribute currentDataStored : DataVolume;
        attribute activeInstruments : Integer;
        
        action def CollectScience {
            in targetLocation : Distance[3];
            in instrumentMode : String;
            in duration : ISQ::TimeValue;
            out scienceData : ScienceData;
            out dataVolume : DataVolume;
        }
        
        action def ProcessData {
            in rawData : ScienceData;
            out processedData : ScienceData;
            out compressionRatio : Real;
        }
        
        action def StoreData {
            in data : ScienceData;
            inout currentStorage : DataVolume;
            out storageSuccess : Boolean;
        }
    }
    
    part def ThermalControlSystem {
        port powerIn : ~PowerPort;
        
        attribute operatingTemp : Temperature;
        attribute minTemp : Temperature;
        attribute maxTemp : Temperature;
        attribute heaterPower : PowerLevel;
        
        action def RegulateTemperature {
            in currentTemp : Temperature;
            in externalTemp : Temperature;
            in sunExposure : Real;
            out heatingPower : PowerLevel;
            out coolingPower : PowerLevel;
        }
        
        action def MonitorTemperature {
            out temperature : Temperature;
            out withinLimits : Boolean;
        }
    }
    
    part def SpaceProbe {
        part propulsion : PropulsionSystem;
        part power : PowerSystem;
        part navigation : NavigationSystem;
        part communication : CommunicationSystem;
        part scienceInstruments : ScienceInstrumentSuite;
        part thermalControl : ThermalControlSystem;
        
        attribute probeMass : ISQ::MassValue;
        attribute missionDuration : ISQ::TimeValue;
        attribute distanceFromEarth : Distance;
        attribute missionPhase : String;
        
        connection powerToPropulsion connect power.powerOut to propulsion.powerIn;
        connection powerToNavigation connect power.powerOut to navigation.powerIn;
        connection powerToCommunication connect power.powerOut to communication.powerIn;
        connection powerToScience connect power.powerOut to scienceInstruments.powerIn;
        connection powerToThermal connect power.powerOut to thermalControl.powerIn;
        
        exhibit state operationalStates;
        perform action executeMission;
    }
    
    action def ExecuteSpaceExplorationMission {
        in missionTarget : Distance[3];
        in missionObjectives : String[*];
        in maxMissionDuration : ISQ::TimeValue;
        out missionData : ScienceData[*];
        out missionSuccess : Boolean;
        out totalDataCollected : DataVolume;
    }
    
    action executeMission : ExecuteSpaceExplorationMission {
        first start;
        then merge missionLoop;
        
        action launch {
            action activateSystems {
                action powerUp;
                then action deployPanels;
                then action initializeInstruments;
            }
            then action initialBurn {
                action calculateDeparture;
                then action executeThrust;
            }
        }
        then missionLoop;
        
        action missionLoop {
            action receiveGroundCommand {
                action establishLink;
                then action decodeCommand;
            }
            then action updateNavigation {
                action measurePosition;
                then action calculateError;
                out distanceToTarget : Real;
                out positionAccuracy : Real;
            }
            then decide;
                if updateNavigation.distanceToTarget > 1000000.0 then cruisePhase;
                if updateNavigation.distanceToTarget <= 1000000.0 and updateNavigation.distanceToTarget > 100.0 then approachPhase;
                if updateNavigation.distanceToTarget <= 100.0 then sciencePhase;
            
            action cruisePhase {
                action monitorSystems {
                    action checkPower;
                    then action checkThermal;
                    then action checkCommunication;
                }
                then action performTrajectoryCorrection {
                    action calculateCorrection;
                    then action executeCorrection;
                }
                then action transmitTelemetry;
            }
            then missionLoop;
            
            action approachPhase {
                action precisionNavigation {
                    action highAccuracyMeasurement;
                    then action refinedTrajectory;
                }
                then action prepareInstruments {
                    action calibrateInstruments;
                    then action testInstruments;
                }
                then action transmitStatus;
            }
            then missionLoop;
            
            action sciencePhase {
                action collectScienceData {
                    action selectTarget;
                    then action activateInstrument;
                    then action acquireData;
                    out dataQuality : Real;
                    out objectivesComplete : Boolean;
                }
                then action processAndStore {
                    action compressData;
                    then action storeToMemory;
                }
                then action transmitScience {
                    action prioritizeData;
                    then action transmitHighPriority;
                }
                then decide;
                    if collectScienceData.objectivesComplete then endMission;
                    if not collectScienceData.objectivesComplete then missionLoop;
            }
        }
        
        action endMission {
            action finalDataTransmission {
                action transmitAllData;
                then action verifyTransmission;
            }
            then action safeModeTransition {
                action minimizePower;
                then action orientForCommunication;
            }
        }
        then done;
    }
    
    state def ProbeOperationalStates {
        entry; 
        then state launch;
        
        state launch {
            entry action activatePowerSystem;
            do action initialSystemCheck;
            do action deploymentSequence;
            accept launchComplete;
            then transition to cruise;
        }
        
        state cruise {
            entry action configureCruiseMode;
            do action maintainTrajectory;
            do action monitorHealth;
            do action periodicTelemetry;
            accept commandSignal : CommandSignal;
            then transition to approach;
        }
        
        state approach {
            entry action increaseNavigationAccuracy;
            do action continuousTracking;
            do action instrumentPreparation;
            accept targetProximity;
            then transition to science;
        }
        
        state science {
            entry action deployScienceInstruments;
            do action continuousDataCollection;
            
            entry;
            then state idle;
            
            state idle {
                do action maintainOrientation;
                accept targetAcquired;
                then transition to collecting;
            }
            
            state collecting {
                do action collectAndProcessData;
                do action monitorDataQuality;
                accept collectionComplete;
                then transition to transmitting;
            }
            
            state transmitting {
                do action transmitScienceData;
                do action verifyReception;
                accept transmissionComplete;
                then transition to idle;
            }
            
            accept missionComplete;
            then transition to safeMode;
        }
        
        state safeMode {
            entry action minimizePowerConsumption;
            do action maintainCommunication;
            do action basicHealthMonitoring;
        }
    }
    
    state operationalStates : ProbeOperationalStates;
    
    requirement def MissionRequirement {
        doc /* High-level requirements for space exploration mission */
        subject probe : SpaceProbe;
    }
    
    requirement <'REQ-001'> primaryMissionObjective : MissionRequirement {
        doc /* The space exploration system shall autonomously navigate to a distant 
             celestial target, collect comprehensive scientific data about the target 
             environment including atmospheric composition, surface characteristics, 
             and magnetic field properties, and transmit findings back to Earth ground 
             stations with sufficient fidelity for scientific analysis. */
    }
    
    requirement <'REQ-002'> dataCollectionRequirement : MissionRequirement {
        doc /* The system shall collect and store at least 100 GB of science data 
             during the mission with data quality sufficient for scientific analysis. */
        
        require constraint {
            probe.scienceInstruments.currentDataStored >= 100.0e9
        }
    }
    
    requirement <'REQ-003'> communicationRequirement : MissionRequirement {
        doc /* The system shall maintain reliable communication capability with Earth 
             ground stations at distances up to 5 billion kilometers with data rates 
             sufficient for mission operations and science data return. */
        
        require constraint {
            probe.communication.antennaGain >= 40.0 and
            probe.communication.linkQuality >= 0.8
        }
    }
    
    requirement <'REQ-004'> powerRequirement : MissionRequirement {
        doc /* The power system shall provide continuous power for all subsystems 
             throughout the mission duration with battery charge maintained above 
             20% to ensure system survival during eclipse periods. */
        
        require constraint {
            probe.power.chargeLevel >= 20.0
        }
    }
    
    requirement <'REQ-005'> autonomyRequirement : MissionRequirement {
        doc /* The system shall operate autonomously for extended periods without 
             ground intervention due to communication delays, with onboard fault 
             detection and recovery capabilities. */
    }
    
    requirement <'REQ-006'> navigationRequirement : MissionRequirement {
        doc /* The navigation system shall determine spacecraft position with accuracy 
             better than 100 km and execute trajectory corrections to maintain mission 
             profile within acceptable tolerances. */
    }
    
    requirement <'REQ-007'> thermalRequirement : MissionRequirement {
        doc /* The thermal control system shall maintain all spacecraft subsystems 
             within their operational temperature ranges throughout all mission phases. */
    }
    
    requirement <'REQ-008'> massRequirement : MissionRequirement {
        doc /* The total spacecraft mass including propellant shall not exceed 1500 kg 
             to meet launch vehicle constraints. */
    }
    
    part missionScenario {
        part groundControl : GroundStation {
            attribute location = "Deep Space Network - Goldstone";
        }
        
        part explorerProbe : SpaceProbe {
            attribute missionPhase = "CRUISE";
            
            part propulsion : PropulsionSystem {
                attribute specificImpulse = 310.0;
            }
            
            part power : PowerSystem {
                attribute chargeLevel = 90.0;
            }
            
            part communication : CommunicationSystem {
                attribute antennaGain = 42.0;
                attribute dataRate = 1000.0;
                attribute linkQuality = 0.85;
            }
            
            part scienceInstruments : ScienceInstrumentSuite {
                attribute instrumentCount = 7;
                attribute currentDataStored = 45.0e9;
                attribute activeInstruments = 3;
            }
            
            perform action missionExecution : ExecuteSpaceExplorationMission;
        }
        
        connection groundLink connect groundControl.commandPort to explorerProbe.communication.commandPort;
        connection dataLink connect explorerProbe.communication.dataPort to groundControl.dataPort;
    }
}
