package SM4AllHighLevelSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    alias kWh for SI::Unit;
    alias percent for SI::Unit;

    attribute def TemperatureValue {
        attribute value : Real;
        attribute unit : String = "degC";
    }

    attribute def HumidityValue {
        attribute value : Real;
        attribute unit : String = "%";
    }

    attribute def IlluminanceValue {
        attribute value : Real;
        attribute unit : String = "lx";
    }

    attribute def PowerValue {
        attribute value : Real;
        attribute unit : String = "W";
    }

    attribute def EnergyValue {
        attribute value : Real;
        attribute unit : String = "kWh";
    }

    attribute def TimeValue {
        attribute value : Real;
        attribute unit : String = "s";
    }

    attribute def ConfidenceValue {
        attribute value : Real;
        unit = "%";
    }

    item def SensorReading {
        attribute timestamp : TimeValue;
        attribute sourceId : String;
        attribute confidence : ConfidenceValue;
    }

    item def OccupancyReading specializes SensorReading {
        attribute occupied : Boolean;
        attribute roomId : String;
        attribute occupantCount : Integer;
    }

    item def EnvironmentalReading specializes SensorReading {
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute illuminance : IlluminanceValue;
    }

    item def EnergyReading specializes SensorReading {
        attribute instantaneousPower : PowerValue;
        attribute cumulativeEnergy : EnergyValue;
        attribute circuitId : String;
    }

    item def UserIntent {
        attribute userId : String;
        attribute targetZone : String;
        attribute intentKind : IntentKind;
        attribute priority : PriorityLevel;
        attribute requestedValue : Real;
    }

    item def AutomationCommand {
        attribute targetDeviceId : String;
        attribute commandKind : CommandKind;
        attribute commandValue : Real;
        attribute issuedAt : TimeValue;
        attribute safetyChecked : Boolean;
    }

    item def AlertNotification {
        attribute alertKind : AlertKind;
        attribute severity : PriorityLevel;
        attribute location : String;
        attribute message : String;
        attribute createdAt : TimeValue;
    }

    enum def IntentKind {
        enum comfortTemperature;
        enum lightingScene;
        enum energySaving;
        enum accessibilityAssistance;
        enum securityMode;
        enum emergencyAssistance;
    }

    enum def CommandKind {
        enum switchOn;
        enum switchOff;
        enum setLevel;
        enum setTemperature;
        enum lock;
        enum unlock;
        enum open;
        enum close;
        enum notify;
    }

    enum def PriorityLevel {
        enum low;
        enum normal;
        enum high;
        enum critical;
    }

    enum def AlertKind {
        enum fallDetected;
        enum intrusion;
        enum smoke;
        enum excessivePowerUse;
        enum deviceFailure;
        enum unavailableService;
    }

    port def SensorDataOut {
        out item reading : SensorReading;
    }

    port def SensorDataIn {
        in item reading : SensorReading;
    }

    port def CommandOut {
        out item command : AutomationCommand;
    }

    port def CommandIn {
        in item command : AutomationCommand;
    }

    port def IntentIn {
        in item intent : UserIntent;
    }

    port def IntentOut {
        out item intent : UserIntent;
    }

    port def AlertOut {
        out item alert : AlertNotification;
    }

    port def AlertIn {
        in item alert : AlertNotification;
    }

    part def EnvironmentalSensor {
        attribute sensorId : String;
        attribute roomId : String;
        attribute samplePeriod : TimeValue;
        attribute isHealthy : Boolean;

        port dataOut : SensorDataOut;

        action senseEnvironment {
            out item reading : EnvironmentalReading;
        }
    }

    part def OccupancySensor {
        attribute sensorId : String;
        attribute roomId : String;
        attribute detectionRange : Real;
        attribute isHealthy : Boolean;

        port dataOut : SensorDataOut;

        action detectPresence {
            out item reading : OccupancyReading;
        }
    }

    part def SmartMeter {
        attribute meterId : String;
        attribute monitoredCircuit : String;
        attribute maximumRatedPower : PowerValue;

        port dataOut : SensorDataOut;

        action measureEnergy {
            out item reading : EnergyReading;
        }
    }

    part def LightingActuator {
        attribute deviceId : String;
        attribute roomId : String;
        attribute currentLevel : Real;
        attribute maximumPower : PowerValue;

        port commandIn : CommandIn;

        action applyLightingCommand {
            in item command : AutomationCommand;
        }
    }

    part def HvacActuator {
        attribute deviceId : String;
        attribute zoneId : String;
        attribute currentSetpoint : TemperatureValue;
        attribute ratedPower : PowerValue;

        port commandIn : CommandIn;

        action applyHvacCommand {
            in item command : AutomationCommand;
        }
    }

    part def DoorLockActuator {
        attribute deviceId : String;
        attribute entryPointId : String;
        attribute locked : Boolean;

        port commandIn : CommandIn;

        action applyLockCommand {
            in item command : AutomationCommand;
        }
    }

    part def UserInterface {
        attribute interfaceId : String;
        attribute supportsVoice : Boolean;
        attribute supportsTouch : Boolean;
        attribute supportsRemoteAccess : Boolean;

        port intentOut : IntentOut;
        port alertIn : AlertIn;

        action captureIntent {
            out item intent : UserIntent;
        }

        action presentAlert {
            in item alert : AlertNotification;
        }
    }

    part def ContextManager {
        attribute knownOccupants : Integer;
        attribute activeRoom : String;
        attribute homeOccupied : Boolean;
        attribute currentComfortScore : Real;

        port sensorIn : SensorDataIn;
        port contextCommandOut : CommandOut;
        port alertOut : AlertOut;

        action aggregateContext {
            in item reading : SensorReading;
        }

        action inferSituation {
            out item alert : AlertNotification;
        }
    }

    part def ServiceComposer {
        attribute activeServiceCount : Integer;
        attribute maximumDecisionLatency : TimeValue;
        attribute lastDecisionConfidence : ConfidenceValue;

        port sensorIn : SensorDataIn;
        port intentIn : IntentIn;
        port commandOut : CommandOut;
        port alertOut : AlertOut;

        action selectServices {
            in item intent : UserIntent;
            in item reading : SensorReading;
            out item command : AutomationCommand;
        }

        action optimizeComfortEnergySafety {
            out item command : AutomationCommand;
        }
    }

    part def SafetySupervisor {
        attribute emergencyMode : Boolean;
        attribute minimumAlertConfidence : ConfidenceValue;
        attribute failSafeEnabled : Boolean;

        port sensorIn : SensorDataIn;
        port commandIn : CommandIn;
        port safeCommandOut : CommandOut;
        port alertOut : AlertOut;

        action validateCommand {
            in item command : AutomationCommand;
            out item safeCommand : AutomationCommand;
        }

        action detectHazard {
            in item reading : SensorReading;
            out item alert : AlertNotification;
        }
    }

    part def HomeGateway {
        attribute gatewayId : String;
        attribute online : Boolean;
        attribute localAutonomyAvailable : Boolean;
        attribute cloudSyncEnabled : Boolean;

        port sensorIn : SensorDataIn;
        port commandOut : CommandOut;
        port alertOut : AlertOut;

        action routeSensorReading {
            in item reading : SensorReading;
        }

        action routeAutomationCommand {
            out item command : AutomationCommand;
        }
    }

    part def SM4AllSmartHomeSystem {
        attribute primaryFunction : String =
            "Provide adaptive, accessible, and energy-aware smart-home automation by sensing the home context, interpreting user intent, composing available device services, and safely controlling household actuators.";

        attribute maximumNormalDecisionLatency : TimeValue = (value = 2.0; unit = "s");
        attribute maximumCriticalAlertLatency : TimeValue = (value = 0.5; unit = "s");
        attribute targetEnergyReduction : Real = 15.0;
        attribute minimumAvailability : Real = 99.0;

        part gateway : HomeGateway {
            gatewayId = "SM4ALL-GW-01";
            online = true;
            localAutonomyAvailable = true;
            cloudSyncEnabled = true;
        }

        part contextManager : ContextManager;
        part serviceComposer : ServiceComposer;
        part safetySupervisor : SafetySupervisor;

        part livingRoomEnvironmentSensor : EnvironmentalSensor {
            sensorId = "ENV-LIVING-01";
            roomId = "livingRoom";
            samplePeriod = (value = 10.0; unit = "s");
            isHealthy = true;
        }

        part bedroomEnvironmentSensor : EnvironmentalSensor {
            sensorId = "ENV-BED-01";
            roomId = "bedroom";
            samplePeriod = (value = 10.0; unit = "s");
            isHealthy = true;
        }

        part livingRoomOccupancySensor : OccupancySensor {
            sensorId = "OCC-LIVING-01";
            roomId = "livingRoom";
            detectionRange = 7.0;
            isHealthy = true;
        }

        part bedroomOccupancySensor : OccupancySensor {
            sensorId = "OCC-BED-01";
            roomId = "bedroom";
            detectionRange = 5.0;
            isHealthy = true;
        }

        part wholeHomeMeter : SmartMeter {
            meterId = "MTR-MAIN-01";
            monitoredCircuit = "wholeHome";
            maximumRatedPower = (value = 12000.0; unit = "W");
        }

        part livingRoomLighting : LightingActuator {
            deviceId = "LIGHT-LIVING-01";
            roomId = "livingRoom";
            currentLevel = 0.0;
            maximumPower = (value = 80.0; unit = "W");
        }

        part bedroomLighting : LightingActuator {
            deviceId = "LIGHT-BED-01";
            roomId = "bedroom";
            currentLevel = 0.0;
            maximumPower = (value = 60.0; unit = "W");
        }

        part hvac : HvacActuator {
            deviceId = "HVAC-ZONE-01";
            zoneId = "mainZone";
            currentSetpoint = (value = 22.0; unit = "degC");
            ratedPower = (value = 3500.0; unit = "W");
        }

        part frontDoorLock : DoorLockActuator {
            deviceId = "LOCK-FRONT-01";
            entryPointId = "frontDoor";
            locked = true;
        }

        part residentInterface : UserInterface {
            interfaceId = "UI-RESIDENT-01";
            supportsVoice = true;
            supportsTouch = true;
            supportsRemoteAccess = true;
        }

        connect livingRoomEnvironmentSensor.dataOut to gateway.sensorIn;
        connect bedroomEnvironmentSensor.dataOut to gateway.sensorIn;
        connect livingRoomOccupancySensor.dataOut to gateway.sensorIn;
        connect bedroomOccupancySensor.dataOut to gateway.sensorIn;
        connect wholeHomeMeter.dataOut to gateway.sensorIn;

        connect gateway.sensorIn to contextManager.sensorIn;
        connect gateway.sensorIn to serviceComposer.sensorIn;
        connect gateway.sensorIn to safetySupervisor.sensorIn;

        connect residentInterface.intentOut to serviceComposer.intentIn;

        connect serviceComposer.commandOut to safetySupervisor.commandIn;
        connect contextManager.contextCommandOut to safetySupervisor.commandIn;
        connect safetySupervisor.safeCommandOut to gateway.commandOut;

        connect gateway.commandOut to livingRoomLighting.commandIn;
        connect gateway.commandOut to bedroomLighting.commandIn;
        connect gateway.commandOut to hvac.commandIn;
        connect gateway.commandOut to frontDoorLock.commandIn;

        connect contextManager.alertOut to residentInterface.alertIn;
        connect serviceComposer.alertOut to residentInterface.alertIn;
        connect safetySupervisor.alertOut to residentInterface.alertIn;
        connect gateway.alertOut to residentInterface.alertIn;
    }

    action def SenseInterpretAct {
        in item environmentalReading : EnvironmentalReading;
        in item occupancyReading : OccupancyReading;
        in item energyReading : EnergyReading;
        in item userIntent : UserIntent;
        out item automationCommand : AutomationCommand;
        out item alert : AlertNotification;

        action senseHomeContext;
        action interpretResidentNeed;
        action composeDeviceService;
        action checkSafetyPolicy;
        action dispatchCommand;

        first start;
        then senseHomeContext;
        then interpretResidentNeed;
        then composeDeviceService;
        then checkSafetyPolicy;
        then dispatchCommand;
        then done;
    }

    state def SM4AllOperationalStates {
        entry action initializeLocalServices;
        exit action persistContextSnapshot;

        state Offline {
            entry action disableRemoteControl;
        }

        state Starting {
            entry action discoverDevices;
            do action verifyServiceRegistry;
        }

        state NormalOperation {
            entry action enableAutomation;
            do action monitorContextAndIntent;

            state Idle {
                do action waitForSensorOrUserEvent;
            }

            state ContextUpdating {
                do action refreshOccupancyComfortAndEnergyState;
            }

            state ServiceComposing {
                do action selectBestAvailableService;
            }

            state Commanding {
                do action issueSafeAutomationCommand;
            }

            transition first Idle;
            transition Idle to ContextUpdating
                accept SensorReading;
            transition Idle to ServiceComposing
                accept UserIntent;
            transition ContextUpdating to ServiceComposing;
            transition ServiceComposing to Commanding;
            transition Commanding to Idle;
        }

        state EnergySaving {
            entry action reduceNonEssentialLoads;
            do action maintainMinimumComfort;
        }

        state EmergencyAssistance {
            entry action raiseCriticalAlert;
            do action unlockSafeExitIfPermitted;
            do action illuminateEscapePath;
        }

        transition first Starting;
        transition Starting to NormalOperation
            if serviceRegistryAvailable and essentialDevicesHealthy;
        transition Starting to Offline
            if not gatewayOnline;
        transition NormalOperation to EnergySaving
            if homeOccupied == false or excessivePowerUseDetected;
        transition EnergySaving to NormalOperation
            if residentComfortRequestReceived or homeOccupied == true;
        transition NormalOperation to EmergencyAssistance
            if criticalHazardDetected;
        transition EnergySaving to EmergencyAssistance
            if criticalHazardDetected;
        transition EmergencyAssistance to NormalOperation
            if hazardCleared and residentAcknowledged;
        transition NormalOperation to Offline
            if gatewayOnline == false and localAutonomyAvailable == false;
        transition Offline to Starting
            if gatewayOnline == true;
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /*
         * The SM4All smart-home system shall provide a high-level primary function
         * of adaptive home assistance by sensing environmental, occupancy, energy,
         * and user-intent information; composing suitable smart-device services;
         * and controlling home actuators to improve comfort, accessibility, safety,
         * and energy efficiency.
         */
    }

    requirement def ContextAwarenessRequirement {
        doc
        /*
         * The system shall maintain a current model of occupancy, environmental
         * comfort, and energy use for each monitored zone of the home.
         */
    }

    requirement def AccessibilityRequirement {
        doc
        /*
         * The system shall accept resident intent through accessible interfaces,
         * including voice, touch, and remote interaction where available.
         */
    }

    requirement def SafetyRequirement {
        doc
        /*
         * The system shall validate automation commands before dispatch and shall
         * override comfort or energy goals when a critical safety condition is detected.
         */
    }

    requirement def LatencyRequirement {
        attribute maximumNormalDecisionLatency : TimeValue = (value = 2.0; unit = "s");
        attribute maximumCriticalAlertLatency : TimeValue = (value = 0.5; unit = "s");

        doc
        /*
         * The system shall produce normal automation decisions within 2 seconds
         * and critical safety alerts within 0.5 seconds of receiving sufficient
         * sensor evidence.
         */
    }

    requirement def EnergyEfficiencyRequirement {
        attribute targetEnergyReduction : Real = 15.0;

        doc
        /*
         * The system shall reduce avoidable household energy use by at least
         * 15 percent compared with equivalent manual operation while maintaining
         * resident comfort and safety constraints.
         */
    }

    requirement def LocalAutonomyRequirement {
        doc
        /*
         * The system shall continue essential sensing, safety supervision, and
         * local automation when external network services are unavailable.
         */
    }

    satisfy PrimaryFunctionRequirement by SM4AllSmartHomeSystem;
    satisfy ContextAwarenessRequirement by ContextManager;
    satisfy AccessibilityRequirement by UserInterface;
    satisfy SafetyRequirement by SafetySupervisor;
    satisfy LatencyRequirement by ServiceComposer;
    satisfy EnergyEfficiencyRequirement by ServiceComposer;
    satisfy LocalAutonomyRequirement by HomeGateway;

    part sm4allHome : SM4AllSmartHomeSystem;

    perform SenseInterpretAct by sm4allHome;

}