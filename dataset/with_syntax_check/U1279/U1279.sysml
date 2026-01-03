package DaintreeNetworksWirelessLightingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def NetworkAddress :> String;
    attribute def DeviceID :> String;
    
    attribute def IlluminanceLevel :> Real;
    
    attribute def DimmingLevel :> Real;
    
    enum def OccupancyState {
        enum vacant;
        enum occupied;
    }
    
    enum def LightingMode {
        enum off;
        enum manual;
        enum automatic;
        enum scheduled;
    }
    
    item def SensorReading {
        attribute timestamp : TimeValue;
        attribute sourceAddress : NetworkAddress;
    }
    
    item def OccupancyReading :> SensorReading {
        attribute status : OccupancyState;
    }
    
    item def DaylightReading :> SensorReading {
        attribute illuminance : IlluminanceLevel;
    }
    
    item def ControlMessage {
        attribute targetAddress : NetworkAddress;
        attribute timestamp : TimeValue;
    }
    
    item def DimmingCommand :> ControlMessage {
        attribute targetLevel : DimmingLevel;
        attribute transitionTime : TimeValue;
    }
    
    item def StatusReport :> ControlMessage {
        attribute currentLevel : DimmingLevel;
        attribute powerUsage : PowerValue;
        attribute operationalMode : LightingMode;
    }
    
    port def WirelessMeshPort {
        in item receivedMessages : ControlMessage[*];
        out item transmittedMessages : ControlMessage[*];
    }
    
    port def SensorPort {
        out attribute reading : SensorReading;
    }
    
    port def LightingControlPort {
        in item command : DimmingCommand;
        out attribute currentOutput : DimmingLevel;
    }
    
    part def OccupancySensor {
        attribute sensorID : DeviceID;
        attribute networkAddr : NetworkAddress;
        attribute detectionRadius : LengthValue;
        
        port meshPort : WirelessMeshPort;
        port sensorOutput : SensorPort;
        
        part detector {
            attribute motionDetected : Boolean := false;
            attribute lastDetectionTime : TimeValue;
        }
        
        state occupancyStateMachine {
            entry; then checkingVacant;
            
            state checkingVacant;
            
            transition checkingVacant_to_detectedOccupied
                first checkingVacant
                accept at checkingVacant
                if detector.motionDetected
                then detectedOccupied;
            
            state detectedOccupied {
                do action transmitOccupancy {
                    out report : OccupancyReading;
                }
            }
            
            transition detectedOccupied_to_checkingVacant
                first detectedOccupied
                accept at detectedOccupied
                if not detector.motionDetected
                then checkingVacant;
        }
    }
    
    part def DaylightSensor {
        attribute sensorID : DeviceID;
        attribute networkAddr : NetworkAddress;
        attribute calibrationFactor : Real := 1.0;
        
        port meshPort : WirelessMeshPort;
        port sensorOutput : SensorPort;
        
        part photodetector {
            attribute measuredIlluminance : IlluminanceLevel;
        }
        
        perform action sampleAndTransmit[*] {
            first start;
            then action measureLight {
                out lightLevel : IlluminanceLevel;
            }
            then action createReading {
                in measured : IlluminanceLevel = measureLight.lightLevel;
                out reading : DaylightReading;
            }
            then action transmitReading {
                in data : DaylightReading = createReading.reading;
            }
            then done;
        }
    }
    
    part def LightingFixture {
        attribute fixtureID : DeviceID;
        attribute networkAddr : NetworkAddress;
        attribute ratedPower : PowerValue;
        attribute currentDimLevel : DimmingLevel := 0.0;
        
        port meshPort : WirelessMeshPort;
        port controlInterface : LightingControlPort;
        
        part ballast {
            attribute outputLevel : DimmingLevel;
            attribute efficiency : Real := 0.85;
        }
        
        part powerMeter {
            attribute activePower : PowerValue;
        }
        
        state lightingStateMachine {
            entry; then offState;
            
            state offState;
            
            transition offState_to_dimmingState
                first offState
                accept at offState
                if controlInterface.command.targetLevel > 0.0
                then dimmingState;
            
            state dimmingState {
                do action adjustOutput {
                    in targetLevel : DimmingLevel = controlInterface.command.targetLevel;
                }
            }
            
            transition dimmingState_to_offState
                first dimmingState
                accept at dimmingState
                if controlInterface.command.targetLevel == 0.0
                then offState;
        }
        
        perform action reportStatus[*] {
            out status : StatusReport;
        }
    }
    
    part def WirelessAreaController {
        attribute controllerID : DeviceID;
        attribute networkAddr : NetworkAddress;
        attribute targetIlluminance : IlluminanceLevel := 500.0;
        attribute occupancyTimeout : TimeValue;
        
        port meshPort : WirelessMeshPort;
        
        part controlLogic {
            attribute currentOccupancy : OccupancyState := OccupancyState::vacant;
            attribute currentDaylight : IlluminanceLevel := 0.0;
            attribute controlMode : LightingMode := LightingMode::automatic;
        }
        
        part scheduler {
            attribute scheduleActive : Boolean := false;
        }
        
        action def CalculateDimmingLevel {
            in occupancy : OccupancyState;
            in ambientLight : IlluminanceLevel;
            in target : IlluminanceLevel;
            out commandLevel : DimmingLevel;
            
            decide;
                if occupancy == OccupancyState::vacant then assignZero;
                else checkAmbient;
            
            action assignZero {
                then assign commandLevel := 0.0;
            }
            then done;
            
            action checkAmbient {
                decide;
                    if ambientLight >= target then assignMinimum;
                    else calculateDeficit;
            }
            
            action assignMinimum {
                then assign commandLevel := 10.0;
            }
            then done;
            
            action calculateDeficit {
                attribute deficit : Real := (target - ambientLight) / target;
                then assign commandLevel := deficit * 100.0;
            }
            then done;
        }
        
        perform action manageLightingZone {
            first start;
            then merge awaitSensorData;
            
            accept action processOccupancy {
                in occReading : OccupancyReading;
            }
            then computeControl;
            
            accept action processDaylight {
                in dayReading : DaylightReading;
            }
            then computeControl;
            
            action computeControl : CalculateDimmingLevel {
                in occupancy = controlLogic.currentOccupancy;
                in ambientLight = controlLogic.currentDaylight;
                in target = targetIlluminance;
                out commandLevel;
            }
            then action issueCommand {
                in level : DimmingLevel = computeControl.commandLevel;
                out cmd : DimmingCommand;
            }
            then awaitSensorData;
        }
    }
    
    part def NetworkGateway {
        attribute gatewayID : DeviceID;
        attribute networkAddr : NetworkAddress;
        
        port meshPort : WirelessMeshPort;
        
        part meshCoordinator {
            attribute routingTable : NetworkAddress[*];
            attribute connectedDevices : Integer;
        }
        
        part cloudInterface {
            attribute connectionActive : Boolean;
            attribute dataBufferSize : Integer;
        }
        
        perform action routeMessages {
            first start;
            then merge receiveMessage;
            
            action receiveFromMesh {
                in msg : ControlMessage;
            }
            then decide;
                if msg.targetAddress != networkAddr then forwardToDevice;
                else processLocally;
            
            action forwardToDevice {
                in message : ControlMessage = receiveFromMesh.msg;
            }
            then receiveMessage;
            
            action processLocally {
                in message : ControlMessage = receiveFromMesh.msg;
            }
            then receiveMessage;
        }
    }
    
    part daintreeWirelessLightingSystem {
        doc /*
            Daintree Networks wireless lighting control system provides intelligent,
            energy-efficient building automation through a self-organizing mesh network
            of sensors, controllers, and lighting fixtures. The system automatically
            adjusts lighting levels based on occupancy detection and available daylight,
            reducing energy consumption while maintaining optimal illumination levels.
        */
        
        part gateway : NetworkGateway {
            perform action routeMessages;
        }
        
        part areaControllers : WirelessAreaController[4] {
            perform action manageLightingZone;
        }
        
        part occupancySensors : OccupancySensor[8];
        
        part daylightSensors : DaylightSensor[4] {
            perform action sampleAndTransmit[*];
        }
        
        part lightingFixtures : LightingFixture[16] {
            perform action reportStatus[*];
        }
        
        connection meshNetwork1 connect gateway.meshPort to areaControllers.meshPort;
        connection meshNetwork2 connect areaControllers.meshPort to occupancySensors.meshPort;
        connection meshNetwork3 connect areaControllers.meshPort to daylightSensors.meshPort;
        connection meshNetwork4 connect areaControllers.meshPort to lightingFixtures.meshPort;
    }
    
    occurrence def LightingControlOperation {
        ref part system :>> daintreeWirelessLightingSystem;
        
        first start;
        then merge continuousOperation;
        
        action detectOccupancy;
        
        then action measureDaylight;
        
        then action processControlLogic;
        
        then action adjustFixtures;
        
        then action routeNetworkTraffic;
        
        then continuousOperation;
    }
    
    requirement def EnergyEfficiencyRequirement {
        doc /* The system shall reduce lighting energy consumption by at least 30% compared to traditional always-on lighting. */
        
        subject lightingSystem : daintreeWirelessLightingSystem;
        
        require constraint energyReduction {
            doc /* Total energy consumption shall be reduced through occupancy-based control and daylight harvesting. */
        }
    }
    
    requirement def OccupancyResponseRequirement {
        doc /* The system shall respond to occupancy changes within specified time limits. */
        
        subject controller : WirelessAreaController;
        
        require constraint responseTime {
            doc /* Lighting shall activate within 2 seconds of occupancy detection. */
        }
        
        require constraint vacancyDelay {
            doc /* Lighting shall deactivate after 15 minutes of vacancy. */
        }
    }
    
    requirement def DaylightHarvestingRequirement {
        doc /* The system shall utilize available daylight to minimize artificial lighting. */
        
        subject controller : WirelessAreaController;
        
        require constraint illuminanceTarget {
            doc /* System shall maintain target illuminance of 500 lux at work surfaces. */
        }
        
        require constraint dimmingRange {
            doc /* Fixtures shall support continuous dimming from 10% to 100% output. */
        }
    }
    
    requirement def WirelessReliabilityRequirement {
        doc /* The wireless mesh network shall provide reliable communication. */
        
        subject network : NetworkGateway;
        
        require constraint messageDelivery {
            doc /* Message delivery success rate shall exceed 98%. */
        }
        
        require constraint networkLatency {
            doc /* End-to-end message latency shall not exceed 500 milliseconds. */
        }
    }
    
    requirement <'SYS-REQ-001'> systemMissionRequirement {
        doc /*
            The Daintree Networks wireless lighting control system shall provide
            automated, energy-efficient lighting management for commercial buildings
            through wireless mesh networking, occupancy sensing, and daylight harvesting,
            achieving significant energy savings while maintaining occupant comfort and
            productivity.
        */
        
        assume constraint wirelessCoverage {
            doc /* Adequate wireless mesh coverage exists throughout the controlled space. */
        }
        
        assume constraint powerAvailability {
            doc /* Continuous power is available to all lighting fixtures and controllers. */
        }
        
        require energyEfficiency : EnergyEfficiencyRequirement;
        require occupancyResponse : OccupancyResponseRequirement;
        require daylightHarvesting : DaylightHarvestingRequirement;
        require wirelessReliability : WirelessReliabilityRequirement;
    }
}
