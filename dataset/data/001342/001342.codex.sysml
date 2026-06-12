package AnthropomorphicSupportSystemModel {
    import ScalarValues::*;
    import SI::*;

    attribute def Percent : Real {
        doc /* Unitless percentage from 0.0 to 100.0. */
    }

    attribute def BatteryEnergy {
        :> ISQ::energy;
        unit = SI::wattHour;
    }

    attribute def Power {
        :> ISQ::power;
        unit = SI::watt;
    }

    attribute def Distance {
        :> ISQ::length;
        unit = SI::meter;
    }

    attribute def Speed {
        :> ISQ::speed;
        unit = SI::meterPerSecond;
    }

    attribute def Angle {
        :> ISQ::planeAngle;
        unit = SI::degree;
    }

    attribute def Force {
        :> ISQ::force;
        unit = SI::newton;
    }

    attribute def DataRate {
        :> ISQ::dataRate;
        unit = SI::megabitPerSecond;
    }

    item def VoiceCommand {
        attribute utterance : String;
        attribute confidence : Percent;
        attribute languageCode : String;
    }

    item def GestureCommand {
        attribute gestureName : String;
        attribute confidence : Percent;
    }

    item def TaskPlan {
        attribute taskId : String;
        attribute goalDescription : String;
        attribute priority : Integer;
    }

    item def EnvironmentMap {
        attribute mapId : String;
        attribute resolution : Distance;
        attribute freshnessSeconds : Real;
    }

    item def ManipulatedObject {
        attribute objectId : String;
        attribute mass : ISQ::mass;
        attribute gripWidth : Distance;
        attribute fragile : Boolean;
    }

    item def StatusReport {
        attribute mode : String;
        attribute batteryStateOfCharge : Percent;
        attribute faultActive : Boolean;
        attribute currentTaskId : String;
    }

    port def HumanInteractionPort {
        in voice : VoiceCommand;
        in gesture : GestureCommand;
        out speech : String;
        out status : StatusReport;
    }

    port def MobilityPowerPort {
        in suppliedPower : Power;
        out consumedPower : Power;
    }

    port def DataPort {
        in taskPlan : TaskPlan;
        in mapUpdate : EnvironmentMap;
        out statusReport : StatusReport;
        out localMap : EnvironmentMap;
    }

    port def ObjectHandlingPort {
        in objectToHandle : ManipulatedObject;
        out graspForce : Force;
        out handlingComplete : Boolean;
    }

    port def SensorPort {
        out detectedMap : EnvironmentMap;
        out detectedObject : ManipulatedObject;
        out humanDistance : Distance;
    }

    part def AnthropomorphicSupportRobot {
        doc /* Primary function: assist people in human-centered spaces by perceiving the environment, communicating naturally, moving safely, and manipulating everyday objects using a human-like body layout. */

        attribute height : Distance = 1.65 [SI::meter];
        attribute mass : ISQ::mass = 72 [SI::kilogram];
        attribute maxWalkingSpeed : Speed = 1.2 [SI::meterPerSecond];
        attribute normalReach : Distance = 0.75 [SI::meter];
        attribute ratedLiftMass : ISQ::mass = 5 [SI::kilogram];
        attribute nominalBatteryEnergy : BatteryEnergy = 1800 [SI::wattHour];
        attribute operatingTime : ISQ::time = 6 [SI::hour];

        port humanInterface : HumanInteractionPort;
        port missionData : DataPort;
        port handlingInterface : ObjectHandlingPort;

        part torso : TorsoAssembly;
        part head : HeadAssembly;
        part leftArm : ArmAssembly {
            attribute side : String = "left";
        }
        part rightArm : ArmAssembly {
            attribute side : String = "right";
        }
        part leftHand : DexterousHand {
            attribute side : String = "left";
        }
        part rightHand : DexterousHand {
            attribute side : String = "right";
        }
        part leftLeg : LegAssembly {
            attribute side : String = "left";
        }
        part rightLeg : LegAssembly {
            attribute side : String = "right";
        }
        part balanceController : BalanceController;
        part taskController : CognitiveTaskController;
        part powerSystem : PowerSystem;
        part safetySupervisor : SafetySupervisor;

        connect humanInterface to head.userPort;
        connect missionData to taskController.dataPort;
        connect handlingInterface to taskController.handlingPort;
        connect taskController.motionCommandPort to balanceController.motionRequestPort;
        connect balanceController.leftLegPort to leftLeg.controlPort;
        connect balanceController.rightLegPort to rightLeg.controlPort;
        connect taskController.leftArmPort to leftArm.controlPort;
        connect taskController.rightArmPort to rightArm.controlPort;
        connect leftArm.handPort to leftHand.wristPort;
        connect rightArm.handPort to rightHand.wristPort;
        connect powerSystem.torsoPowerPort to torso.powerPort;
        connect powerSystem.headPowerPort to head.powerPort;
        connect powerSystem.leftArmPowerPort to leftArm.powerPort;
        connect powerSystem.rightArmPowerPort to rightArm.powerPort;
        connect powerSystem.leftLegPowerPort to leftLeg.powerPort;
        connect powerSystem.rightLegPowerPort to rightLeg.powerPort;
        connect safetySupervisor.statusPort to taskController.safetyStatusPort;
        connect head.sensorPort to taskController.perceptionPort;

        state def OperationalStateMachine {
            entry action initialize {
                out report : StatusReport;
            }

            state Off;
            state Booting;
            state Idle;
            state Listening;
            state Planning;
            state Navigating;
            state Manipulating;
            state Speaking;
            state Charging;
            state Fault;

            transition first Off;
            transition Off_to_Booting from Off to Booting
                accept VoiceCommand
                if voice.utterance == "wake up";
            transition Booting_to_Idle from Booting to Idle;
            transition Idle_to_Listening from Idle to Listening
                accept VoiceCommand;
            transition Listening_to_Planning from Listening to Planning
                if voice.confidence >= 85.0;
            transition Planning_to_Navigating from Planning to Navigating
                if taskController.requiresLocomotion == true;
            transition Planning_to_Manipulating from Planning to Manipulating
                if taskController.requiresManipulation == true;
            transition Navigating_to_Manipulating from Navigating to Manipulating
                if taskController.atTargetLocation == true;
            transition Manipulating_to_Speaking from Manipulating to Speaking
                if taskController.taskComplete == true;
            transition Speaking_to_Idle from Speaking to Idle;
            transition Idle_to_Charging from Idle to Charging
                if powerSystem.stateOfCharge < 20.0;
            transition Charging_to_Idle from Charging to Idle
                if powerSystem.stateOfCharge >= 95.0;
            transition any_to_Fault from Off, Booting, Idle, Listening, Planning, Navigating, Manipulating, Speaking, Charging to Fault
                if safetySupervisor.emergencyStopActive == true;
            transition Fault_to_Idle from Fault to Idle
                if safetySupervisor.faultCleared == true;
        }

        action def ExecuteAssistanceTask {
            in command : VoiceCommand;
            in environment : EnvironmentMap;
            out report : StatusReport;

            action interpretCommand {
                in command : VoiceCommand;
                out taskPlan : TaskPlan;
            }

            action assessScene {
                in environment : EnvironmentMap;
                out safeMap : EnvironmentMap;
            }

            action navigateToGoal {
                in safeMap : EnvironmentMap;
                in taskPlan : TaskPlan;
                out arrived : Boolean;
            }

            action manipulateObject {
                in taskPlan : TaskPlan;
                out complete : Boolean;
            }

            action communicateResult {
                in complete : Boolean;
                out report : StatusReport;
            }

            flow command to interpretCommand.command;
            flow environment to assessScene.environment;
            flow interpretCommand.taskPlan to navigateToGoal.taskPlan;
            flow assessScene.safeMap to navigateToGoal.safeMap;
            flow navigateToGoal.arrived to manipulateObject.complete;
            flow manipulateObject.complete to communicateResult.complete;
            flow communicateResult.report to report;
        }
    }

    part def HeadAssembly {
        attribute panRange : Angle = 160 [SI::degree];
        attribute tiltRange : Angle = 90 [SI::degree];

        port userPort : HumanInteractionPort;
        port sensorPort : SensorPort;
        port powerPort : MobilityPowerPort;

        part stereoCamera : VisionSensor;
        part microphoneArray : AudioSensor;
        part speaker : SpeechEmitter;
        part neckActuator : RotaryActuator;

        connect stereoCamera.sensorOut to sensorPort;
        connect microphoneArray.userIn to userPort;
        connect speaker.userOut to userPort;
    }

    part def TorsoAssembly {
        attribute payloadMountCapacity : ISQ::mass = 10 [SI::kilogram];
        port powerPort : MobilityPowerPort;
        part inertialMeasurementUnit : InertialSensor;
        part spineActuator : RotaryActuator;
    }

    part def ArmAssembly {
        attribute side : String;
        attribute shoulderYawRange : Angle = 180 [SI::degree];
        attribute elbowRange : Angle = 145 [SI::degree];
        attribute maxEndpointForce : Force = 120 [SI::newton];

        port controlPort : DataPort;
        port powerPort : MobilityPowerPort;
        port handPort : DataPort;

        part shoulder : RotaryActuator;
        part elbow : RotaryActuator;
        part wrist : RotaryActuator;
        part jointTorqueSensor : ForceSensor;
    }

    part def DexterousHand {
        attribute side : String;
        attribute fingerCount : Integer = 5;
        attribute maximumGripForce : Force = 80 [SI::newton];
        attribute minimumGripWidth : Distance = 0.01 [SI::meter];
        attribute maximumGripWidth : Distance = 0.12 [SI::meter];

        port wristPort : DataPort;
        port handlingPort : ObjectHandlingPort;

        part thumbActuator : LinearActuator;
        part indexActuator : LinearActuator;
        part middleActuator : LinearActuator;
        part ringActuator : LinearActuator;
        part littleActuator : LinearActuator;
        part tactileArray : ForceSensor;
    }

    part def LegAssembly {
        attribute side : String;
        attribute strideLength : Distance = 0.62 [SI::meter];
        attribute kneeRange : Angle = 135 [SI::degree];

        port controlPort : DataPort;
        port powerPort : MobilityPowerPort;

        part hip : RotaryActuator;
        part knee : RotaryActuator;
        part ankle : RotaryActuator;
        part footPressureSensor : ForceSensor;
    }

    part def CognitiveTaskController {
        attribute processorLoad : Percent;
        attribute requiresLocomotion : Boolean;
        attribute requiresManipulation : Boolean;
        attribute atTargetLocation : Boolean;
        attribute taskComplete : Boolean;

        port dataPort : DataPort;
        port perceptionPort : SensorPort;
        port handlingPort : ObjectHandlingPort;
        port motionCommandPort : DataPort;
        port leftArmPort : DataPort;
        port rightArmPort : DataPort;
        port safetyStatusPort : DataPort;

        action def PlanHumanAssistance {
            in voice : VoiceCommand;
            in map : EnvironmentMap;
            out plan : TaskPlan;
        }
    }

    part def BalanceController {
        attribute stabilityMargin : Distance = 0.06 [SI::meter];
        attribute controlFrequency : ISQ::frequency = 200 [SI::hertz];

        port motionRequestPort : DataPort;
        port leftLegPort : DataPort;
        port rightLegPort : DataPort;

        action def MaintainUprightPosture {
            in centerOfMassOffset : Distance;
            out leftFootCorrection : Angle;
            out rightFootCorrection : Angle;
        }
    }

    part def PowerSystem {
        attribute stateOfCharge : Percent = 100.0;
        attribute availableEnergy : BatteryEnergy = 1800 [SI::wattHour];
        attribute peakPower : Power = 2500 [SI::watt];
        attribute nominalBusVoltage : ISQ::electricPotential = 48 [SI::volt];

        port torsoPowerPort : MobilityPowerPort;
        port headPowerPort : MobilityPowerPort;
        port leftArmPowerPort : MobilityPowerPort;
        port rightArmPowerPort : MobilityPowerPort;
        port leftLegPowerPort : MobilityPowerPort;
        port rightLegPowerPort : MobilityPowerPort;

        state def ChargingStateMachine {
            state Supplying;
            state LowEnergy;
            state Charging;
            state ProtectedShutdown;

            transition first Supplying;
            transition Supplying_to_LowEnergy from Supplying to LowEnergy
                if stateOfCharge < 20.0;
            transition LowEnergy_to_Charging from LowEnergy to Charging
                if stateOfCharge < 15.0;
            transition Charging_to_Supplying from Charging to Supplying
                if stateOfCharge >= 95.0;
            transition LowEnergy_to_ProtectedShutdown from LowEnergy to ProtectedShutdown
                if stateOfCharge < 5.0;
        }
    }

    part def SafetySupervisor {
        attribute emergencyStopActive : Boolean = false;
        attribute faultCleared : Boolean = true;
        attribute minimumHumanDistance : Distance = 0.45 [SI::meter];
        attribute maximumAllowedGripForce : Force = 60 [SI::newton];

        port statusPort : DataPort;

        action def EvaluateSafety {
            in humanDistance : Distance;
            in gripForce : Force;
            out safeToMove : Boolean;
            out safeToGrip : Boolean;
        }
    }

    part def VisionSensor {
        attribute horizontalFieldOfView : Angle = 95 [SI::degree];
        attribute range : Distance = 8 [SI::meter];
        attribute frameRate : ISQ::frequency = 30 [SI::hertz];
        port sensorOut : SensorPort;
    }

    part def AudioSensor {
        attribute microphoneCount : Integer = 6;
        attribute sampleRate : ISQ::frequency = 48000 [SI::hertz];
        port userIn : HumanInteractionPort;
    }

    part def SpeechEmitter {
        attribute maximumSoundLevel : Real = 72.0;
        port userOut : HumanInteractionPort;
    }

    part def InertialSensor {
        attribute updateRate : ISQ::frequency = 400 [SI::hertz];
    }

    part def ForceSensor {
        attribute measurementRange : Force = 200 [SI::newton];
        attribute accuracy : Percent = 2.0;
    }

    part def RotaryActuator {
        attribute maximumTorque : ISQ::torque = 90 [SI::newtonMeter];
        attribute maximumSpeed : ISQ::angularVelocity = 180 [SI::degreePerSecond];
        attribute holdingPower : Power = 12 [SI::watt];
    }

    part def LinearActuator {
        attribute maximumForce : Force = 80 [SI::newton];
        attribute travel : Distance = 0.04 [SI::meter];
        attribute holdingPower : Power = 4 [SI::watt];
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The anthropomorphic support robot shall provide high-level human assistance by interpreting natural human input, planning a safe task, moving through human environments, manipulating everyday objects, and reporting completion status. */
        subject robot : AnthropomorphicSupportRobot;

        require constraint {
            robot.maxWalkingSpeed >= 1.0 [SI::meterPerSecond] and
            robot.ratedLiftMass >= 5 [SI::kilogram] and
            robot.normalReach >= 0.7 [SI::meter]
        }
    }

    requirement def HumanLikeFormRequirement {
        doc /* The system shall use a human-like morphology with one head, one torso, two arms, two dexterous hands, and two legs to operate in spaces designed for people. */
        subject robot : AnthropomorphicSupportRobot;

        require constraint {
            robot.leftHand.fingerCount == 5 and
            robot.rightHand.fingerCount == 5 and
            robot.height >= 1.4 [SI::meter] and
            robot.height <= 1.9 [SI::meter]
        }
    }

    requirement def SafeInteractionRequirement {
        doc /* The system shall maintain safe interaction margins around humans and limit contact forces during object handling. */
        subject robot : AnthropomorphicSupportRobot;

        require constraint {
            robot.safetySupervisor.minimumHumanDistance >= 0.45 [SI::meter] and
            robot.safetySupervisor.maximumAllowedGripForce <= 60 [SI::newton]
        }
    }

    requirement def EnduranceRequirement {
        doc /* The system shall support a practical assistance shift without battery replacement. */
        subject robot : AnthropomorphicSupportRobot;

        require constraint {
            robot.operatingTime >= 4 [SI::hour] and
            robot.nominalBatteryEnergy >= 1500 [SI::wattHour]
        }
    }

    requirement def CommunicationRequirement {
        doc /* The system shall accept spoken or gestural commands and provide spoken and status-report responses. */
        subject robot : AnthropomorphicSupportRobot;

        require constraint {
            robot.head.microphoneArray.microphoneCount >= 4 and
            robot.head.stereoCamera.range >= 5 [SI::meter]
        }
    }

    satisfy PrimaryFunctionRequirement by AnthropomorphicSupportRobot;
    satisfy HumanLikeFormRequirement by AnthropomorphicSupportRobot;
    satisfy SafeInteractionRequirement by AnthropomorphicSupportRobot;
    satisfy EnduranceRequirement by AnthropomorphicSupportRobot;
    satisfy CommunicationRequirement by AnthropomorphicSupportRobot;
}