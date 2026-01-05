package AerobotSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SequenceFunctions::*;
    
    attribute def AltitudeValue :> LengthValue;
    attribute def TemperatureValue :> ThermodynamicTemperatureValue;
    attribute def WindSpeedValue :> SpeedValue;
    attribute def BuoyancyForceValue :> ForceValue;
    attribute def BallastMassValue :> MassValue;
    
    attribute def NavigationCommand;
    attribute def BuoyancyCommand;
    attribute def ScienceCommand;
    attribute def SystemStatus;
    
    item def AtmosphericMeasurement {
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute windSpeed : WindSpeedValue;
        attribute altitude : AltitudeValue;
        attribute timestamp : TimeValue;
    }
    
    item def ScienceDataPacket {
        attribute imageData : String;
        attribute spectralData : String;
        attribute particleData : String;
        attribute measurement : AtmosphericMeasurement;
    }
    
    item def Waypoint {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute targetAltitude : AltitudeValue;
    }
    
    port def AtmosphericSensorPort {
        out measurement : AtmosphericMeasurement;
    }
    
    port def ScienceDataPort {
        out data : ScienceDataPacket;
    }
    
    port def NavigationCommandPort {
        in command : NavigationCommand;
    }
    
    port def BuoyancyControlPort {
        in command : BuoyancyCommand;
        out liftForce : BuoyancyForceValue;
    }
    
    port def PowerSupplyPort {
        out voltage : ElectricPotentialValue;
        out current : ElectricCurrentValue;
        in demand : PowerValue;
    }
    
    port def TelemetryPort {
        out status : SystemStatus;
        out position : Waypoint;
        out batteryLevel : Real;
    }
    
    part def BalloonEnvelope {
        attribute volume : VolumeValue;
        attribute liftingGas : String;
        attribute currentBuoyancy : BuoyancyForceValue;
        port buoyancyPort : BuoyancyControlPort;
        
        action generateLift {
            in gasVolume : VolumeValue;
            in atmosphericDensity : Real;
            out liftForce : BuoyancyForceValue;
        }
    }
    
    part def BallastSystem {
        attribute ballastMass : BallastMassValue;
        attribute maxReleaseMass : BallastMassValue;
        
        action releaseBallast {
            in massToRelease : BallastMassValue;
            out actualReleased : BallastMassValue;
        }
    }
    
    part def AtmosphericSensorSuite {
        port sensorPort : AtmosphericSensorPort;
        attribute samplingRate : FrequencyValue;
        
        action measureAtmosphere {
            out measurement : AtmosphericMeasurement;
        }
    }
    
    part def ScienceInstrumentPackage {
        port dataPort : ScienceDataPort;
        attribute operatingMode : String;
        
        action collectScienceData {
            in measurement : AtmosphericMeasurement;
            in mode : ScienceCommand;
            out data : ScienceDataPacket;
        }
    }
    
    part def NavigationSubsystem {
        port navPort : NavigationCommandPort;
        attribute currentPosition : Waypoint;
        attribute targetWaypoint : Waypoint;
        
        action computeNavigation {
            in current : Waypoint;
            in target : Waypoint;
            in windData : AtmosphericMeasurement;
            out navCommand : NavigationCommand;
        }
    }
    
    part def BuoyancyController {
        attribute targetAltitude : AltitudeValue;
        attribute currentAltitude : AltitudeValue;
        attribute altitudeTolerance : LengthValue;
        
        action controlAltitude {
            in target : AltitudeValue;
            in current : AltitudeValue;
            in atmosphericData : AtmosphericMeasurement;
            out buoyancyCmd : BuoyancyCommand;
        }
    }
    
    part def PowerSystem {
        port powerPort : PowerSupplyPort;
        attribute batteryCapacity : EnergyValue;
        attribute currentCharge : EnergyValue;
        attribute solarPanelArea : AreaValue;
        
        action managePower {
            in totalDemand : PowerValue;
            in solarIrradiance : Real;
            out availablePower : PowerValue;
        }
    }
    
    part def CommunicationSubsystem {
        attribute dataBuffer : ScienceDataPacket[*];
        attribute linkQuality : Real;
        
        action transmitData {
            in data : ScienceDataPacket;
            out transmissionSuccess : Boolean;
        }
        
        action receiveCommands {
            out navCmd : NavigationCommand;
            out scienceCmd : ScienceCommand;
        }
    }
    
    part def Gondola {
        attribute mass : MassValue;
        
        part instruments : ScienceInstrumentPackage;
        part sensors : AtmosphericSensorSuite;
        part navigation : NavigationSubsystem;
        part communications : CommunicationSubsystem;
        part power : PowerSystem;
        
        connection sensorData connect sensors.sensorPort to instruments.dataPort;
        connection powerSupply connect power.powerPort to instruments.dataPort;
    }
    
    action def ExploreAtmosphere {
        in missionWaypoints : Waypoint[*];
        in missionDuration : TimeValue;
        in targetAltitudeRange : AltitudeValue[2];
        out collectedData : ScienceDataPacket[*];
        out missionStatus : SystemStatus;
    }
    
    action def MaintainStableAltitude {
        in desiredAltitude : AltitudeValue;
        in currentConditions : AtmosphericMeasurement;
        in ballastAvailable : BallastMassValue;
        out altitudeAdjustment : BuoyancyCommand;
    }
    
    action def NavigateToWaypoint {
        in targetWaypoint : Waypoint;
        in currentPosition : Waypoint;
        in windConditions : AtmosphericMeasurement;
        out navigationPath : NavigationCommand[*];
        out estimatedTime : TimeValue;
    }
    
    action def CollectAtmosphericProfile {
        in altitudeRange : AltitudeValue[2];
        in samplingInterval : TimeValue;
        out profileData : ScienceDataPacket[*];
    }
    
    part def Aerobot {
        doc /* 
        An Aerobot is an autonomous lighter-than-air aerial vehicle designed for 
        extended atmospheric exploration of planetary environments. Its primary 
        function is to navigate through atmospheric layers at controlled altitudes, 
        continuously collect scientific measurements of atmospheric composition, 
        temperature, pressure, and wind patterns, capture imaging and spectral data, 
        and transmit findings to ground stations or orbiting relays. The system 
        autonomously maintains stable flight by adjusting buoyancy through ballast 
        release and gas venting, navigates to designated waypoints using wind currents, 
        and executes a comprehensive atmospheric survey mission while managing limited 
        power and communication resources.
        */
        
        attribute totalMass : MassValue;
        attribute operationalAltitude : AltitudeValue;
        attribute missionStatus : SystemStatus;
        
        part balloon : BalloonEnvelope {
            port buoyancyPort;
        }
        
        part ballast : BallastSystem;
        
        part gondola : Gondola {
            part instruments;
            part sensors;
            part navigation;
            part communications;
            part power;
        }
        
        part buoyancyCtrl : BuoyancyController;
        
        port telemetryOut : TelemetryPort;
        
        connection balloonToBuoyancy connect balloon.buoyancyPort to buoyancyCtrl;
        connection sensorToBuoyancy connect gondola.sensors.sensorPort to buoyancyCtrl;
        connection powerToGondola connect gondola.power.powerPort to gondola.instruments;
        
        perform action aerobotMission : ExploreAtmosphere {
            in missionWaypoints;
            in missionDuration;
            in targetAltitudeRange;
            out collectedData;
            out missionStatus;
            
            first start;
            then merge missionLoop;
            
            action senseEnvironment : AtmosphericSensorSuite::measureAtmosphere {
                out measurement;
            }
            
            then action controlAltitude : BuoyancyController::controlAltitude {
                in target = targetAltitudeRange[0];
                in current = operationalAltitude;
                in atmosphericData = senseEnvironment.measurement;
                out buoyancyCmd;
            }
            
            then action adjustBuoyancy : BalloonEnvelope::generateLift {
                in gasVolume = balloon.volume;
                in atmosphericDensity = 1.2;
                out liftForce;
            }
            
            then action navigate : NavigationSubsystem::computeNavigation {
                in current = gondola.navigation.currentPosition;
                in target = gondola.navigation.targetWaypoint;
                in windData = senseEnvironment.measurement;
                out navCommand;
            }
            
            then action collectData : ScienceInstrumentPackage::collectScienceData {
                in measurement = senseEnvironment.measurement;
                in mode;
                out data;
            }
            
            then assign collectedData := collectedData->including(collectData.data);
            
            then action transmit : CommunicationSubsystem::transmitData {
                in data = collectData.data;
                out transmissionSuccess;
            }
            
            then action checkPower : PowerSystem::managePower {
                in totalDemand;
                in solarIrradiance = 1000.0;
                out availablePower;
            }
            
            then decide;
                if checkPower.availablePower > 10.0 and missionDuration > 0 then missionLoop;
                if checkPower.availablePower <= 10.0 or missionDuration <= 0 then endMission;
            
            action endMission;
            then done;
        }
    }
    
    part aerobot : Aerobot {
        exhibit state flightStates {
            entry; then initialization;
            
            state initialization;
            then ascent;
            
            state ascent;
            accept at operationalAltitude >= 15000.0;
            then cruiseOperation;
            
            state cruiseOperation {
                entry; then measuring;
                
                state measuring;
                then dataCollection;
                
                state dataCollection;
                then transmitting;
                
                state transmitting;
                then navigating;
                
                state navigating;
                then measuring;
            }
            accept at gondola.power.currentCharge < 0.1 * gondola.power.batteryCapacity;
            then descent;
            
            state descent;
            then missionComplete;
            
            state missionComplete;
            then done;
        }
    }
    
    requirement def AerobotMissionCapability {
        doc /* 
        The Aerobot system shall autonomously explore planetary atmospheres by 
        navigating to designated waypoints, maintaining stable altitude control, 
        and collecting comprehensive atmospheric science data.
        */
        
        subject aerobot : Aerobot;
        
        require altitudeControl : AltitudeControlRequirement;
        require dataCollection : DataCollectionRequirement;
        require autonomousOperation : AutonomousOperationRequirement;
        require powerManagement : PowerManagementRequirement;
    }
    
    requirement altitudeControl : AltitudeControlRequirement {
        doc /* 
        The Aerobot shall maintain altitude within +/- 200 meters of target 
        altitude during nominal atmospheric conditions.
        */
        
        subject aerobot : Aerobot;
        
        assume constraint nominalConditions {
            doc /* Wind speeds less than 25 m/s and stable atmospheric density */
        }
        
        require constraint altitudePrecision {
            abs(aerobot.operationalAltitude - aerobot.buoyancyCtrl.targetAltitude) <= 200.0
        }
    }
    
    requirement dataCollection : DataCollectionRequirement {
        doc /* 
        The Aerobot shall collect atmospheric measurements at minimum intervals 
        of 5 minutes and transmit data packets at least every 30 minutes.
        */
        
        subject aerobot : Aerobot;
        
        require constraint samplingFrequency {
            aerobot.gondola.sensors.samplingRate >= 0.0033
        }
        
        require constraint transmissionRate {
            doc /* Data transmission occurs at minimum every 1800 seconds */
        }
    }
    
    requirement autonomousOperation : AutonomousOperationRequirement {
        doc /* 
        The Aerobot shall operate autonomously for extended mission durations 
        with minimal ground intervention, making independent decisions for 
        navigation and altitude control.
        */
        
        subject aerobot : Aerobot;
        
        require constraint navigationAutonomy {
            doc /* Navigation system computes trajectory corrections autonomously */
        }
        
        require constraint buoyancyAutonomy {
            doc /* Buoyancy control operates without ground commands */
        }
    }
    
    requirement powerManagement : PowerManagementRequirement {
        doc /* 
        The Aerobot shall manage power resources to sustain operations for 
        minimum 30 days, maintaining battery charge above 20% reserve.
        */
        
        subject aerobot : Aerobot;
        
        require constraint minimumCharge {
            aerobot.gondola.power.currentCharge >= 0.2 * aerobot.gondola.power.batteryCapacity
        }
        
        require constraint missionDuration {
            doc /* System operational for minimum 2592000 seconds (30 days) */
        }
    }
}
