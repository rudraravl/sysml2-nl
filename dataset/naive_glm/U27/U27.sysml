package ThymioRobot {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value type DistanceUnit > Real = mm;
    value type Distance > Real { :>> unit = DistanceUnit; }
    value type SpeedUnit > Real = mm/s;
    value type LinearSpeed > Real { :>> unit = SpeedUnit; }
    value type AngularSpeedUnit > Real = rad/s;
    value type AngularSpeed > Real { :>> unit = AngularSpeedUnit; }
    value type VoltageUnit > Real = V;
    value type Voltage > Real { :>> unit = VoltageUnit; }
    value type CurrentUnit > Real = A;
    value type Current > Real { :>> unit = CurrentUnit; }
    value type ChargeUnit > Real = C;
    value type Charge > Real { :>> unit = ChargeUnit; }
    value type MassUnit > Real = g;
    value type Mass > Real { :>> unit = MassUnit; }
    value type TemperatureUnit > Real = degC;
    value type Temperature > Real { :>> unit = TemperatureUnit; }
    value type FrequencyUnit > Real = Hz;
    value type Frequency > Real { :>> unit = FrequencyUnit; }
    value type DutyCycle > Real { min = 0.0; max = 1.0; }
    value type ProximityValue > Integer { min = 0; max = 4095; }
    value type ReflectanceValue > Integer { min = 0; max = 1023; }
    value type ButtonState > Boolean;
    value type RGBValue > Integer { min = 0; max = 255; }
    value type ColorValue > Tuple { red: RGBValue; green: RGBValue; blue: RGBValue; }
    value type ToneFrequency > Real { :>> unit = FrequencyUnit; min = 100.0; max = 8000.0; }
    value type DurationUnit > Real = s;
    value type DurationValue > Real { :>> unit = DurationUnit; }
    value type HeadingAngle > Real { :>> unit = AngularSpeedUnit; }

    // ===== Item Types =====
    item def Obstacle;
    item def SurfaceEdge;
    item def SoundWave;
    item def LightEmission;
    item def UserCommand;
    item def ProgramInstruction;
    item def PowerFlow;
    item def SensorReading;
    item def MotorCommand;
    item def LEDCommand;
    item def AudioCommand;

    // ===== Enumerations =====
    enum def RobotMode {
        idle;
        cruising;
        avoiding;
        edgeAvoiding;
        userControlled;
        charging;
    }

    enum def DriveDirection {
        forward;
        backward;
        leftTurn;
        rightTurn;
        stop;
    }

    enum def SensorOrientation {
        front;
        rear;
        downward;
    }

    enum def LEDLocation {
        topRing;
        bottomLeft;
        bottomRight;
    }

    enum def ButtonFunction {
        start;
        stop;
        forward;
        backward;
        left;
        right;
        modeSelect;
    }

    // ===== Port Definitions =====
    port def PowerPort {
        out voltage: Voltage;
        in current: Current;
        out powerFlow: PowerFlow;
    }

    port def ProximityOutputPort {
        out distance: Distance;
        out rawValue: ProximityValue;
        out detected: Boolean;
    }

    port def GroundSensorOutputPort {
        out reflectance: ReflectanceValue;
        out edgeDetected: Boolean;
    }

    port def MotorControlPort {
        in dutyCycle: DutyCycle;
        in direction: DriveDirection;
        in speed: LinearSpeed;
    }

    port def MotorFeedbackPort {
        out actualSpeed: LinearSpeed;
        out encoderTicks: Integer;
    }

    port def ButtonInputPort {
        out pressed: Boolean;
        out function: ButtonFunction;
    }

    port def LEDControlPort {
        in color: ColorValue;
        in location: LEDLocation;
        in active: Boolean;
    }

    port def AudioControlPort {
        in frequency: ToneFrequency;
        in duration: DurationValue;
        in active: Boolean;
    }

    port def I2CBusPort {
        in address: Integer;
        in dataOut: Integer[0..*];
        out dataIn: Integer[0..*];
    }

    port def SensorBusPort {
        out readings: SensorReading[0..*];
    }

    port def ActuatorBusPort {
        in commands: MotorCommand[0..*];
    }

    port def FeedbackBusPort {
        in ledCommands: LEDCommand[0..*];
        in audioCommands: AudioCommand[0..*];
    }

    // ===== Requirements =====
    requirement def ThymioRobotRequirement {
        doc /* The Thymio is a small, two-wheeled educational robot designed to teach programming and robotics concepts interactively. */
        subject robot: Thymio;
        requirement compactBody: CompactBodyRequirement;
        requirement differentialDrive: DifferentialDriveRequirement;
        requirement sensorArray: SensorArrayRequirement;
        requirement userInteraction: UserInteractionRequirement;
        requirement feedback: FeedbackRequirement;
        requirement autonomy: AutonomousBehaviorRequirement;
        requirement power: PowerRequirement;
    }

    requirement def CompactBodyRequirement {
        doc /* The robot shall have a compact body suitable for educational use. */
        subject body: RobotBody;
        constraint { body.mass <= 110.0 [g] }
        constraint { body.length <= 110.0 [mm] }
        constraint { body.width <= 110.0 [mm] }
    }

    requirement def DifferentialDriveRequirement {
        doc /* The robot shall use a differential drive system with two independently controlled DC motors. */
        subject drive: DifferentialDrive;
        constraint { drive.wheelCount == 2 }
        requirement forwardMotion: { doc /* The robot shall move forward. */ subject m: DifferentialDrive; constraint { m.direction == DriveDirection::forward } }
        requirement backwardMotion: { doc /* The robot shall move backward. */ subject m: DifferentialDrive; constraint { m.direction == DriveDirection::backward } }
        requirement turning: { doc /* The robot shall turn with precision. */ subject m: DifferentialDrive; constraint { m.turningPrecision <= 5.0 [deg] } }
    }

    requirement def SensorArrayRequirement {
        doc /* The robot shall have an extensive array of proximity sensors. */
        subject sensors: SensorArray;
        constraint { sensors.frontSensorCount == 5 }
        constraint { sensors.rearSensorCount == 2 }
        constraint { sensors.groundSensorCount == 2 }
        requirement obstacleDetection: { doc /* Forward sensors shall detect obstacles. */ subject s: ProximitySensor; constraint { s.orientation == SensorOrientation::front } }
        requirement rearDetection: { doc /* Rear sensors shall detect objects behind. */ subject s: ProximitySensor; constraint { s.orientation == SensorOrientation::rear } }
        requirement edgeDetection: { doc /* Downward sensors shall detect surface edges. */ subject s: GroundSensor; constraint { s.orientation == SensorOrientation::downward } }
    }

    requirement def UserInteractionRequirement {
        doc /* Users shall interact via capacitive touch buttons. */
        subject buttons: TouchButtonArray;
        constraint { buttons.buttonCount >= 5 }
        constraint { buttons.type == "capacitive" }
    }

    requirement def FeedbackRequirement {
        doc /* The robot shall provide visual and audible feedback. */
        subject feedback: FeedbackSystem;
        requirement visual: { doc /* RGB LEDs shall indicate modes and events. */ subject l: LEDRing; constraint { l.ledCount >= 8 } }
        requirement audible: { doc /* A piezo speaker shall produce sounds and melodies. */ subject s: PiezoSpeaker; constraint { s.frequencyRange.min >= 100.0 [Hz] } constraint { s.frequencyRange.max <= 8000.0 [Hz] } }
    }

    requirement def AutonomousBehaviorRequirement {
        doc /* The robot shall operate autonomously, scanning for obstacles and avoiding collisions. */
        subject behavior: AutonomousBehavior;
        requirement cruiseForward: { doc /* If path is clear, robot shall cruise forward. */ subject b: AutonomousBehavior; constraint { b.clearPath == true implies b.action == DriveDirection::forward } }
        requirement avoidObstacle: { doc /* Upon detecting an object, robot shall execute an avoidance maneuver. */ subject b: AutonomousBehavior; constraint { b.obstacleDetected == true implies b.action == DriveDirection::leftTurn or b.action == DriveDirection::rightTurn } }
        requirement signalAvoidance: { doc /* During avoidance, robot shall turn red and beep. */ subject b: AutonomousBehavior; constraint { b.mode == RobotMode::avoiding implies b.ledColor == ColorValue{red=255, green=0, blue=0} } }
    }

    requirement def PowerRequirement {
        doc /* The robot shall be powered by an internal rechargeable battery. */
        subject battery: Battery;
        constraint { battery.rechargeable == true }
        constraint { battery.nominalVoltage >= 3.7 [V] }
        constraint { battery.capacity >= 1.8 [A*h] }
    }

    // ===== Part Definitions =====

    part def Thymio {
        doc /* The Thymio educational robot. */
        requirement thymioReq: ThymioRobotRequirement { subject robot = this; }

        part body: RobotBody;
        part driveSystem: DifferentialDrive;
        part sensorArray: SensorArray;
        part interactionInterface: TouchButtonArray;
        part feedbackSystem: FeedbackSystem;
        part controller: Microcontroller;
        part powerSystem: PowerSystem;

        port powerIn: PowerPort;

        attribute mode: RobotMode = RobotMode::idle;
        attribute currentSpeed: LinearSpeed = 0.0 [mm/s];
        attribute heading: HeadingAngle = 0.0 [rad];

        exhibit state behavior AutonomousBehavior {
            attribute clearPath: Boolean;
            attribute obstacleDetected: Boolean;
            attribute edgeDetected: Boolean;
            attribute action: DriveDirection;
            attribute ledColor: ColorValue;
            attribute beepActive: Boolean;

            state idle;
            state cruising;
            state avoiding;
            state edgeAvoiding;
            state userControlled;
            state charging;

            transition init to idle;
            transition idle to cruising
                when sensorArray.frontSensors.detected->forAll{d | d == false}
                guard interactionInterface.startButton.pressed == true;
            transition cruising to avoiding
                when sensorArray.frontSensors.detected->exists{d | d == true};
            transition cruising to edgeAvoiding
                when sensorArray.groundSensors.edgeDetected->exists{d | d == true};
            transition avoiding to cruising
                when sensorArray.frontSensors.detected->forAll{d | d == false}
                guard controller.avoidanceComplete == true;
            transition edgeAvoiding to cruising
                when sensorArray.groundSensors.edgeDetected->forAll{d | d == false}
                guard controller.edgeAvoidanceComplete == true;
            transition cruising to userControlled
                when interactionInterface.anyButtonPressed == true;
            transition userControlled to idle
                when interactionInterface.stopButton.pressed == true;
            transition idle to charging
                when powerSystem.battery.charging == true;
            transition charging to idle
                when powerSystem.battery.fullyCharged == true;

            do action cruiseForwardAction {
                /* Set motors to move forward at cruise speed */
                controller.leftMotorCommand.dutyCycle = 0.5;
                controller.rightMotorCommand.dutyCycle = 0.5;
                controller.leftMotorCommand.direction = DriveDirection::forward;
                controller.rightMotorCommand.direction = DriveDirection::forward;
                feedbackSystem.ledRing.setColor(ColorValue{red=0, green=255, blue=0});
                feedbackSystem.speaker.mute();
            } in cruising;

            do action avoidObstacleAction {
                /* Calculate and execute avoidance maneuver */
                if sensorArray.frontSensors[0].detected then {
                    controller.leftMotorCommand.dutyCycle = 0.3;
                    controller.rightMotorCommand.dutyCycle = 0.0;
                    controller.leftMotorCommand.direction = DriveDirection::backward;
                    controller.rightMotorCommand.direction = DriveDirection::forward;
                } else {
                    controller.leftMotorCommand.dutyCycle = 0.0;
                    controller.rightMotorCommand.dutyCycle = 0.3;
                    controller.leftMotorCommand.direction = DriveDirection::forward;
                    controller.rightMotorCommand.direction = DriveDirection::backward;
                }
                feedbackSystem.ledRing.setColor(ColorValue{red=255, green=0, blue=0});
                feedbackSystem.speaker.playTone(880.0 [Hz], 200.0 [ms]);
            } in avoiding;

            do action edgeAvoidAction {
                /* Back up and turn away from edge */
                controller.leftMotorCommand.dutyCycle = 0.4;
                controller.rightMotorCommand.dutyCycle = 0.4;
                controller.leftMotorCommand.direction = DriveDirection::backward;
                controller.rightMotorCommand.direction = DriveDirection::backward;
                wait(500.0 [ms]);
                controller.leftMotorCommand.dutyCycle = 0.3;
                controller.rightMotorCommand.dutyCycle = 0.0;
                controller.leftMotorCommand.direction = DriveDirection::forward;
                controller.rightMotorCommand.direction = DriveDirection::forward;
                feedbackSystem.ledRing.setColor(ColorValue{red=255, green=100, blue=0});
                feedbackSystem.speaker.playTone(440.0 [Hz], 300.0 [ms]);
            } in edgeAvoiding;

            do action idleAction {
                controller.leftMotorCommand.dutyCycle = 0.0;
                controller.rightMotorCommand.dutyCycle = 0.0;
                feedbackSystem.ledRing.setColor(ColorValue{red=0, green=0, blue=255});
                feedbackSystem.speaker.mute();
            } in idle;

            do action chargingAction {
                controller.leftMotorCommand.dutyCycle = 0.0;
                controller.rightMotorCommand.dutyCycle = 0.0;
                feedbackSystem.ledRing.setColor(ColorValue{red=0, green=50, blue=0});
                feedbackSystem.speaker.mute();
            } in charging;
        }
    }

    part def RobotBody {
        doc /* Compact body of the Thymio robot. */
        attribute length: Distance = 110.0 [mm];
        attribute width: Distance = 110.0 [mm];
        attribute height: Distance = 50.0 [mm];
        attribute mass: Mass = 110.0 [g];
        attribute material: String = "polycarbonate";
        part topShell: Shell {
            attribute color: String = "white";
            attribute hasTouchButtons: Boolean = true;
        }
        part bottomShell: Shell {
            attribute color: String = "white";
            attribute hasGroundSensors: Boolean = true;
        }
    }

    part def Shell {
        attribute color: String;
        attribute hasTouchButtons: Boolean = false;
        attribute hasGroundSensors: Boolean = false;
    }

    part def DifferentialDrive {
        doc /* Differential drive system with two independently controlled DC motors. */
        attribute wheelCount: Integer = 2;
        attribute wheelDiameter: Distance = 22.0 [mm];
        attribute wheelBase: Distance = 95.0 [mm];
        attribute maxSpeed: LinearSpeed = 200.0 [mm/s];
        attribute turningPrecision: Real = 5.0 [deg];
        attribute direction: DriveDirection = DriveDirection::stop;

        part leftMotor: DCMotor {
            attribute side: String = "left";
            port control: MotorControlPort;
            port feedback: MotorFeedbackPort;
            port power: PowerPort;
        }
        part rightMotor: DCMotor {
            attribute side: String = "right";
            port control: MotorControlPort;
            port feedback: MotorFeedbackPort;
            port power: PowerPort;
        }
        part leftWheel: Wheel {
            attribute side: String = "left";
            attribute diameter: Distance = 22.0 [mm];
        }
        part rightWheel: Wheel {
            attribute side: String = "right";
            attribute diameter: Distance = 22.0 [mm];
        }

        connection leftMotorToWheel connect leftMotor.shaft to leftWheel.hub;
        connection rightMotorToWheel connect rightMotor.shaft to rightWheel.hub;
    }

    part def DCMotor {
        doc /* DC motor for wheel propulsion. */
        attribute side: String;
        attribute nominalVoltage: Voltage = 6.0 [V];
        attribute stallCurrent: Current = 1.5 [A];
        attribute noLoadSpeed: AngularSpeed = 200.0 [rad/s];
        attribute shaft: Shaft;
        port control: MotorControlPort;
        port feedback: MotorFeedbackPort;
        port power: PowerPort;

        exhibit state behavior MotorOperation {
            state stopped;
            state runningForward;
            state runningBackward;
            transition init to stopped;
            transition stopped to runningForward
                when control.direction == DriveDirection::forward and control.dutyCycle > 0.0;
            transition stopped to runningBackward
                when control.direction == DriveDirection::backward and control.dutyCycle > 0.0;
            transition runningForward to stopped
                when control.dutyCycle == 0.0;
            transition runningBackward to stopped
                when control.dutyCycle == 0.0;
            do action updateSpeed {
                feedback.actualSpeed = noLoadSpeed * control.dutyCycle;
            }
        }
    }

    part def Shaft {
        attribute diameter: Distance = 3.0 [mm];
        attribute length: Distance = 15.0 [mm];
    }

    part def Wheel {
        attribute side: String;
        attribute diameter: Distance;
        attribute material: String = "rubber";
        port hub: Shaft;
    }

    part def SensorArray {
        doc /* Array of proximity and ground sensors. */
        attribute frontSensorCount: Integer = 5;
        attribute rearSensorCount: Integer = 2;
        attribute groundSensorCount: Integer = 2;

        part frontSensors: ProximitySensor[5] {
            attribute orientation: SensorOrientation = SensorOrientation::front;
        }
        part rearSensors: ProximitySensor[2] {
            attribute orientation: SensorOrientation = SensorOrientation::rear;
        }
        part groundSensors: GroundSensor[2] {
            attribute orientation: SensorOrientation = SensorOrientation::downward;
        }

        port sensorBus: SensorBusPort;
    }

    part def ProximitySensor {
        doc /* Infrared proximity sensor for obstacle detection. */
        attribute orientation: SensorOrientation;
        attribute maxRange: Distance = 100.0 [mm];
        attribute minRange: Distance = 5.0 [mm];
        attribute resolution: ProximityValue = 4095;
        attribute detected: Boolean = false;
        attribute distance: Distance = 100.0 [mm];
        attribute rawValue: ProximityValue = 0;
        port output: ProximityOutputPort;
        port power: PowerPort;

        exhibit state behavior Sensing {
            state idle;
            state scanning;
            state objectDetected;
            transition init to idle;
            transition idle to scanning when power.voltage > 0.0 [V];
            transition scanning to objectDetected when rawValue > 800;
            transition objectDetected to scanning when rawValue <= 800;
            do action readSensor {
                /* Emit IR pulse and measure reflection */
                output.rawValue = rawValue;
                output.detected = rawValue > 800;
                output.distance = maxRange - (maxRange * rawValue / resolution);
            }
        }
    }

    part def GroundSensor {
        doc /* Downward-facing sensor for edge/surface detection. */
        attribute orientation: SensorOrientation = SensorOrientation::downward;
        attribute reflectance: ReflectanceValue = 1023;
        attribute edgeDetected: Boolean = false;
        attribute threshold: ReflectanceValue = 200;
        port output: GroundSensorOutputPort;
        port power: PowerPort;

        exhibit state behavior GroundSensing {
            state idle;
            state onSurface;
            state edgeDetectedState;
            transition init to idle;
            transition idle to onSurface when power.voltage > 0.0 [V];
            transition onSurface to edgeDetectedState when reflectance < threshold;
            transition edgeDetectedState to onSurface when reflectance >= threshold;
            do action readGround {
                output.reflectance = reflectance;
                output.edgeDetected = reflectance < threshold;
            }
        }
    }

    part def TouchButtonArray {
        doc /* Capacitive touch buttons on top shell. */
        attribute buttonCount: Integer = 5;
        attribute type: String = "capacitive";
        attribute anyButtonPressed: Boolean = false;

        part startButton: TouchButton {
            attribute function: ButtonFunction = ButtonFunction::start;
        }
        part stopButton: TouchButton {
            attribute function: ButtonFunction = ButtonFunction::stop;
        }
        part forwardButton: TouchButton {
            attribute function: ButtonFunction = ButtonFunction::forward;
        }
        part backwardButton: TouchButton {
            attribute function: ButtonFunction = ButtonFunction::backward;
        }
        part modeSelectButton: TouchButton {
            attribute function: ButtonFunction = ButtonFunction::modeSelect;
        }

        port buttonBus: ButtonInputPort;
    }

    part def TouchButton {
        doc /* Individual capacitive touch button. */
        attribute function: ButtonFunction;
        attribute pressed: Boolean = false;
        attribute sensitivity: Real = 0.8;
        port output: ButtonInputPort;

        exhibit state behavior ButtonPress {
            state unpressed;
            state pressedState;
            state debounce;
            transition init to unpressed;
            transition unpressed to pressedState when touched == true;
            transition pressedState to debounce when touched == false;
            transition debounce to unpressed after 50.0 [ms];
            do action updateOutput {
                output.pressed = pressed;
                output.function = function;
            }
        }
    }

    part def FeedbackSystem {
        doc /* Visual and audible feedback system. */
        part ledRing: LEDRing;
        part bottomLEDs: BottomLEDs;
        part speaker: PiezoSpeaker;
        port feedbackBus: FeedbackBusPort;
    }

    part def LEDRing {
        doc /* Ring of multi-color RGB LEDs on top. */
        attribute ledCount: Integer = 8;
        attribute color: ColorValue = ColorValue{red=0, green=0, blue=0};
        attribute active: Boolean = false;
        part leds: RGBLED[8];
        port control: LEDControlPort;

        exhibit state behavior LEDOperation {
            state off;
            state on;
            state blinking;
            transition init to off;
            transition off to on when control.active == true;
            transition on to off when control.active == false;
            transition on to blinking when blinkingEnabled == true;
            transition blinking to on when blinkingEnabled == false;
            do action setColor {
                color = control.color;
                active = control.active;
            }
        }
    }

    part def BottomLEDs {
        doc /* Two RGB LEDs underneath the robot. */
        attribute ledCount: Integer = 2;
        part leftLED: RGBLED;
        part rightLED: RGBLED;
        port control: LEDControlPort;
    }

    part def RGBLED {
        doc /* Individual RGB LED. */
        attribute red: RGBValue = 0;
        attribute green: RGBValue = 0;
        attribute blue: RGBValue = 0;
        attribute brightness: Real = 1.0;
        port control: LEDControlPort;
    }

    part def PiezoSpeaker {
        doc /* Piezo speaker for sounds and melodies. */
        attribute frequencyRange: Tuple { min: Frequency = 100.0 [Hz]; max: Frequency = 8000.0 [Hz]; }
        attribute currentFrequency: ToneFrequency = 0.0 [Hz];
        attribute active: Boolean = false;
        port control: AudioControlPort;
        port power: PowerPort;

        exhibit state behavior SpeakerOperation {
            state silent;
            state playingTone;
            state playingMelody;
            transition init to silent;
            transition silent to playingTone when control.active == true;
            transition playingTone to silent when control.active == false;
            transition playingTone to playingMelody when melodyQueue->size() > 0;
            transition playingMelody to silent when melodyQueue->isEmpty();
            do action playTone(f: ToneFrequency, d: DurationValue) {
                currentFrequency = f;
                active = true;
                wait(d);
                active = false;
            }
            do action mute() {
                active = false;
                currentFrequency = 0.0 [Hz];
            }
        }
    }

    part def Microcontroller {
        doc /* Central microcontroller - the robot's brain. */
        attribute clockSpeed: Frequency = 16.0 [MHz];
        attribute flashMemory: Integer = 128 [KB];
        attribute ram: Integer = 16 [KB];
        attribute avoidanceComplete: Boolean = false;
        attribute edgeAvoidanceComplete: Boolean = false;
        attribute processingDelay: DurationValue = 10.0 [ms];

        part leftMotorCommand: MotorCommand {
            attribute dutyCycle: DutyCycle = 0.0;
            attribute direction: DriveDirection = DriveDirection::stop;
            attribute speed: LinearSpeed = 0.0 [mm/s];
        }
        part rightMotorCommand: MotorCommand {
            attribute dutyCycle: DutyCycle = 0.0;
            attribute direction: DriveDirection = DriveDirection::stop;
            attribute speed: LinearSpeed = 0.0 [mm/s];
        }

        port sensorInput: SensorBusPort;
        port actuatorOutput: ActuatorBusPort;
        port feedbackOutput: FeedbackBusPort;
        port buttonInput: ButtonInputPort;
        port power: PowerPort;

        exhibit state behavior Processing {
            state initializing;
            state readingSensors;
            state decisionMaking;
            state executingCommands;
            transition init to initializing;
            transition initializing to readingSensors;
            transition readingSensors to decisionMaking;
            transition decisionMaking to executingCommands;
            transition executingCommands to readingSensors;

            do action processSensorData {
                /* Read all sensor values and update internal state */
                var frontReadings: ProximityValue[5] = sensorInput.readings->selectByType(ProximityValue);
                var rearReadings: ProximityValue[2] = sensorInput.readings->selectByType(ProximityValue);
                var groundReadings: ReflectanceValue[2] = sensorInput.readings->selectByType(ReflectanceValue);
            }

            do action makeDecision {
                /* Determine action based on sensor data */
                if sensorInput.readings->exists{r | r.detected == true} then {
                    avoidanceComplete = false;
                } else {
                    avoidanceComplete = true;
                }
            }

            do action sendCommands {
                /* Send commands to motors, LEDs, and speaker */
                actuatorOutput.commands = Sequence{leftMotorCommand, rightMotorCommand};
            }
        }
    }

    part def PowerSystem {
        doc /* Power management system. */
        part battery: Battery;
        part powerRegulator: PowerRegulator;
        part chargingCircuit: ChargingCircuit;
        port powerOut: PowerPort;
        port chargeIn: PowerPort;
    }

    part def Battery {
        doc /* Internal rechargeable battery. */
        attribute rechargeable: Boolean = true;
        attribute nominalVoltage: Voltage = 3.7 [V];
        attribute capacity: Current = 1.8 [A];
        attribute chargeLevel: Real = 1.0 { min = 0.0; max = 1.0; }
        attribute charging: Boolean = false;
        attribute fullyCharged: Boolean = true;
        attribute chemistry: String = "LiPo";
        port positive: PowerPort;
        port negative: PowerPort;

        exhibit state behavior BatteryOperation {
            state discharging;
            state chargingState;
            state depleted;
            state full;
            transition init to full;
            transition full to discharging when loadConnected == true;
            transition discharging to depleted when chargeLevel < 0.1;
            transition discharging to chargingState when charging == true;
            transition chargingState to discharging when charging == false and chargeLevel > 0.1;
            transition chargingState to full when chargeLevel >= 1.0;
            transition depleted to chargingState when charging == true;
            do action discharge {
                chargeLevel = chargeLevel - 0.001;
                fullyCharged = false;
            }
            do action charge {
                chargeLevel = chargeLevel + 0.01;
                if chargeLevel >= 1.0 then {
                    fullyCharged = true;
                    chargeLevel = 1.0;
                }
            }
        }
    }

    part def PowerRegulator {
        doc /* Regulates battery voltage to system voltage. */
        attribute inputVoltage: Voltage = 3.7 [V];
        attribute outputVoltage: Voltage = 5.0 [V];
        attribute efficiency: Real = 0.9;
        port input: PowerPort;
        port output: PowerPort;
    }

    part def ChargingCircuit {
        doc /* Circuit for recharging the battery. */
        attribute maxChargeCurrent: Current = 0.5 [A];
        attribute chargeVoltage: Voltage = 5.0 [V];
        port input: PowerPort;
        port output: PowerPort;
    }

    // ===== Connections in Thymio =====
    connection powerToSystem connect powerSystem.powerOut to controller.power;
    connection powerToMotors connect powerSystem.powerOut to driveSystem.leftMotor.power;
    connection powerToMotors2 connect powerSystem.powerOut to driveSystem.rightMotor.power;
    connection powerToSensors connect powerSystem.powerOut to sensorArray.frontSensors.power;
    connection powerToSensors2 connect powerSystem.powerOut to sensorArray.rearSensors.power;
    connection powerToSensors3 connect powerSystem.powerOut to sensorArray.groundSensors.power;
    connection powerToSpeaker connect powerSystem.powerOut to feedbackSystem.speaker.power;

    connection sensorsToController connect sensorArray.sensorBus to controller.sensorInput;
    connection controllerToMotors connect controller.actuatorOutput to driveSystem.leftMotor.control;
    connection controllerToMotors2 connect controller.actuatorOutput to driveSystem.rightMotor.control;
    connection controllerToFeedback connect controller.feedbackOutput to feedbackSystem.feedbackBus;
    connection buttonsToController connect interactionInterface.buttonBus to controller.buttonInput;

    connection chargeInput connect powerIn to powerSystem.chargeIn;
}
