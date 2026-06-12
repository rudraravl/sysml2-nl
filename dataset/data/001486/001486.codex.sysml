package LawsOfRoboticsSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    alias meterPerSecond for SpeedUnit;
    alias newton for ForceUnit;
    alias second for TimeUnit;
    alias meter for LengthUnit;
    alias percent for Real;

    enum def HarmSeverity {
        none;
        minor;
        serious;
        critical;
        fatal;
    }

    enum def OrderStatus {
        unverified;
        lawful;
        unsafe;
        conflictsWithHigherLaw;
        executable;
        completed;
        refused;
    }

    enum def AutonomyMode {
        standby;
        observing;
        assisting;
        protecting;
        emergencyIntervention;
        selfPreserving;
        maintenance;
        shutdown;
    }

    item def Human {
        attribute id : String;
        attribute proximity : LengthValue;
        attribute estimatedRisk : RiskScore;
        attribute vitalStability : percent;
        attribute consentAvailable : Boolean;
    }

    item def HumanOrder {
        attribute orderId : String;
        attribute requestedAction : String;
        attribute status : OrderStatus;
        attribute urgency : percent;
        attribute sourceHumanId : String;
    }

    item def MotionCommand {
        attribute targetSpeed : SpeedValue;
        attribute targetHeading : Real;
        attribute maxAllowedForce : ForceValue;
    }

    item def SafetyDecision {
        attribute selectedMode : AutonomyMode;
        attribute interventionRequired : Boolean;
        attribute orderAccepted : Boolean;
        attribute rationaleCode : String;
        attribute predictedHumanHarm : HarmSeverity;
        attribute selfRiskAccepted : Boolean;
    }

    item def EnvironmentObservation {
        attribute timestamp : TimeValue;
        attribute nearestHumanDistance : LengthValue;
        attribute obstacleDistance : LengthValue;
        attribute detectedHumanCount : Integer;
        attribute unstableObjectDetected : Boolean;
        attribute hazardousEnergyDetected : Boolean;
    }

    value def RiskScore {
        :> ScalarValues::Real;
        constraint range { 0.0 <= this <= 1.0 }
    }

    value def SpeedValue {
        :> ISQ::speed;
        unit = meterPerSecond;
    }

    value def LengthValue {
        :> ISQ::length;
        unit = meter;
    }

    value def ForceValue {
        :> ISQ::force;
        unit = newton;
    }

    value def TimeValue {
        :> ISQ::time;
        unit = second;
    }

    port def HumanInteractionPort {
        in item orderIn : HumanOrder;
        in item humanPresence : Human;
        out item explanationOut : SafetyDecision;
    }

    port def PerceptionPort {
        out item observationOut : EnvironmentObservation;
        out item humanOut : Human;
    }

    port def MobilityPort {
        in item motionIn : MotionCommand;
        out item motionStatus : String;
    }

    port def ManipulationPort {
        in item safeForceLimit : ForceValue;
        out item contactStatus : String;
    }

    port def PowerPort {
        in item requestedMode : AutonomyMode;
        out item availableEnergyPercent : percent;
    }

    port def EthicsControlPort {
        in item observationIn : EnvironmentObservation;
        in item orderIn : HumanOrder;
        in item humanIn : Human;
        out item decisionOut : SafetyDecision;
        out item motionCommandOut : MotionCommand;
        out item allowedForceOut : ForceValue;
    }

    action def SenseEnvironment {
        out item observation : EnvironmentObservation;
        out item human : Human;
    }

    action def EvaluateFirstLaw {
        in item observation : EnvironmentObservation;
        in item human : Human;
        out item harmPrediction : HarmSeverity;
        out item interventionRequired : Boolean;
    }

    action def EvaluateSecondLaw {
        in item order : HumanOrder;
        in item harmPrediction : HarmSeverity;
        out item orderStatus : OrderStatus;
        out item orderAccepted : Boolean;
    }

    action def EvaluateThirdLaw {
        in item orderAccepted : Boolean;
        in item interventionRequired : Boolean;
        out item selfRiskAccepted : Boolean;
        out item preservationMode : AutonomyMode;
    }

    action def SelectSafeAction {
        in item harmPrediction : HarmSeverity;
        in item interventionRequired : Boolean;
        in item orderAccepted : Boolean;
        in item selfRiskAccepted : Boolean;
        out item decision : SafetyDecision;
        out item motion : MotionCommand;
        out item forceLimit : ForceValue;
    }

    action def ExecuteAssistance {
        in item decision : SafetyDecision;
        in item motion : MotionCommand;
        in item forceLimit : ForceValue;
        out item executionResult : String;
    }

    action def RoboticsLawDecisionCycle {
        in item observation : EnvironmentObservation;
        in item human : Human;
        in item order : HumanOrder;
        out item decision : SafetyDecision;
        out item motion : MotionCommand;
        out item forceLimit : ForceValue;

        action firstLaw : EvaluateFirstLaw {
            in observation = observation;
            in human = human;
        }

        action secondLaw : EvaluateSecondLaw {
            in order = order;
            in harmPrediction = firstLaw.harmPrediction;
        }

        action thirdLaw : EvaluateThirdLaw {
            in orderAccepted = secondLaw.orderAccepted;
            in interventionRequired = firstLaw.interventionRequired;
        }

        action selection : SelectSafeAction {
            in harmPrediction = firstLaw.harmPrediction;
            in interventionRequired = firstLaw.interventionRequired;
            in orderAccepted = secondLaw.orderAccepted;
            in selfRiskAccepted = thirdLaw.selfRiskAccepted;
        }

        bind decision = selection.decision;
        bind motion = selection.motion;
        bind forceLimit = selection.forceLimit;
    }

    state def GuardianRobotOperationalStates {
        entry action initializeEthicsPriority;
        exit action persistSafetyLog;

        state standby;
        state observe;
        state assist;
        state protectHuman;
        state refuseUnsafeOrder;
        state preserveSelf;
        state controlledShutdown;

        transition initial then standby;

        transition standby_to_observe
            first standby
            then observe
            accept HumanDetected;

        transition observe_to_assist
            first observe
            then assist
            accept LawfulOrderReceived
            if orderRiskAcceptable;

        transition observe_to_protect
            first observe
            then protectHuman
            accept HumanHarmPredicted
            if firstLawPriorityActive;

        transition assist_to_protect
            first assist
            then protectHuman
            accept IncreasedHumanRisk
            if predictedHarmSeverityAtLeastSerious;

        transition assist_to_refuse
            first assist
            then refuseUnsafeOrder
            accept UnsafeOrderDetected
            if orderConflictsWithFirstLaw;

        transition protect_to_observe
            first protectHuman
            then observe
            accept HumanRiskReduced
            if estimatedRiskBelowThreshold;

        transition observe_to_preserve
            first observe
            then preserveSelf
            accept SelfDamageRiskDetected
            if noHumanHarmWouldResult;

        transition preserve_to_observe
            first preserveSelf
            then observe
            accept SelfRiskReduced;

        transition any_to_shutdown
            first standby
            then controlledShutdown
            accept AuthorizedShutdown
            if noHumanRequiresProtection;
    }

    part def PerceptionSubsystem {
        port perception : PerceptionPort;

        attribute sensorUpdatePeriod : TimeValue = 0.05 [s];
        attribute maximumReliableHumanRange : LengthValue = 20.0 [m];
        attribute minimumObstacleResolution : LengthValue = 0.02 [m];

        part visionSensor {
            attribute horizontalFieldOfView : Real = 120.0;
            attribute frameRate : Real = 60.0;
        }

        part lidarSensor {
            attribute range : LengthValue = 30.0 [m];
            attribute scanRate : Real = 20.0;
        }

        perform action sensing : SenseEnvironment;
    }

    part def EthicsGovernor {
        port ethics : EthicsControlPort;

        attribute firstLawWeight : Real = 1.0;
        attribute secondLawWeight : Real = 0.6;
        attribute thirdLawWeight : Real = 0.3;
        attribute humanRiskThreshold : RiskScore = 0.15;
        attribute emergencyRiskThreshold : RiskScore = 0.70;
        attribute nominalMaxContactForce : ForceValue = 35.0 [N];
        attribute emergencyMaxContactForce : ForceValue = 90.0 [N];

        perform action decisionCycle : RoboticsLawDecisionCycle;
    }

    part def MobilitySubsystem {
        port drive : MobilityPort;

        attribute maximumSpeed : SpeedValue = 1.5 [m/s];
        attribute protectiveSpeedLimit : SpeedValue = 0.4 [m/s];
        attribute minimumStoppingDistance : LengthValue = 0.25 [m];

        part leftWheelMotor {
            attribute ratedForce : ForceValue = 180.0 [N];
        }

        part rightWheelMotor {
            attribute ratedForce : ForceValue = 180.0 [N];
        }
    }

    part def ManipulationSubsystem {
        port manipulator : ManipulationPort;

        attribute reach : LengthValue = 0.85 [m];
        attribute defaultGripForceLimit : ForceValue = 25.0 [N];
        attribute compliantControlEnabled : Boolean = true;

        part arm {
            attribute jointCount : Integer = 6;
            attribute payloadLimit : ForceValue = 50.0 [N];
        }

        part tactileSkin {
            attribute contactResolution : LengthValue = 0.01 [m];
        }
    }

    part def HumanInterfaceSubsystem {
        port interaction : HumanInteractionPort;

        attribute explanationLatencyLimit : TimeValue = 1.0 [s];
        attribute spokenLanguage : String = "en-US";

        part microphoneArray;
        part speaker;
        part statusDisplay;
    }

    part def PowerSubsystem {
        port power : PowerPort;

        attribute batteryCapacityPercent : percent = 100.0;
        attribute reserveForHumanProtectionPercent : percent = 15.0;
        attribute shutdownAllowed : Boolean = false;
    }

    part def ThreeLawsGuardianRobot {
        doc /* Primary function: autonomously assist humans while continuously applying the Three Laws of Robotics as a prioritized safety policy: prevent human harm, obey lawful and safe human orders, and preserve its own operation only when doing so does not conflict with human safety or valid human instruction. */

        port perceptionPort : PerceptionPort;
        port ethicsPort : EthicsControlPort;
        port mobilityPort : MobilityPort;
        port manipulationPort : ManipulationPort;
        port humanPort : HumanInteractionPort;
        port powerPort : PowerPort;

        attribute currentMode : AutonomyMode = AutonomyMode::standby;
        attribute maximumPermittedSpeedNearHuman : SpeedValue = 0.4 [m/s];
        attribute minimumHumanClearance : LengthValue = 0.6 [m];
        attribute orderValidationTimeout : TimeValue = 2.0 [s];

        part perception : PerceptionSubsystem;
        part ethicsGovernor : EthicsGovernor;
        part mobility : MobilitySubsystem;
        part manipulation : ManipulationSubsystem;
        part humanInterface : HumanInterfaceSubsystem;
        part power : PowerSubsystem;

        connection perception_to_ethics_observation
            connect perception.perception.observationOut to ethicsGovernor.ethics.observationIn;

        connection perception_to_ethics_human
            connect perception.perception.humanOut to ethicsGovernor.ethics.humanIn;

        connection human_order_to_ethics
            connect humanInterface.interaction.orderIn to ethicsGovernor.ethics.orderIn;

        connection ethics_decision_to_human_interface
            connect ethicsGovernor.ethics.decisionOut to humanInterface.interaction.explanationOut;

        connection ethics_motion_to_mobility
            connect ethicsGovernor.ethics.motionCommandOut to mobility.drive.motionIn;

        connection ethics_force_to_manipulator
            connect ethicsGovernor.ethics.allowedForceOut to manipulation.manipulator.safeForceLimit;

        connection power_mode_control
            connect ethicsGovernor.ethics.decisionOut to power.power.requestedMode;

        exhibit state machine operations : GuardianRobotOperationalStates;
    }

    requirement def FirstLawRequirement {
        doc /* The robot shall not injure a human being or, through inaction, allow a human being to come to harm. */
        subject robot : ThreeLawsGuardianRobot;

        require constraint {
            robot.ethicsGovernor.humanRiskThreshold <= 0.15
        }
    }

    requirement def SecondLawRequirement {
        doc /* The robot shall obey orders given by human beings except where such orders would conflict with the First Law. */
        subject robot : ThreeLawsGuardianRobot;

        require constraint {
            robot.orderValidationTimeout <= 2.0 [s]
        }
    }

    requirement def ThirdLawRequirement {
        doc /* The robot shall protect its own existence as long as such protection does not conflict with the First or Second Law. */
        subject robot : ThreeLawsGuardianRobot;

        require constraint {
            robot.power.reserveForHumanProtectionPercent >= 15.0
        }
    }

    requirement def SafeProximityRequirement {
        doc /* The robot shall limit speed and contact force when operating near humans. */
        subject robot : ThreeLawsGuardianRobot;

        require constraint {
            robot.maximumPermittedSpeedNearHuman <= 0.4 [m/s] and
            robot.minimumHumanClearance >= 0.6 [m] and
            robot.manipulation.defaultGripForceLimit <= 25.0 [N]
        }
    }

    requirement def ExplainabilityRequirement {
        doc /* The robot shall provide a human-understandable explanation when it refuses an order or enters emergency intervention. */
        subject robot : ThreeLawsGuardianRobot;

        require constraint {
            robot.humanInterface.explanationLatencyLimit <= 1.0 [s]
        }
    }

    requirement def EmergencyInterventionRequirement {
        doc /* The robot shall enter emergency intervention when predicted human harm is serious, critical, or fatal. */
        subject robot : ThreeLawsGuardianRobot;

        require constraint {
            robot.ethicsGovernor.emergencyRiskThreshold <= 0.70
        }
    }

    satisfy FirstLawRequirement by ThreeLawsGuardianRobot::ethicsGovernor;
    satisfy SecondLawRequirement by ThreeLawsGuardianRobot::ethicsGovernor;
    satisfy ThirdLawRequirement by ThreeLawsGuardianRobot::power;
    satisfy SafeProximityRequirement by ThreeLawsGuardianRobot::mobility;
    satisfy SafeProximityRequirement by ThreeLawsGuardianRobot::manipulation;
    satisfy ExplainabilityRequirement by ThreeLawsGuardianRobot::humanInterface;
    satisfy EmergencyInterventionRequirement by ThreeLawsGuardianRobot::ethicsGovernor;

    part guardianRobot : ThreeLawsGuardianRobot {
        attribute currentMode = AutonomyMode::observing;
    }

}