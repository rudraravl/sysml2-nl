package ThymioEducationalRobotSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def RGBColor {
        attribute red : Real;
        attribute green : Real;
        attribute blue : Real;
    }
    
    attribute def ProximityReading {
        attribute distance : ISQ::LengthValue;
        attribute intensity : Real;
    }
    
    attribute def MotorCommand {
        attribute speed : ISQ::SpeedValue;
        attribute direction : Real;
    }
    
    attribute def ButtonState {
        attribute pressed : Boolean;
        attribute timestamp : ISQ::TimeValue;
    }
    
    port def ProximitySensorPort {
        out reading : ProximityReading;
    }
    
    port def MotorControlPort {
        in command : MotorCommand;
        out actualSpeed : ISQ::SpeedValue;
    }
    
    port def LEDControlPort {
        in color : RGBColor;
        in brightness : Real;
    }
    
    port def SpeakerPort {
        in frequency : ISQ::FrequencyValue;
        in duration : ISQ::TimeValue;
    }
    
    port def ButtonInputPort {
        out state : ButtonState;
    }
    
    port def PowerPort {
        attribute voltage : ISQ::VoltageValue;
        attribute current : ISQ::ElectricCurrentValue;
    }
    
    part def ProximitySensor {
        attribute maxRange : ISQ::LengthValue = 140[SI::mm];
        attribute fieldOfView : Real = 0.3;
        attribute updateRate : ISQ::FrequencyValue = 10[SI::Hz];
        port output : ProximitySensorPort;
    }
    
    part def DCMotor {
        attribute maxSpeed : ISQ::SpeedValue = 0.2[SI::m/SI::s];
        attribute maxTorque : ISQ::TorqueValue = 0.05[SI::N*SI::m];
        attribute efficiency : Real = 0.85;
        port control : MotorControlPort;
        port power : PowerPort;
    }
    
    part def RGBLEDArray {
        attribute numberOfLEDs : Integer = 8;
        attribute maxBrightness : Real = 1.0;
        port control : LEDControlPort;
        port power : PowerPort;
    }
    
    part def PiezoSpeaker {
        attribute minFrequency : ISQ::FrequencyValue = 100[SI::Hz];
        attribute maxFrequency : ISQ::FrequencyValue = 10000[SI::Hz];
        attribute volume : Real = 0.8;
        port control : SpeakerPort;
        port power : PowerPort;
    }
    
    part def CapacitiveButton {
        attribute sensitivity : Real = 0.7;
        attribute debounceTime : ISQ::TimeValue = 0.05[SI::s];
        port output : ButtonInputPort;
    }
    
    part def Battery {
        attribute capacity : ISQ::ElectricChargeValue = 5400[SI::C];
        attribute nominalVoltage : ISQ::VoltageValue = 3.7[SI::V];
        attribute currentCharge : ISQ::ElectricChargeValue;
        port power : PowerPort;
    }
    
    part def Microcontroller {
        attribute processorSpeed : ISQ::FrequencyValue = 72000000[SI::Hz];
        attribute ramSize : ISQ::DataRateValue = 96000[SI::bit];
        attribute flashSize : ISQ::DataRateValue = 512000[SI::bit];
        port power : PowerPort;
    }
    
    action def ProcessProximityData {
        in frontLeft : ProximityReading;
        in frontCenter : ProximityReading;
        in frontRight : ProximityReading;
        in rearLeft : ProximityReading;
        in rearRight : ProximityReading;
        out obstacleDetected : Boolean;
        out obstacleDirection : Real;
        out minDistance : ISQ::LengthValue;
    }
    
    action def ComputeNavigationCommands {
        in obstacleDetected : Boolean;
        in obstacleDirection : Real;
        in minDistance : ISQ::LengthValue;
        in currentMode : String;
        out leftMotorCmd : MotorCommand;
        out rightMotorCmd : MotorCommand;
    }
    
    action def GenerateUserFeedback {
        in systemState : String;
        in obstacleDetected : Boolean;
        in batteryLevel : Real;
        out topLEDColor : RGBColor;
        out bottomLEDColor : RGBColor;
        out soundFrequency : ISQ::FrequencyValue;
        out soundDuration : ISQ::TimeValue;
    }
    
    part def ThymioRobot {
        attribute robotMass : ISQ::MassValue = 0.27[SI::kg];
        attribute wheelDiameter : ISQ::LengthValue = 0.042[SI::m];
        attribute wheelBase : ISQ::LengthValue = 0.094[SI::m];
        attribute bodyLength : ISQ::LengthValue = 0.11[SI::m];
        attribute bodyWidth : ISQ::LengthValue = 0.11[SI::m];
        attribute bodyHeight : ISQ::LengthValue = 0.05[SI::m];
        
        part frontProximitySensors : ProximitySensor[5] {
            port output : ProximitySensorPort;
        }
        
        part rearProximitySensors : ProximitySensor[2] {
            port output : ProximitySensorPort;
        }
        
        part groundProximitySensors : ProximitySensor[2] {
            port output : ProximitySensorPort;
        }
        
        part leftMotor : DCMotor {
            port control : MotorControlPort;
            port power : PowerPort;
        }
        
        part rightMotor : DCMotor {
            port control : MotorControlPort;
            port power : PowerPort;
        }
        
        part topLEDs : RGBLEDArray {
            attribute numberOfLEDs = 8;
            port control : LEDControlPort;
            port power : PowerPort;
        }
        
        part bottomLEDs : RGBLEDArray {
            attribute numberOfLEDs = 2;
            port control : LEDControlPort;
            port power : PowerPort;
        }
        
        part speaker : PiezoSpeaker {
            port control : SpeakerPort;
            port power : PowerPort;
        }
        
        part centerButton : CapacitiveButton {
            port output : ButtonInputPort;
        }
        
        part forwardButton : CapacitiveButton {
            port output : ButtonInputPort;
        }
        
        part backwardButton : CapacitiveButton {
            port output : ButtonInputPort;
        }
        
        part leftButton : CapacitiveButton {
            port output : ButtonInputPort;
        }
        
        part rightButton : CapacitiveButton {
            port output : ButtonInputPort;
        }
        
        part battery : Battery {
            attribute capacity = 5400[SI::C];
            attribute nominalVoltage = 3.7[SI::V];
            port power : PowerPort;
        }
        
        part controller : Microcontroller {
            port power : PowerPort;
        }
        
        connect battery.power to controller.power;
        connect battery.power to leftMotor.power;
        connect battery.power to rightMotor.power;
        connect battery.power to topLEDs.power;
        connect battery.power to bottomLEDs.power;
        connect battery.power to speaker.power;
        
        perform action autonomousOperation : AutonomousOperation;
    }
    
    action def AutonomousOperation {
        in buttonPressed : Boolean;
        in batteryVoltage : ISQ::VoltageValue;
        out leftMotorCmd : MotorCommand;
        out rightMotorCmd : MotorCommand;
        out topLEDCmd : RGBColor;
        out audioCmd : ISQ::FrequencyValue;
        
        first start;
        then merge senseEnvironment;
        
        action senseEnvironment : ProcessProximityData {
            in frontLeft : ProximityReading;
            in frontCenter : ProximityReading;
            in frontRight : ProximityReading;
            in rearLeft : ProximityReading;
            in rearRight : ProximityReading;
            out obstacleDetected : Boolean;
            out obstacleDirection : Real;
            out minDistance : ISQ::LengthValue;
        }
        
        then decide;
            if senseEnvironment.obstacleDetected then executeAvoidance;
            if !senseEnvironment.obstacleDetected then executeCruise;
        
        action executeCruise : ComputeNavigationCommands {
            in obstacleDetected = false;
            in obstacleDirection = 0.0;
            in minDistance = 1.0[SI::m];
            in currentMode = "cruise";
            out leftMotorCmd : MotorCommand;
            out rightMotorCmd : MotorCommand;
        }
        
        flow executeCruise.leftMotorCmd to leftMotorCmd;
        flow executeCruise.rightMotorCmd to rightMotorCmd;
        
        then provideFeedback;
        
        action executeAvoidance : ComputeNavigationCommands {
            in obstacleDetected = true;
            in obstacleDirection = senseEnvironment.obstacleDirection;
            in minDistance = senseEnvironment.minDistance;
            in currentMode = "avoid";
            out leftMotorCmd : MotorCommand;
            out rightMotorCmd : MotorCommand;
        }
        
        flow executeAvoidance.leftMotorCmd to leftMotorCmd;
        flow executeAvoidance.rightMotorCmd to rightMotorCmd;
        
        then action emitWarning : GenerateUserFeedback {
            in systemState = "avoiding";
            in obstacleDetected = true;
            in batteryLevel = 0.8;
            out topLEDColor : RGBColor;
            out bottomLEDColor : RGBColor;
            out soundFrequency : ISQ::FrequencyValue = 880[SI::Hz];
            out soundDuration : ISQ::TimeValue = 0.15[SI::s];
        }
        
        flow emitWarning.soundFrequency to audioCmd;
        
        then provideFeedback;
        
        action provideFeedback : GenerateUserFeedback {
            in systemState = "active";
            in obstacleDetected = senseEnvironment.obstacleDetected;
            in batteryLevel = 0.8;
            out topLEDColor : RGBColor;
            out bottomLEDColor : RGBColor;
            out soundFrequency : ISQ::FrequencyValue;
            out soundDuration : ISQ::TimeValue;
        }
        
        flow provideFeedback.topLEDColor to topLEDCmd;
        
        then senseEnvironment;
    }
    
    requirement def ObstacleDetectionRequirement {
        doc /* The robot shall detect obstacles within 140mm range using proximity sensors 
                with a minimum update rate of 10Hz to enable safe navigation. */
        
        subject robot : ThymioRobot;
        
        require constraint {
            robot.frontProximitySensors.maxRange >= 0.14[SI::m] and
            robot.frontProximitySensors.updateRate >= 10[SI::Hz]
        }
    }
    
    requirement def CollisionAvoidanceRequirement {
        doc /* The robot shall initiate avoidance maneuvers when obstacles are detected 
                within 100mm to prevent collisions during autonomous navigation. */
        
        subject robot : ThymioRobot;
        
        require constraint {
            robot.frontProximitySensors.maxRange >= 0.1[SI::m]
        }
    }
    
    requirement def MobilityRequirement {
        doc /* The robot shall achieve differential drive motion with each motor capable 
                of at least 100mm/s forward speed for effective navigation. */
        
        subject robot : ThymioRobot;
        
        require constraint {
            robot.leftMotor.maxSpeed >= 0.1[SI::m/SI::s] and
            robot.rightMotor.maxSpeed >= 0.1[SI::m/SI::s]
        }
    }
    
    requirement def UserFeedbackRequirement {
        doc /* The robot shall provide visual feedback through RGB LEDs and audio feedback 
                through speaker to communicate operational state to users. */
        
        subject robot : ThymioRobot;
        
        require constraint {
            robot.topLEDs.numberOfLEDs >= 8 and
            robot.speaker.maxFrequency >= 1000[SI::Hz]
        }
    }
    
    requirement def BatteryLifeRequirement {
        doc /* The robot shall operate for a minimum of 2 hours on a single battery charge 
                under normal autonomous navigation conditions. */
        
        subject robot : ThymioRobot;
        
        require constraint {
            robot.battery.capacity >= 5400[SI::C]
        }
    }
    
    requirement <'THYM-MAIN-001'> primaryFunctionRequirement {
        doc /* The Thymio educational robot system shall provide an interactive, programmable 
                platform for learning robotics and computer science concepts through autonomous 
                navigation, obstacle avoidance, and multi-modal user feedback. The system shall 
                enable users to explore sensor-based decision making, motor control, and 
                event-driven programming in an engaging, hands-on manner suitable for 
                educational environments. */
        
        subject thymioSystem : ThymioRobot;
        
        assume constraint educationalEnvironment {
            doc /* The robot operates in controlled indoor educational settings with 
                    flat surfaces and detectable obstacles appropriate for learning activities. */
        }
        
        require obstacleDetection : ObstacleDetectionRequirement;
        require collisionAvoidance : CollisionAvoidanceRequirement;
        require mobility : MobilityRequirement;
        require userFeedback : UserFeedbackRequirement;
        require batteryLife : BatteryLifeRequirement;
    }
    
    part thymioInstance : ThymioRobot {
        perform action operate : AutonomousOperation {
            in buttonPressed;
            in batteryVoltage;
            out leftMotorCmd;
            out rightMotorCmd;
            out topLEDCmd;
            out audioCmd;
        }
        
        connection frontSensorConnection connect 
            frontProximitySensors[0].output to operate;
        
        connection leftMotorConnection connect 
            operate to leftMotor.control;
        
        connection rightMotorConnection connect 
            operate to rightMotor.control;
        
        connection topLEDConnection connect 
            operate to topLEDs.control;
        
        connection speakerConnection connect 
            operate to speaker.control;
        
        connection buttonConnection connect 
            centerButton.output to operate;
    }
    
    satisfy requirement primaryFunctionRequirement by thymioInstance;
}
