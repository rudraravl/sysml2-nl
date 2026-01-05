package SpaceProbeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ProbeStatus {
        attribute powerLevel : Real;
        attribute dataBufferUsage : Real;
        attribute attitudeStable : Boolean;
        attribute communicationActive : Boolean;
        attribute thermalStatus : Real;
    }
    
    attribute def ScienceData {
        attribute dataType : String;
        attribute timestamp : ISQ::TimeValue;
        attribute dataSize : Real;
        attribute priority : Integer;
    }
    
    attribute def NavigationData {
        attribute position : ISQ::LengthValue[3];
        attribute velocity : ISQ::SpeedValue[3];
        attribute orientation : Real[3];
    }
    
    attribute def CommandSignal {
        attribute commandType : String;
        attribute parameters : Real[*];
        attribute timestamp : ISQ::TimeValue;
    }
    
    port def PowerPort {
        out attribute voltage : ISQ::ElectricPotentialValue;
        out attribute current : ISQ::ElectricCurrentValue;
        out attribute availablePower : ISQ::PowerValue;
    }
    
    port def DataPort {
        in attribute scienceData : ScienceData;
        out attribute transmissionReady : Boolean;
    }
    
    port def CommunicationPort {
        in attribute uplinkCommand : CommandSignal;
        out attribute downlinkData : ScienceData;
        out attribute telemetry : ProbeStatus;
    }
    
    port def SensorPort {
        out attribute measurements : ScienceData;
    }
    
    port def ControlPort {
        in attribute targetOrientation : Real[3];
        out attribute currentOrientation : Real[3];
    }
    
    part def PowerSubsystem {
        attribute batteryCapacity : ISQ::EnergyValue;
        attribute solarPanelArea : ISQ::AreaValue;
        attribute currentCharge : Real;
        attribute solarEfficiency : Real;
        
        port powerOut : PowerPort;
        
        action generatePower {
            in solarIrradiance : ISQ::PowerValue;
            out generatedPower : ISQ::PowerValue;
        }
        
        action managePower {
            in demand : ISQ::PowerValue;
            in currentCharge : Real;
            out supplied : ISQ::PowerValue;
            out updatedCharge : Real;
        }
    }
    
    part def CommunicationSubsystem {
        attribute antennaGain : Real;
        attribute transmitPower : ISQ::PowerValue;
        attribute dataRate : Real;
        attribute frequency : ISQ::FrequencyValue;
        
        port commPort : CommunicationPort;
        port powerIn : PowerPort;
        
        action receiveCommand {
            out command : CommandSignal;
        }
        
        action transmitData {
            in data : ScienceData;
            in telemetry : ProbeStatus;
            in powerAvailable : ISQ::PowerValue;
            out transmissionSuccess : Boolean;
        }
        
        action establishLink {
            in earthPosition : ISQ::LengthValue[3];
            in probePosition : ISQ::LengthValue[3];
            out linkEstablished : Boolean;
        }
    }
    
    part def AttitudeControlSubsystem {
        attribute reactionWheelSpeed : Real[3];
        attribute thrusterFuel : ISQ::MassValue;
        attribute momentumCapacity : Real;
        
        port controlPort : ControlPort;
        port powerIn : PowerPort;
        
        action stabilizeAttitude {
            in targetOrientation : Real[3];
            in currentOrientation : Real[3];
            out controlSignal : Real[3];
        }
        
        action maintainPointing {
            in targetDirection : Real[3];
            out stable : Boolean;
        }
        
        action desaturateWheels {
            in wheelSpeed : Real[3];
            in fuelAvailable : ISQ::MassValue;
            out thrusterFiring : Boolean;
        }
    }
    
    part def ScienceInstrumentSubsystem {
        attribute instrumentType : String;
        attribute calibrationStatus : Boolean;
        attribute operatingTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute fieldOfView : Real;
        attribute resolution : Real;
        
        port sensorOut : SensorPort;
        port powerIn : PowerPort;
        
        action collectData {
            in targetBody : String;
            in exposureTime : ISQ::TimeValue;
            out measurements : ScienceData;
        }
        
        action processData {
            in rawData : ScienceData;
            out processedData : ScienceData;
        }
        
        action calibrateInstrument {
            in referenceTarget : String;
            out calibrationSuccess : Boolean;
        }
    }
    
    part def DataStorageSubsystem {
        attribute storageCapacity : Real;
        attribute currentUsage : Real;
        attribute compressionRatio : Real;
        
        port dataIn : DataPort;
        port powerIn : PowerPort;
        
        action storeData {
            in data : ScienceData;
            in currentUsage : Real;
            out stored : Boolean;
            out updatedUsage : Real;
        }
        
        action retrieveData {
            in priority : Integer;
            out data : ScienceData;
        }
        
        action compressData {
            in rawData : ScienceData;
            out compressedData : ScienceData;
        }
    }
    
    part def NavigationSubsystem {
        attribute position : ISQ::LengthValue[3];
        attribute velocity : ISQ::SpeedValue[3];
        attribute accuracy : ISQ::LengthValue;
        
        port powerIn : PowerPort;
        
        action determinePosition {
            in starTrackerData : Real[*];
            in accelerometerData : Real[3];
            out navData : NavigationData;
        }
        
        action planTrajectory {
            in targetPosition : ISQ::LengthValue[3];
            in currentPosition : ISQ::LengthValue[3];
            in currentVelocity : ISQ::SpeedValue[3];
            out trajectory : NavigationData[*];
        }
        
        action executeManeuver {
            in plannedTrajectory : NavigationData[*];
            out maneuverComplete : Boolean;
        }
    }
    
    part def ThermalControlSubsystem {
        attribute radiatorArea : ISQ::AreaValue;
        attribute heaterPower : ISQ::PowerValue;
        attribute currentTemperature : ISQ::ThermodynamicTemperatureValue;
        
        port powerIn : PowerPort;
        
        action regulateTemperature {
            in targetTemp : ISQ::ThermodynamicTemperatureValue;
            in currentTemp : ISQ::ThermodynamicTemperatureValue;
            out heaterActive : Boolean;
        }
        
        action monitorTemperature {
            out temperature : ISQ::ThermodynamicTemperatureValue;
        }
    }
    
    action def CollectScienceData {
        in instrumentActive : Boolean;
        in targetBody : String;
        in exposureTime : ISQ::TimeValue;
        out scienceData : ScienceData;
    }
    
    action def StoreAndManageData {
        in data : ScienceData;
        in bufferCapacity : Real;
        in currentUsage : Real;
        out dataStored : Boolean;
        out updatedUsage : Real;
    }
    
    action def TransmitToEarth {
        in data : ScienceData;
        in commReady : Boolean;
        in linkEstablished : Boolean;
        out transmitted : Boolean;
    }
    
    action def ExecuteMissionSequence {
        in missionTarget : String;
        in missionDuration : ISQ::TimeValue;
        out missionComplete : Boolean;
        
        first start;
        then merge missionLoop;
        
        then action checkStatus {
            out systemHealthy : Boolean;
            out dataAvailable : Boolean;
            out commWindowOpen : Boolean;
            out powerSufficient : Boolean;
            out attitudeStable : Boolean;
        }
        
        then decide healthCheck;
            if checkStatus.systemHealthy && checkStatus.powerSufficient 
                then normalOperations;
            if !checkStatus.systemHealthy || !checkStatus.powerSufficient 
                then safeModeAction;
        
        action normalOperations {
            first action pointToTarget {
                in target = missionTarget;
                out pointingAchieved : Boolean;
            }
            
            then action collectScience : CollectScienceData {
                in instrumentActive = true;
                in targetBody = missionTarget;
                in exposureTime = 30.0[s];
                out scienceData;
            }
            
            then action storeData : StoreAndManageData {
                in data = collectScience.scienceData;
                in bufferCapacity = 8000.0;
                in currentUsage = 0.0;
                out dataStored;
                out updatedUsage;
            }
            
            then decide transmissionDecision;
                if checkStatus.commWindowOpen && storeData.dataStored 
                    then transmitData;
                if !checkStatus.commWindowOpen || !storeData.dataStored 
                    then missionLoop;
            
            action transmitData : TransmitToEarth {
                in data = collectScience.scienceData;
                in commReady = checkStatus.commWindowOpen;
                in linkEstablished = true;
                out transmitted;
            }
            
            then missionLoop;
        }
        
        action safeModeAction {
            doc /* Enter safe mode: stabilize attitude, minimize power, await ground commands */
            
            action stabilize {
                out stabilized : Boolean;
            }
            
            then action minimizePower {
                out powerMinimized : Boolean;
            }
            
            then action awaitRecovery {
                out recoveryCommand : CommandSignal;
            }
        }
        
        then done;
    }
    
    part def SpaceProbe {
        doc /* 
            Autonomous deep space exploration probe designed to conduct scientific 
            observations of distant celestial bodies and transmit findings back to Earth.
            The probe operates independently for extended periods, managing power, attitude,
            thermal control, and data collection based on onboard decision-making and
            ground commands received during communication windows.
        */
    }
    
    part spaceProbe : SpaceProbe {
        attribute missionDuration : ISQ::TimeValue;
        attribute targetBody : String;
        attribute launchDate : String;
        attribute totalMass : ISQ::MassValue;
        
        part powerSystem : PowerSubsystem {
            attribute :>> batteryCapacity = 2.5[MJ];
            attribute :>> solarPanelArea = 18.0[m^2];
            attribute :>> currentCharge = 0.85;
            attribute :>> solarEfficiency = 0.28;
        }
        
        part commSystem : CommunicationSubsystem {
            attribute :>> antennaGain = 52.0;
            attribute :>> transmitPower = 25.0[W];
            attribute :>> dataRate = 256.0;
            attribute :>> frequency = 8.4[GHz];
        }
        
        part attitudeControl : AttitudeControlSubsystem {
            attribute :>> thrusterFuel = 75.0[kg];
            attribute :>> momentumCapacity = 50.0;
        }
        
        part scienceInstruments : ScienceInstrumentSubsystem {
            attribute :>> instrumentType = "Multispectral Imaging Spectrometer";
            attribute :>> calibrationStatus = true;
            attribute :>> operatingTemperature = 273.15[K];
            attribute :>> fieldOfView = 3.5;
            attribute :>> resolution = 100.0;
        }
        
        part dataStorage : DataStorageSubsystem {
            attribute :>> storageCapacity = 16000.0;
            attribute :>> currentUsage = 0.25;
            attribute :>> compressionRatio = 3.5;
        }
        
        part navigation : NavigationSubsystem {
            attribute :>> accuracy = 10.0[km];
        }
        
        part thermalControl : ThermalControlSubsystem {
            attribute :>> radiatorArea = 4.5[m^2];
            attribute :>> heaterPower = 150.0[W];
            attribute :>> currentTemperature = 285.0[K];
        }
        
        connect powerSystem.powerOut to commSystem.powerIn;
        connect powerSystem.powerOut to attitudeControl.powerIn;
        connect powerSystem.powerOut to scienceInstruments.powerIn;
        connect powerSystem.powerOut to dataStorage.powerIn;
        connect powerSystem.powerOut to navigation.powerIn;
        connect powerSystem.powerOut to thermalControl.powerIn;
        
        perform action missionOperation : ExecuteMissionSequence {
            in missionTarget = spaceProbe::targetBody;
            in missionDuration = spaceProbe::missionDuration;
        }
    }
    
    requirement def MissionRequirement;
    
    requirement <'PROBE-001'> primaryMissionObjective : MissionRequirement {
        doc /* 
            The space probe shall autonomously collect scientific data from 
            the target celestial body and transmit the data to Earth ground 
            stations during available communication windows, operating 
            independently for the duration of the mission.
        */
        
        subject spaceProbe;
        
        require scientificDataCollection;
        require autonomousOperation;
        require reliableCommunication;
        require powerManagement;
        require thermalStability;
    }
    
    requirement <'PROBE-002'> scientificDataCollection {
        doc /* 
            The probe shall collect multispectral imaging data and other 
            scientific measurements with sufficient resolution and accuracy 
            to meet mission science objectives.
        */
        
        subject spaceProbe.scienceInstruments;
    }
    
    requirement <'PROBE-003'> autonomousOperation {
        doc /* 
            The probe shall operate autonomously for extended periods without 
            ground intervention, managing power, attitude, thermal control, 
            and data collection based on onboard decision-making algorithms.
        */
        
        subject spaceProbe;
    }
    
    requirement <'PROBE-004'> reliableCommunication {
        doc /* 
            The probe shall maintain reliable communication with Earth ground 
            stations and successfully transmit collected scientific data during 
            scheduled communication windows with a success rate of at least 95%.
        */
        
        subject spaceProbe.commSystem;
    }
    
    requirement <'PROBE-005'> powerManagement {
        doc /* 
            The probe shall manage power resources to ensure continuous operation 
            throughout the mission duration, balancing solar power generation with 
            battery storage and system demands, maintaining battery charge above 15%.
        */
        
        subject spaceProbe.powerSystem;
    }
    
    requirement <'PROBE-006'> thermalStability {
        doc /* 
            The probe shall maintain all subsystems within their operational 
            temperature ranges throughout all mission phases, using passive 
            and active thermal control mechanisms.
        */
        
        subject spaceProbe.thermalControl;
    }
    
    requirement <'PROBE-007'> attitudeControl {
        doc /* 
            The probe shall maintain stable three-axis attitude control and 
            achieve pointing accuracy of 0.1 degrees for science observations 
            and Earth communications.
        */
        
        subject spaceProbe.attitudeControl;
    }
    
    requirement <'PROBE-008'> dataStorage {
        doc /* 
            The probe shall provide sufficient onboard data storage capacity 
            to buffer at least 72 hours of continuous science observations 
            between communication windows.
        */
        
        subject spaceProbe.dataStorage;
    }
}
