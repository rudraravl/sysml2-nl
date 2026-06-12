package QuartzClockSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Voltage :> ISQ::electromagneticQuantity {
        unit = "V";
    }

    attribute def Current :> ISQ::electricCurrent {
        unit = "mA";
    }

    attribute def Frequency :> ISQ::frequency {
        unit = "Hz";
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = "degC";
    }

    attribute def Angle :> ISQ::planeAngle {
        unit = "deg";
    }

    attribute def Duration :> ISQ::time {
        unit = "s";
    }

    attribute def Torque :> ISQ::mechanicsQuantity {
        unit = "mN*m";
    }

    attribute def Energy :> ISQ::energy {
        unit = "J";
    }

    attribute def LogicalSignal {
        attribute level : Boolean;
    }

    attribute def TimePulse {
        attribute period : Duration;
        attribute pulseWidth : Duration;
        attribute risingEdge : Boolean;
    }

    attribute def StepCommand {
        attribute stepAngle : Angle;
        attribute directionClockwise : Boolean;
        attribute issuedAtSecond : Integer;
    }

    attribute def GearRotation {
        attribute angle : Angle;
        attribute angularVelocity : Real;
    }

    attribute def DisplayedTime {
        attribute hours : Integer;
        attribute minutes : Integer;
        attribute seconds : Integer;
    }

    attribute def BatteryStatus {
        attribute terminalVoltage : Voltage;
        attribute remainingEnergy : Energy;
        attribute lowBattery : Boolean;
    }

    port def ElectricalPowerPort {
        out attribute voltage : Voltage;
        out attribute current : Current;
    }

    port def PowerInputPort {
        in attribute voltage : Voltage;
        in attribute current : Current;
    }

    port def OscillationPort {
        out attribute frequency : Frequency;
        out attribute waveform : LogicalSignal;
    }

    port def PulsePort {
        out item pulse : TimePulse;
    }

    port def PulseInputPort {
        in item pulse : TimePulse;
    }

    port def StepCommandPort {
        out item command : StepCommand;
    }

    port def StepCommandInputPort {
        in item command : StepCommand;
    }

    port def MechanicalRotationPort {
        out item rotation : GearRotation;
    }

    port def MechanicalRotationInputPort {
        in item rotation : GearRotation;
    }

    port def TimeDisplayPort {
        out item displayedTime : DisplayedTime;
    }

    port def AdjustmentInputPort {
        in attribute crownPulled : Boolean;
        in attribute advanceMinutePulse : Boolean;
    }

    port def StatusPort {
        out item status : BatteryStatus;
    }

    part def Battery {
        attribute nominalVoltage : Voltage = 1.5 [V];
        attribute cutoffVoltage : Voltage = 1.1 [V];
        attribute capacity : Energy = 7200 [J];
        attribute internalResistance : Real = 8.0;
        attribute status : BatteryStatus;

        port powerOut : ElectricalPowerPort;
        port statusOut : StatusPort;

        action providePower {
            first start;
            then measureTerminalVoltage;
            then updateRemainingEnergy;
            then publishStatus;
        }

        requirement batteryVoltageRequirement {
            doc /* The battery shall provide regulated clock supply voltage while terminal voltage remains above cutoff. */
            require constraint { status.terminalVoltage >= cutoffVoltage implies powerOut.voltage >= 1.1 [V] }
        }

        requirement lowBatteryIndicationRequirement {
            doc /* The battery shall assert lowBattery when terminal voltage is below 1.2 V. */
            require constraint { status.terminalVoltage < 1.2 [V] implies status.lowBattery == true }
        }
    }

    part def QuartzCrystal {
        attribute nominalFrequency : Frequency = 32768 [Hz];
        attribute frequencyTolerance : Real = 20.0;
        attribute operatingTemperature : Temperature = 25 [degC];
        attribute loadCapacitance : Real = 12.5;

        port powerIn : PowerInputPort;
        port oscillationOut : OscillationPort;

        state def CrystalOscillationStateMachine {
            state off;
            state startup;
            state resonating;
            state fault;

            transition first off;
            transition off_to_startup
                first off
                accept PowerApplied
                then startup;

            transition startup_to_resonating
                first startup
                accept StableAmplitudeReached
                then resonating;

            transition resonating_to_fault
                first resonating
                accept FrequencyOutOfRange
                then fault;

            transition fault_to_startup
                first fault
                accept ResetOscillator
                then startup;
        }

        perform oscillationBehavior : CrystalOscillationStateMachine;

        requirement crystalFrequencyRequirement {
            doc /* The quartz crystal shall oscillate at 32,768 Hz within +/-20 ppm at 25 degC. */
            require constraint {
                nominalFrequency >= 32767.345 [Hz] and nominalFrequency <= 32768.655 [Hz]
            }
        }
    }

    part def OscillatorCircuit {
        attribute supplyVoltage : Voltage;
        attribute outputFrequency : Frequency = 32768 [Hz];
        attribute startupTime : Duration = 1.0 [s];
        attribute driveCurrent : Current = 0.002 [mA];

        port powerIn : PowerInputPort;
        port oscillationOut : OscillationPort;

        part crystal : QuartzCrystal;

        connection crystalPower from powerIn to crystal.powerIn;
        connection crystalSignal from crystal.oscillationOut to oscillationOut;

        action startOscillation {
            first receiveSupply;
            then biasCrystal;
            then amplifyResonance;
            then outputSquareWave;
        }

        requirement oscillatorStartupRequirement {
            doc /* The oscillator shall reach stable 32,768 Hz operation within 2 seconds after valid power is applied. */
            require constraint { startupTime <= 2.0 [s] }
        }
    }

    part def FrequencyDivider {
        attribute inputFrequency : Frequency = 32768 [Hz];
        attribute outputPulseFrequency : Frequency = 1 [Hz];
        attribute dividerRatio : Integer = 32768;
        attribute counterValue : Integer;

        port oscillatorIn : PulseInputPort;
        port oneHzPulseOut : PulsePort;

        action divideFrequency {
            first receiveOscillatorTick;
            then incrementCounter;
            then decide;
            if counterValue >= dividerRatio then resetCounter;
            then emitOneSecondPulse;
        }

        state def DividerStateMachine {
            state reset;
            state counting;
            state emitPulse;

            transition first reset;
            transition reset_to_counting
                first reset
                accept OscillatorTick
                then counting;

            transition counting_to_counting
                first counting
                accept OscillatorTick
                then counting;

            transition counting_to_emitPulse
                first counting
                accept DividerTerminalCount
                then emitPulse;

            transition emitPulse_to_counting
                first emitPulse
                accept PulseEmitted
                then counting;
        }

        perform dividerBehavior : DividerStateMachine;

        requirement dividerAccuracyRequirement {
            doc /* The divider shall produce one output pulse for every 32,768 oscillator cycles. */
            require constraint { dividerRatio == 32768 }
        }
    }

    part def TimekeepingController {
        attribute currentTime : DisplayedTime;
        attribute pulseCount : Integer;
        attribute batteryLowMode : Boolean;
        attribute secondsPerMinute : Integer = 60;
        attribute minutesPerHour : Integer = 60;
        attribute hoursPerCycle : Integer = 12;

        port oneHzPulseIn : PulseInputPort;
        port adjustmentIn : AdjustmentInputPort;
        port stepCommandOut : StepCommandPort;
        port displayOut : TimeDisplayPort;

        action keepTime {
            first receiveOneSecondPulse;
            then incrementSeconds;
            if currentTime.seconds >= secondsPerMinute then incrementMinutes;
            if currentTime.minutes >= minutesPerHour then incrementHours;
            if currentTime.hours > hoursPerCycle then wrapHours;
            then issueStepCommand;
            then publishDisplayedTime;
        }

        action adjustTime {
            first detectCrownPosition;
            if adjustmentIn.crownPulled then acceptMinuteAdvance;
            then updateDisplayedTime;
        }

        state def ControllerStateMachine {
            state initializing;
            state normalTimekeeping;
            state adjustment;
            state lowBatteryTimekeeping;
            state stopped;

            transition first initializing;

            transition initializing_to_normal
                first initializing
                accept InitializationComplete
                then normalTimekeeping;

            transition normal_to_adjustment
                first normalTimekeeping
                accept CrownPulled
                then adjustment;

            transition adjustment_to_normal
                first adjustment
                accept CrownPushed
                then normalTimekeeping;

            transition normal_to_lowBattery
                first normalTimekeeping
                accept LowBatteryDetected
                then lowBatteryTimekeeping;

            transition lowBattery_to_normal
                first lowBatteryTimekeeping
                accept BatteryRestored
                then normalTimekeeping;

            transition normal_to_stopped
                first normalTimekeeping
                accept PowerLost
                then stopped;

            transition lowBattery_to_stopped
                first lowBatteryTimekeeping
                accept PowerLost
                then stopped;
        }

        perform controllerBehavior : ControllerStateMachine;

        requirement timeRollOverRequirement {
            doc /* The controller shall roll over seconds, minutes, and hours using a 12-hour clock convention. */
            require constraint {
                currentTime.seconds >= 0 and currentTime.seconds < 60 and
                currentTime.minutes >= 0 and currentTime.minutes < 60 and
                currentTime.hours >= 1 and currentTime.hours <= 12
            }
        }
    }

    part def StepperMotor {
        attribute coilResistance : Real = 240.0;
        attribute nominalStepAngle : Angle = 6 [deg];
        attribute holdingTorque : Torque = 0.08 [mN*m];
        attribute consumedCurrentPerPulse : Current = 0.8 [mA];

        port powerIn : PowerInputPort;
        port commandIn : StepCommandInputPort;
        port rotationOut : MechanicalRotationPort;

        action executeStep {
            first receiveStepCommand;
            then energizeCoilA;
            then energizeCoilB;
            then rotateRotor;
            then deenergizeCoils;
            then publishRotation;
        }

        state def MotorStateMachine {
            state idle;
            state coilA;
            state coilB;
            state stepped;
            state fault;

            transition first idle;

            transition idle_to_coilA
                first idle
                accept StepCommandReceived
                then coilA;

            transition coilA_to_coilB
                first coilA
                accept CoilASettled
                then coilB;

            transition coilB_to_stepped
                first coilB
                accept RotorAligned
                then stepped;

            transition stepped_to_idle
                first stepped
                accept PulseComplete
                then idle;

            transition coilA_to_fault
                first coilA
                accept RotorStall
                then fault;

            transition coilB_to_fault
                first coilB
                accept RotorStall
                then fault;
        }

        perform motorBehavior : MotorStateMachine;

        requirement motorStepRequirement {
            doc /* The motor shall rotate one 6 degree step for each valid one-second command. */
            require constraint { nominalStepAngle == 6 [deg] }
        }
    }

    part def GearTrain {
        attribute secondsGearRatio : Real = 1.0;
        attribute minutesGearRatio : Real = 60.0;
        attribute hoursGearRatio : Real = 720.0;
        attribute backlashAngle : Angle = 0.2 [deg];

        port motorRotationIn : MechanicalRotationInputPort;
        port secondsRotationOut : MechanicalRotationPort;
        port minutesRotationOut : MechanicalRotationPort;
        port hoursRotationOut : MechanicalRotationPort;

        action transmitMotion {
            first receiveMotorStep;
            then rotateSecondsWheel;
            then reduceToMinutesWheel;
            then reduceToHoursWheel;
            then outputHandRotations;
        }

        requirement gearRatioRequirement {
            doc /* The gear train shall convert sixty motor second steps into one minute-hand increment and seven hundred twenty second steps into one hour-hand increment. */
            require constraint { minutesGearRatio == 60.0 and hoursGearRatio == 720.0 }
        }
    }

    part def AnalogDisplay {
        attribute displayedTime : DisplayedTime;
        attribute secondsHandAngle : Angle;
        attribute minutesHandAngle : Angle;
        attribute hoursHandAngle : Angle;
        attribute dialMarkCount : Integer = 60;

        port secondsRotationIn : MechanicalRotationInputPort;
        port minutesRotationIn : MechanicalRotationInputPort;
        port hoursRotationIn : MechanicalRotationInputPort;
        port timeOut : TimeDisplayPort;

        action updateHands {
            first receiveRotations;
            then setSecondsHand;
            then setMinutesHand;
            then setHoursHand;
            then publishDisplayedTime;
        }

        requirement displayReadabilityRequirement {
            doc /* The display shall indicate time using hour, minute, and second hands over a 12-hour dial. */
            require constraint { dialMarkCount == 60 }
        }
    }

    part def AdjustmentMechanism {
        attribute crownPulled : Boolean = false;
        attribute advanceRate : Frequency = 2 [Hz];

        port userInputOut : AdjustmentInputPort;
        port mechanicalAdvanceOut : StepCommandPort;

        action handleUserAdjustment {
            first senseCrown;
            if crownPulled then generateAdvancePulses;
            then releaseCrown;
        }

        state def AdjustmentStateMachine {
            state locked;
            state setting;
            state released;

            transition first locked;

            transition locked_to_setting
                first locked
                accept CrownPulled
                then setting;

            transition setting_to_released
                first setting
                accept CrownPushed
                then released;

            transition released_to_locked
                first released
                accept CrownSettled
                then locked;
        }

        perform adjustmentBehavior : AdjustmentStateMachine;
    }

    part def QuartzClock {
        attribute primaryFunction : String = "Maintain and display civil time by using a quartz crystal frequency reference to generate one-second motor steps that advance analog clock hands.";
        attribute nominalSupplyVoltage : Voltage = 1.5 [V];
        attribute oscillatorFrequency : Frequency = 32768 [Hz];
        attribute displayedTime : DisplayedTime;
        attribute operatingTemperatureMin : Temperature = -10 [degC];
        attribute operatingTemperatureMax : Temperature = 50 [degC];

        port displayedTimeOut : TimeDisplayPort;

        part battery : Battery;
        part oscillator : OscillatorCircuit;
        part divider : FrequencyDivider;
        part controller : TimekeepingController;
        part motor : StepperMotor;
        part gearTrain : GearTrain;
        part display : AnalogDisplay;
        part adjustment : AdjustmentMechanism;

        connection batteryToOscillator from battery.powerOut to oscillator.powerIn;
        connection batteryToMotor from battery.powerOut to motor.powerIn;
        connection oscillatorToDivider from oscillator.oscillationOut to divider.oscillatorIn;
        connection dividerToController from divider.oneHzPulseOut to controller.oneHzPulseIn;
        connection controllerToMotor from controller.stepCommandOut to motor.commandIn;
        connection motorToGearTrain from motor.rotationOut to gearTrain.motorRotationIn;
        connection gearTrainToSecondsHand from gearTrain.secondsRotationOut to display.secondsRotationIn;
        connection gearTrainToMinutesHand from gearTrain.minutesRotationOut to display.minutesRotationIn;
        connection gearTrainToHoursHand from gearTrain.hoursRotationOut to display.hoursRotationIn;
        connection displayToExternal from display.timeOut to displayedTimeOut;
        connection adjustmentToController from adjustment.userInputOut to controller.adjustmentIn;

        action operateQuartzClock {
            first initializePower;
            then startReferenceOscillator;
            then divideReferenceToOneHz;
            then repeatTimekeepingCycle;
        }

        action repeatTimekeepingCycle {
            first waitForOneSecondPulse;
            then updateInternalTime;
            then commandMotorStep;
            then transmitGearMotion;
            then updateAnalogDisplay;
        }

        state def ClockOperationalStateMachine {
            state unpowered;
            state starting;
            state running;
            state settingTime;
            state lowBattery;
            state stopped;

            transition first unpowered;

            transition unpowered_to_starting
                first unpowered
                accept BatteryInserted
                then starting;

            transition starting_to_running
                first starting
                accept OscillatorStable
                then running;

            transition running_to_setting
                first running
                accept CrownPulled
                then settingTime;

            transition setting_to_running
                first settingTime
                accept CrownPushed
                then running;

            transition running_to_lowBattery
                first running
                accept LowBatteryDetected
                then lowBattery;

            transition lowBattery_to_running
                first lowBattery
                accept BatteryReplaced
                then running;

            transition running_to_stopped
                first running
                accept BatteryDepleted
                then stopped;

            transition lowBattery_to_stopped
                first lowBattery
                accept BatteryDepleted
                then stopped;
        }

        perform clockBehavior : ClockOperationalStateMachine;

        requirement primaryFunctionRequirement {
            doc /* The quartz clock shall maintain and display time by deriving a one-second reference from a 32,768 Hz quartz oscillator and advancing the analog display once per second. */
            require constraint { oscillatorFrequency == 32768 [Hz] }
        }

        requirement operatingEnvironmentRequirement {
            doc /* The quartz clock shall operate over the specified household temperature range. */
            require constraint {
                operatingTemperatureMin <= -10 [degC] and operatingTemperatureMax >= 50 [degC]
            }
        }

        requirement displayUpdateRequirement {
            doc /* The clock shall update the displayed second indication once for every valid one-second pulse while in the running state. */
            require constraint { true }
        }

        requirement powerEfficiencyRequirement {
            doc /* The clock shall use intermittent motor drive pulses so the motor is energized only during commanded steps. */
            require constraint { motor.consumedCurrentPerPulse <= 1.0 [mA] }
        }
    }

    part clockSystem : QuartzClock;

    requirement quartzClockSystemRequirement {
        doc /* The system shall provide a battery-powered quartz analog clock that continuously maintains and displays hours, minutes, and seconds. */
        subject clockSystem;
        require constraint {
            clockSystem.oscillatorFrequency == 32768 [Hz] and
            clockSystem.nominalSupplyVoltage == 1.5 [V]
        }
    }
}