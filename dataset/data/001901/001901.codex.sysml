package RobonautMissionSupportSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percent : Real {
        unit = "%";
    }

    attribute def NewtonMeter : Real {
        unit = "N*m";
    }

    attribute def Newton : Real {
        unit = "N";
    }

    attribute def WattHour : Real {
        unit = "W*h";
    }

    attribute def Degree : Real {
        unit = "deg";
    }

    attribute def MeterPerSecond : Real {
        unit = "m/s";
    }

    attribute def Millimeter : Real {
        unit = "mm";
    }

    attribute def Kilogram : Real {
        unit = "kg";
    }

    item def PowerFlow {
        attribute voltage : Volt;
        attribute current : Ampere;
        attribute availableEnergy : WattHour;
    }

    item def CommandPacket {
        attribute commandId : Integer;
        attribute priority : Integer;
        attribute targetSubsystem : String;
        attribute issuedTime : Real;
    }

    item def TelemetryPacket {
        attribute robotMode : String;
        attribute batteryStateOfCharge : Percent;
        attribute internalTemperature : Celsius;
        attribute faultCount : Integer;
    }

    item def VideoFrame {
        attribute widthPixels : Integer;
        attribute heightPixels : Integer;
        attribute frameRate : Real;
        attribute compressionType : String;
    }

    item def ForceTorqueSample {
        attribute forceX : Newton;
        attribute forceY : Newton;
        attribute forceZ : Newton;
        attribute torqueX : NewtonMeter;
        attribute torqueY : NewtonMeter;
        attribute torqueZ : NewtonMeter;
    }

    item def Tool {
        attribute toolId : String;
        attribute mass : Kilogram;
        attribute requiredGripForce : Newton;
        attribute interfaceType : String;
    }

    item def TaskPlan {
        attribute taskId : String;
        attribute objective : String;
        attribute maximumDuration : Second;
        attribute requiredToolId : String;
        attribute humanApprovalRequired : Boolean;
    }

    port def PowerPort {
        in item powerIn : PowerFlow;
        out item powerStatus : TelemetryPacket;
    }

    port def DataPort {
        in item command : CommandPacket;
        out item telemetry : TelemetryPacket;
        out item video : VideoFrame;
    }

    port def ManipulatorPort {
        in item desiredForce : ForceTorqueSample;
        out item measuredForce : ForceTorqueSample;
        inout item handledTool : Tool;
    }

    port def MobilityPort {
        in attribute commandedVelocity : MeterPerSecond;
        out attribute measuredVelocity : MeterPerSecond;
        out attribute positionError : Millimeter;
    }

    port def ThermalPort {
        in attribute heatLoad : Watt;
        out attribute temperature : Celsius;
    }

    action def InterpretMissionCommand {
        in item command : CommandPacket;
        out item plan : TaskPlan;
    }

    action def AcquireTool {
        in item plan : TaskPlan;
        inout item selectedTool : Tool;
        out attribute graspVerified : Boolean;
    }

    action def PerformDexterousMaintenance {
        in item plan : TaskPlan;
        in item forceFeedback : ForceTorqueSample;
        out attribute taskComplete : Boolean;
        out attribute taskQuality : Percent;
    }

    action def StreamOperatorAwareness {
        in item telemetry : TelemetryPacket;
        in item video : VideoFrame;
        out attribute operatorSituationalAwareness : Percent;
    }

    action def ExecuteFaultRecovery {
        in item telemetry : TelemetryPacket;
        out attribute recovered : Boolean;
        out attribute safeModeRequired : Boolean;
    }

    state def RobonautOperatingState {
        entry action InitializeRobonaut;
        state PoweredOff;
        state Startup;
        state Standby;
        state ReceivingTask;
        state Planning;
        state ToolAcquisition;
        state TaskExecution;
        state Reporting;
        state FaultRecovery;
        state SafeMode;
        state Shutdown;

        transition first PoweredOff;
        transition PoweredOff_to_Startup
            first PoweredOff then Startup
            accept CommandPacket
            if command.targetSubsystem == "RobonautCore";

        transition Startup_to_Standby
            first Startup then Standby
            if selfCheckPassed == true;

        transition Startup_to_SafeMode
            first Startup then SafeMode
            if selfCheckPassed == false;

        transition Standby_to_ReceivingTask
            first Standby then ReceivingTask
            accept CommandPacket
            if command.priority >= 1;

        transition ReceivingTask_to_Planning
            first ReceivingTask then Planning;

        transition Planning_to_ToolAcquisition
            first Planning then ToolAcquisition
            if requiredToolAvailable == true;

        transition Planning_to_Reporting
            first Planning then Reporting
            if requiredToolAvailable == false;

        transition ToolAcquisition_to_TaskExecution
            first ToolAcquisition then TaskExecution
            if graspVerified == true;

        transition ToolAcquisition_to_FaultRecovery
            first ToolAcquisition then FaultRecovery
            if graspVerified == false;

        transition TaskExecution_to_Reporting
            first TaskExecution then Reporting
            if taskComplete == true;

        transition TaskExecution_to_FaultRecovery
            first TaskExecution then FaultRecovery
            if faultDetected == true;

        transition Reporting_to_Standby
            first Reporting then Standby;

        transition FaultRecovery_to_TaskExecution
            first FaultRecovery then TaskExecution
            if recovered == true and safeModeRequired == false;

        transition FaultRecovery_to_SafeMode
            first FaultRecovery then SafeMode
            if safeModeRequired == true;

        transition Standby_to_Shutdown
            first Standby then Shutdown
            accept CommandPacket
            if command.commandId == 900;

        transition Shutdown_to_PoweredOff
            first Shutdown then PoweredOff;
    }

    part def BatteryModule {
        attribute capacity : WattHour = 1200 [W*h];
        attribute stateOfCharge : Percent;
        attribute nominalVoltage : Volt = 48 [V];
        attribute maximumContinuousPower : Watt = 850 [W];

        port powerOutput : PowerPort;
    }

    part def PowerManagementUnit {
        attribute conversionEfficiency : Percent = 94 [%];
        attribute regulatedBusVoltage : Volt = 48 [V];
        attribute emergencyReserveEnergy : WattHour = 180 [W*h];

        port batteryInput : PowerPort;
        port avionicsOutput : PowerPort;
        port actuatorOutput : PowerPort;
        port sensorOutput : PowerPort;
    }

    part def CommunicationsModule {
        attribute uplinkRate : Real = 4.0;
        attribute downlinkRate : Real = 25.0;
        attribute commandLatency : Second;
        attribute encryptionEnabled : Boolean = true;

        port operatorLink : DataPort;
        port robotDataBus : DataPort;
    }

    part def VisionSystem {
        attribute stereoBaseline : Millimeter = 75 [mm];
        attribute fieldOfView : Degree = 110 [deg];
        attribute minimumIllumination : Real = 0.5;
        attribute depthAccuracy : Millimeter = 3 [mm];

        port data : DataPort;
        port power : PowerPort;
        port thermal : ThermalPort;
    }

    part def ForceTorqueSensor {
        attribute forceRange : Newton = 300 [N];
        attribute torqueRange : NewtonMeter = 40 [N*m];
        attribute sampleRate : Real = 1000.0;

        port measurement : ManipulatorPort;
        port power : PowerPort;
    }

    part def DexterousHand {
        attribute fingerCount : Integer = 5;
        attribute gripForce : Newton = 125 [N];
        attribute tactileSensorCount : Integer = 96;
        attribute minimumObjectDiameter : Millimeter = 8 [mm];

        port manipulation : ManipulatorPort;
        port power : PowerPort;
    }

    part def ArmAssembly {
        attribute degreesOfFreedom : Integer = 7;
        attribute reach : Millimeter = 850 [mm];
        attribute payloadCapacity : Kilogram = 9 [kg];
        attribute jointTorqueLimit : NewtonMeter = 120 [N*m];
        attribute positioningAccuracy : Millimeter = 2 [mm];

        part hand : DexterousHand;
        part wristSensor : ForceTorqueSensor;

        port manipulation : ManipulatorPort;
        port power : PowerPort;
        port thermal : ThermalPort;

        connect manipulation to hand.manipulation;
        connect hand.manipulation to wristSensor.measurement;
    }

    part def MobilityBase {
        attribute maximumTranslationSpeed : MeterPerSecond = 0.25 [m/s];
        attribute stationKeepingAccuracy : Millimeter = 10 [mm];
        attribute dockingForceLimit : Newton = 80 [N];

        port motion : MobilityPort;
        port power : PowerPort;
        port data : DataPort;
    }

    part def ToolStorageRack {
        attribute toolCapacity : Integer = 12;
        attribute retainedToolCount : Integer;
        attribute toolRetentionForce : Newton = 60 [N];

        port toolInterface : ManipulatorPort;
        port data : DataPort;
    }

    part def OnboardComputer {
        attribute processorHealth : Percent;
        attribute memoryUtilization : Percent;
        attribute autonomyLevel : Integer = 3;
        attribute faultToleranceMode : String = "degraded-operation-capable";

        port commandAndTelemetry : DataPort;
        port sensorBus : DataPort;
        port actuatorBus : DataPort;
        port power : PowerPort;

        perform action interpretCommand : InterpretMissionCommand;
        perform action streamAwareness : StreamOperatorAwareness;
        perform action recoverFault : ExecuteFaultRecovery;
    }

    part def ThermalControlSystem {
        attribute maximumAllowedAvionicsTemperature : Celsius = 65 [degC];
        attribute maximumAllowedActuatorTemperature : Celsius = 80 [degC];
        attribute radiatorCapacity : Watt = 450 [W];

        port avionicsThermal : ThermalPort;
        port actuatorThermal : ThermalPort;
        port sensorThermal : ThermalPort;
    }

    part def Robonaut {
        doc /* Primary function: the Robonaut is a humanoid robotic assistant that performs dexterous inspection, tool handling, and maintenance tasks in hazardous or constrained environments while supervised by a human operator. */

        attribute height : Millimeter = 1500 [mm];
        attribute mass : Kilogram = 145 [kg];
        attribute nominalOperatingDuration : Second = 14400 [s];
        attribute minimumBatteryForTaskStart : Percent = 35 [%];
        attribute maximumExternalContactForce : Newton = 150 [N];

        part battery : BatteryModule;
        part powerManagement : PowerManagementUnit;
        part communications : CommunicationsModule;
        part computer : OnboardComputer;
        part vision : VisionSystem;
        part leftArm : ArmAssembly;
        part rightArm : ArmAssembly;
        part mobilityBase : MobilityBase;
        part toolRack : ToolStorageRack;
        part thermalControl : ThermalControlSystem;

        port externalPower : PowerPort;
        port operatorNetwork : DataPort;
        port leftManipulator : ManipulatorPort;
        port rightManipulator : ManipulatorPort;
        port mobility : MobilityPort;

        exhibit state operatingState : RobonautOperatingState;

        perform action missionCommandInterpretation : InterpretMissionCommand;
        perform action toolAcquisition : AcquireTool;
        perform action maintenanceExecution : PerformDexterousMaintenance;
        perform action awarenessStreaming : StreamOperatorAwareness;
        perform action faultRecovery : ExecuteFaultRecovery;

        connect externalPower to powerManagement.batteryInput;
        connect battery.powerOutput to powerManagement.batteryInput;
        connect powerManagement.avionicsOutput to computer.power;
        connect powerManagement.sensorOutput to vision.power;
        connect powerManagement.actuatorOutput to leftArm.power;
        connect powerManagement.actuatorOutput to rightArm.power;
        connect powerManagement.actuatorOutput to mobilityBase.power;

        connect operatorNetwork to communications.operatorLink;
        connect communications.robotDataBus to computer.commandAndTelemetry;
        connect computer.sensorBus to vision.data;
        connect computer.actuatorBus to mobilityBase.data;
        connect computer.actuatorBus to toolRack.data;

        connect leftManipulator to leftArm.manipulation;
        connect rightManipulator to rightArm.manipulation;
        connect leftArm.hand.manipulation to toolRack.toolInterface;
        connect rightArm.hand.manipulation to toolRack.toolInterface;
        connect mobility to mobilityBase.motion;

        connect vision.thermal to thermalControl.sensorThermal;
        connect computer.power.powerStatus to communications.robotDataBus.telemetry;
        connect leftArm.thermal to thermalControl.actuatorThermal;
        connect rightArm.thermal to thermalControl.actuatorThermal;
    }

    requirement def PrimaryFunctionRequirement {
        subject robonaut : Robonaut;
        require constraint {
            robonaut.computer.autonomyLevel >= 3
        }
        doc /* The system shall provide a humanoid robotic assistant capable of receiving supervised task commands, interpreting them into executable plans, manipulating tools with two dexterous arms, and returning telemetry and video to the operator. */
    }

    requirement def DexterousManipulationRequirement {
        subject robonaut : Robonaut;
        require constraint {
            robonaut.leftArm.degreesOfFreedom >= 7 and
            robonaut.rightArm.degreesOfFreedom >= 7 and
            robonaut.leftArm.hand.fingerCount == 5 and
            robonaut.rightArm.hand.fingerCount == 5 and
            robonaut.leftArm.positioningAccuracy <= 2 [mm] and
            robonaut.rightArm.positioningAccuracy <= 2 [mm]
        }
        doc /* The Robonaut shall manipulate human-compatible tools and service interfaces using two anthropomorphic arms with high positional accuracy. */
    }

    requirement def OperatorAwarenessRequirement {
        subject robonaut : Robonaut;
        require constraint {
            robonaut.vision.fieldOfView >= 100 [deg] and
            robonaut.communications.downlinkRate >= 20.0
        }
        doc /* The Robonaut shall provide live video, depth perception data, health telemetry, and task status sufficient for remote operator supervision. */
    }

    requirement def EnergyRequirement {
        subject robonaut : Robonaut;
        require constraint {
            robonaut.battery.capacity >= 1000 [W*h] and
            robonaut.minimumBatteryForTaskStart >= 30 [%] and
            robonaut.powerManagement.emergencyReserveEnergy >= 150 [W*h]
        }
        doc /* The Robonaut shall sustain nominal supervised operation and maintain a protected energy reserve for safe shutdown or retreat. */
    }

    requirement def SafetyRequirement {
        subject robonaut : Robonaut;
        require constraint {
            robonaut.maximumExternalContactForce <= 150 [N] and
            robonaut.thermalControl.maximumAllowedActuatorTemperature <= 80 [degC]
        }
        doc /* The Robonaut shall limit contact force and thermal exposure to protect crew, equipment, and itself during close-proximity work. */
    }

    requirement def FaultRecoveryRequirement {
        subject robonaut : Robonaut;
        require constraint {
            robonaut.computer.faultToleranceMode == "degraded-operation-capable"
        }
        doc /* The Robonaut shall detect subsystem faults, attempt autonomous recovery, and enter safe mode when continued task execution is unsafe. */
    }

    requirement def MobilityRequirement {
        subject robonaut : Robonaut;
        require constraint {
            robonaut.mobilityBase.maximumTranslationSpeed <= 0.25 [m/s] and
            robonaut.mobilityBase.stationKeepingAccuracy <= 10 [mm]
        }
        doc /* The Robonaut shall reposition slowly and accurately near worksites while maintaining stable alignment for manipulation. */
    }

    satisfy PrimaryFunctionRequirement by Robonaut;
    satisfy DexterousManipulationRequirement by Robonaut::leftArm;
    satisfy DexterousManipulationRequirement by Robonaut::rightArm;
    satisfy OperatorAwarenessRequirement by Robonaut::communications;
    satisfy OperatorAwarenessRequirement by Robonaut::vision;
    satisfy EnergyRequirement by Robonaut::battery;
    satisfy EnergyRequirement by Robonaut::powerManagement;
    satisfy SafetyRequirement by Robonaut;
    satisfy FaultRecoveryRequirement by Robonaut::computer;
    satisfy MobilityRequirement by Robonaut::mobilityBase;

    part missionRobonaut : Robonaut {
        attribute height = 1500 [mm];
        attribute mass = 145 [kg];
        attribute nominalOperatingDuration = 14400 [s];
        attribute minimumBatteryForTaskStart = 35 [%];
        attribute maximumExternalContactForce = 150 [N];

        part battery {
            attribute capacity = 1200 [W*h];
            attribute stateOfCharge = 100 [%];
            attribute nominalVoltage = 48 [V];
            attribute maximumContinuousPower = 850 [W];
        }

        part toolRack {
            attribute toolCapacity = 12;
            attribute retainedToolCount = 8;
            attribute toolRetentionForce = 60 [N];
        }

        part computer {
            attribute processorHealth = 100 [%];
            attribute memoryUtilization = 22 [%];
            attribute autonomyLevel = 3;
            attribute faultToleranceMode = "degraded-operation-capable";
        }
    }
}