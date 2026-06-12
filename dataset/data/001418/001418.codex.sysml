package EntertainmentRobotSystem {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Percentage {
        :>> value : Real;
        constraint range { value >= 0.0 and value <= 100.0 }
    }

    attribute def DecibelLevel {
        :>> value : Real;
        unit = "dB";
    }

    attribute def LuminousFluxValue {
        :>> value : Real;
        unit = "lm";
    }

    attribute def PixelResolution {
        attribute horizontalPixels : Integer;
        attribute verticalPixels : Integer;
    }

    attribute def AudienceCount {
        :>> value : Integer;
        constraint nonnegative { value >= 0 }
    }

    attribute def EmotionConfidence {
        :>> value : Real;
        constraint range { value >= 0.0 and value <= 1.0 }
    }

    item def VoiceCommand {
        attribute utterance : String;
        attribute confidence : EmotionConfidence;
        attribute sourceDirection : Real;
    }

    item def MusicTrack {
        attribute title : String;
        attribute tempoBpm : Real;
        attribute duration : Time;
        attribute moodTag : String;
    }

    item def ChoreographyCue {
        attribute cueId : String;
        attribute startTime : Time;
        attribute moveName : String;
        attribute intensity : Percentage;
    }

    item def FacialExpressionCommand {
        attribute expressionName : String;
        attribute intensity : Percentage;
        attribute holdTime : Time;
    }

    item def LightingCommand {
        attribute red : Percentage;
        attribute green : Percentage;
        attribute blue : Percentage;
        attribute brightness : Percentage;
        attribute strobeFrequency : Frequency;
    }

    item def AudienceObservation {
        attribute detectedPeople : AudienceCount;
        attribute applauseLevel : DecibelLevel;
        attribute averageSmileConfidence : EmotionConfidence;
        attribute engagementScore : Percentage;
    }

    item def SafetyEvent {
        attribute eventCode : String;
        attribute severity : Integer;
        attribute description : String;
    }

    item def BatteryEnergy {
        attribute stateOfCharge : Percentage;
        attribute remainingEnergy : Energy;
        attribute packVoltage : ElectricPotential;
    }

    port def AudioInputPort {
        in item voice : VoiceCommand;
    }

    port def AudioOutputPort {
        out item track : MusicTrack;
        out item speech : VoiceCommand;
    }

    port def VisionInputPort {
        out item observation : AudienceObservation;
    }

    port def LightingOutputPort {
        out item light : LightingCommand;
    }

    port def MotionCommandPort {
        out item cue : ChoreographyCue;
    }

    port def ExpressionOutputPort {
        out item face : FacialExpressionCommand;
    }

    port def SafetyPort {
        out item event : SafetyEvent;
    }

    port def PowerPort {
        in item energy : BatteryEnergy;
    }

    part def EntertainmentRobot {
        attribute robotMass : Mass = 18.0 [kg];
        attribute maximumSpeed : Speed = 1.2 [m/s];
        attribute nominalRuntime : Time = 7200 [s];
        attribute maximumSoundPressure : DecibelLevel = 82.0;
        attribute safeOperatingRadius : Length = 1.5 [m];

        port audienceAudio : AudioInputPort;
        port speakerOutput : AudioOutputPort;
        port audienceVision : VisionInputPort;
        port stageLighting : LightingOutputPort;
        port bodyMotion : MotionCommandPort;
        port facialDisplay : ExpressionOutputPort;
        port safetyStatus : SafetyPort;
        port batteryInput : PowerPort;

        part controller : PerformanceController;
        part mobility : MobilitySubsystem;
        part audio : AudioSubsystem;
        part vision : VisionSubsystem;
        part lighting : LightingSubsystem;
        part expression : ExpressionSubsystem;
        part power : PowerSubsystem;
        part safety : SafetySubsystem;

        connect audienceAudio to audio.microphoneInput;
        connect audio.audioAnalysis to controller.voiceInput;
        connect vision.audienceOutput to controller.audienceInput;
        connect controller.musicOutput to audio.playbackInput;
        connect controller.motionOutput to mobility.motionInput;
        connect controller.lightOutput to lighting.lightInput;
        connect controller.expressionOutput to expression.expressionInput;
        connect power.energyOutput to controller.energyInput;
        connect safety.safetyEventOutput to controller.safetyInput;
        connect mobility.safetyEventOutput to safety.motionSafetyInput;
        connect vision.safetyEventOutput to safety.visionSafetyInput;
    }

    part def PerformanceController {
        attribute currentRoutineName : String;
        attribute audienceEngagementTarget : Percentage = 75.0;
        attribute minimumBatteryForShow : Percentage = 25.0;

        port voiceInput : AudioInputPort;
        port audienceInput : VisionInputPort;
        port energyInput : PowerPort;
        port safetyInput : SafetyPort;
        port musicOutput : AudioOutputPort;
        port motionOutput : MotionCommandPort;
        port lightOutput : LightingOutputPort;
        port expressionOutput : ExpressionOutputPort;

        action performInteractiveShow {
            in item audience : AudienceObservation;
            in item command : VoiceCommand;
            in item battery : BatteryEnergy;
            out item selectedTrack : MusicTrack;
            out item selectedCue : ChoreographyCue;
            out item selectedExpression : FacialExpressionCommand;
            out item selectedLighting : LightingCommand;

            first startShow;
            then senseAudience;
            then selectEntertainmentMode;
            then executeMusicDanceSequence;
            then adaptToAudienceResponse;
            then closeShow;

            action startShow;
            action senseAudience;
            action selectEntertainmentMode;
            action executeMusicDanceSequence;
            action adaptToAudienceResponse;
            action closeShow;
        }

        state def PerformanceStateMachine {
            entry action initializeEntertainmentSession;

            state Idle;
            state GreetingAudience;
            state PerformingRoutine;
            state InteractiveImprovisation;
            state SafetyPause;
            state RechargeRequired;
            state Shutdown;

            transition first Idle;
            transition Idle to GreetingAudience
                accept VoiceCommand
                if voice.confidence.value >= 0.70;

            transition GreetingAudience to PerformingRoutine
                if energyInput.energy.stateOfCharge.value >= minimumBatteryForShow.value;

            transition GreetingAudience to RechargeRequired
                if energyInput.energy.stateOfCharge.value < minimumBatteryForShow.value;

            transition PerformingRoutine to InteractiveImprovisation
                if audienceInput.observation.engagementScore.value < audienceEngagementTarget.value;

            transition InteractiveImprovisation to PerformingRoutine
                if audienceInput.observation.engagementScore.value >= audienceEngagementTarget.value;

            transition PerformingRoutine to SafetyPause
                accept SafetyEvent
                if event.severity >= 2;

            transition InteractiveImprovisation to SafetyPause
                accept SafetyEvent
                if event.severity >= 2;

            transition SafetyPause to PerformingRoutine
                if safetyInput.event.severity == 0 and energyInput.energy.stateOfCharge.value >= minimumBatteryForShow.value;

            transition SafetyPause to Shutdown
                if safetyInput.event.severity >= 4;

            transition PerformingRoutine to RechargeRequired
                if energyInput.energy.stateOfCharge.value < 15.0;

            transition RechargeRequired to Idle
                if energyInput.energy.stateOfCharge.value >= 90.0;

            transition Idle to Shutdown
                accept VoiceCommand
                if voice.utterance == "power down";
        }
    }

    part def MobilitySubsystem {
        attribute wheelBase : Length = 0.42 [m];
        attribute maximumAngularSpeed : AngularSpeed = 1.8 [rad/s];
        attribute positionTolerance : Length = 0.03 [m];

        port motionInput : MotionCommandPort;
        port safetyEventOutput : SafetyPort;

        part leftWheelMotor : DriveMotor {
            :>> ratedPower = 90.0 [W];
        }

        part rightWheelMotor : DriveMotor {
            :>> ratedPower = 90.0 [W];
        }

        part torsoActuator : ServoActuator {
            :>> angularRange = 1.57 [rad];
        }

        part armActuatorLeft : ServoActuator {
            :>> angularRange = 2.20 [rad];
        }

        part armActuatorRight : ServoActuator {
            :>> angularRange = 2.20 [rad];
        }

        action executeDanceMove {
            in item cue : ChoreographyCue;
            out item event : SafetyEvent;
        }
    }

    part def DriveMotor {
        attribute ratedPower : Power;
        attribute peakTorque : Torque = 2.4 [N*m];
        attribute encoderResolution : Integer = 2048;
    }

    part def ServoActuator {
        attribute ratedPower : Power = 35.0 [W];
        attribute angularRange : Angle;
        attribute maximumTorque : Torque = 4.0 [N*m];
    }

    part def AudioSubsystem {
        attribute speakerCount : Integer = 2;
        attribute microphoneCount : Integer = 4;
        attribute frequencyLow : Frequency = 80.0 [Hz];
        attribute frequencyHigh : Frequency = 18000.0 [Hz];

        port microphoneInput : AudioInputPort;
        port playbackInput : AudioOutputPort;
        port audioAnalysis : AudioInputPort;

        action recognizeSpeech {
            in item rawVoice : VoiceCommand;
            out item command : VoiceCommand;
        }

        action playMusicAndSpeech {
            in item music : MusicTrack;
            in item speech : VoiceCommand;
        }
    }

    part def VisionSubsystem {
        attribute cameraResolution : PixelResolution {
            :>> horizontalPixels = 1920;
            :>> verticalPixels = 1080;
        }
        attribute frameRate : Frequency = 30.0 [Hz];
        attribute minimumIllumination : Illuminance = 5.0 [lx];

        port audienceOutput : VisionInputPort;
        port safetyEventOutput : SafetyPort;

        action detectAudience {
            out item observation : AudienceObservation;
        }

        action detectObstacle {
            out item event : SafetyEvent;
        }
    }

    part def LightingSubsystem {
        attribute maximumFlux : LuminousFluxValue = 1200.0;
        attribute ledChannelCount : Integer = 24;
        attribute maximumStrobeFrequency : Frequency = 12.0 [Hz];

        port lightInput : LightingOutputPort;

        action renderLightingEffect {
            in item command : LightingCommand;
        }
    }

    part def ExpressionSubsystem {
        attribute displayResolution : PixelResolution {
            :>> horizontalPixels = 800;
            :>> verticalPixels = 480;
        }
        attribute expressionFrameRate : Frequency = 60.0 [Hz];

        port expressionInput : ExpressionOutputPort;

        action renderExpression {
            in item command : FacialExpressionCommand;
        }
    }

    part def PowerSubsystem {
        attribute batteryCapacity : Energy = 540000.0 [J];
        attribute nominalVoltage : ElectricPotential = 24.0 [V];
        attribute maximumContinuousPower : Power = 450.0 [W];
        attribute chargingPower : Power = 180.0 [W];

        port energyOutput : PowerPort;

        action estimateRemainingRuntime {
            in item energy : BatteryEnergy;
            out remainingRuntime : Time;
        }
    }

    part def SafetySubsystem {
        attribute obstacleStopDistance : Length = 0.35 [m];
        attribute maximumSurfaceTemperature : Temperature = 318.15 [K];
        attribute maximumAllowedSoundPressure : DecibelLevel = 85.0;

        port motionSafetyInput : SafetyPort;
        port visionSafetyInput : SafetyPort;
        port safetyEventOutput : SafetyPort;

        action evaluateSafety {
            in item motionEvent : SafetyEvent;
            in item visionEvent : SafetyEvent;
            out item systemEvent : SafetyEvent;
        }
    }

    requirement def PrimaryEntertainmentRequirement {
        subject robot : EntertainmentRobot;

        require constraint {
            robot.controller.audienceEngagementTarget.value >= 70.0
        }

        require constraint {
            robot.nominalRuntime >= 3600 [s]
        }

        require constraint {
            robot.maximumSoundPressure.value <= 85.0
        }
    }

    requirement def AudienceInteractionRequirement {
        subject controller : PerformanceController;

        require constraint {
            controller.minimumBatteryForShow.value >= 20.0
        }

        require constraint {
            controller.audienceEngagementTarget.value >= 75.0
        }
    }

    requirement def MobilitySafetyRequirement {
        subject mobility : MobilitySubsystem;

        require constraint {
            mobility.maximumAngularSpeed <= 2.0 [rad/s]
        }

        require constraint {
            mobility.positionTolerance <= 0.05 [m]
        }
    }

    requirement def VisualPerformanceRequirement {
        subject lighting : LightingSubsystem;
        subject expression : ExpressionSubsystem;

        require constraint {
            lighting.maximumFlux.value >= 1000.0
        }

        require constraint {
            expression.expressionFrameRate >= 30.0 [Hz]
        }
    }

    requirement def PowerEnduranceRequirement {
        subject power : PowerSubsystem;

        require constraint {
            power.batteryCapacity >= 500000.0 [J]
        }

        require constraint {
            power.maximumContinuousPower >= 400.0 [W]
        }
    }

    part entertainmentRobotSystem {
        part robot : EntertainmentRobot;

        requirement primaryTask : PrimaryEntertainmentRequirement {
            subject robot = entertainmentRobotSystem.robot;
        }

        requirement interaction : AudienceInteractionRequirement {
            subject controller = entertainmentRobotSystem.robot.controller;
        }

        requirement mobilitySafety : MobilitySafetyRequirement {
            subject mobility = entertainmentRobotSystem.robot.mobility;
        }

        requirement visualPerformance : VisualPerformanceRequirement {
            subject lighting = entertainmentRobotSystem.robot.lighting;
            subject expression = entertainmentRobotSystem.robot.expression;
        }

        requirement endurance : PowerEnduranceRequirement {
            subject power = entertainmentRobotSystem.robot.power;
        }
    }
}