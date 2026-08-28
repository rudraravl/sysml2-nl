package HotAirOvenSystem {

    import ScalarValues::*;

    // ========== UNITS ==========

    unit degC {
        doc "Degree Celsius";
    }

    unit watt {
        doc "Watt - unit of electrical power";
    }

    unit s {
        doc "Second - unit of time";
    }

    unit rpm {
        doc "Revolutions per minute - unit of rotational speed";
    }

    // ========== VALUE TYPES ==========

    value type Temperature :> Real {
        unit degC;
        doc "Temperature measurement in degrees Celsius";
    }

    value type Power :> Real {
        unit watt;
        doc "Electrical power in watts";
    }

    value type Duration :> Real {
        unit s;
        doc "Time duration in seconds";
    }

    value type RotationalSpeed :> Real {
        unit rpm;
        doc "Rotational speed in revolutions per minute";
    }

    // ========== ENUMERATIONS ==========

    enum OperationalPhase {
        doc "Operational phases of the hot air oven cycle";
        Idle;
        Preheating;
        Maintaining;
        Cooling;
        Complete;
    }

    enum FanSpeedEnum {
        doc "Fan speed settings";
        Off;
        Low;
        High;
    }

    enum DoorState {
        doc "State of the oven door";
        Open;
        Closed;
    }

    enum HeaterState {
        doc "On or off state of the heating element";
        On;
        Off;
    }

    // ========== ITEMS ==========

    item def HeatFlow {
        doc "Thermal energy flow produced by the heating element";
        attribute power : Power;
    }

    item def AirFlow {
        doc "Circulating air flow produced by the fan";
        attribute velocity : RotationalSpeed;
    }

    // ========== PORTS ==========

    port def HeatOutPort {
        out heat : HeatFlow;
    }

    port def HeatInPort {
        in heat : HeatFlow;
    }

    port def AirOutPort {
        out air : AirFlow;
    }

    port def AirInPort {
        in air : AirFlow;
    }

    port def TempReadingPort {
        attribute temperature : Temperature;
    }

    port def PowerCommandPort {
        attribute command : HeaterState;
    }

    port def FanCommandPort {
        attribute speed : FanSpeedEnum;
    }

    port def DoorStatePort {
        attribute state : DoorState;
    }

    port def UIControlPort {
        attribute setpoint : Temperature;
        attribute cycleDuration : Duration;
        attribute startCommand : Boolean;
        attribute stopCommand : Boolean;
    }

    port def UIFeedbackPort {
        attribute currentTemperature : Temperature;
        attribute elapsedTime : Duration;
        attribute currentPhase : OperationalPhase;
    }

    // ========== REQUIREMENTS ==========

    requirement def ThermalProcessingReq {
        doc "The hot air oven shall heat an insulated chamber to a precise target temperature and maintain it for a user-specified duration.";
    }

    requirement def TemperatureControlReq {
        doc "The control unit shall continuously monitor chamber temperature via the temperature sensor and cycle the heating element on and off to reach and maintain the user-specified target temperature.";
    }

    requirement def AirCirculationReq {
        doc "The circulation fan shall distribute heated air evenly throughout the chamber to ensure temperature uniformity across the chamber volume.";
    }

    requirement def OvertempShutdownReq {
        doc "The system shall automatically shut down the heating element and activate the fan at high speed if the chamber temperature exceeds a maximum safe limit of 250 degrees Celsius.";
    }

    requirement def DoorInterlockReq {
        doc "The heating element shall immediately cease operation if the oven door is opened during any active heating cycle phase.";
    }

    requirement def UIFeedbackReq {
        doc "The user interface shall display the current chamber temperature, elapsed cycle time, and current operational phase in real time.";
    }

    // ========== PART DEFINITIONS ==========

    part def HeatingElement {
        doc "Electric heating element that generates heat for the oven chamber";

        port powerCommandIn : PowerCommandPort;
        port heatOut : HeatOutPort;

        attribute maxPower : Power = 3000;
        attribute currentPower : Power = 0;
        attribute operatingState : HeaterState = Off;

        action generateHeat {
            in command : HeaterState;
            out heat : HeatFlow;

            if command == HeaterState::On {
                heat.power = maxPower;
                currentPower = maxPower;
                operatingState = HeaterState::On;
            } else {
                heat.power = 0;
                currentPower = 0;
                operatingState = HeaterState::Off;
            }
        }
    }

    part def CirculationFan {
        doc "Circulation fan that distributes heated air throughout the chamber";

        port fanCommandIn : FanCommandPort;
        port airOut : AirOutPort;

        attribute maxSpeed : RotationalSpeed = 2500;
        attribute currentSpeed : RotationalSpeed = 0;
        attribute speedSetting : FanSpeedEnum = Off;

        action circulateAir {
            in setting : FanSpeedEnum;
            out air : AirFlow;

            if setting == FanSpeedEnum::Off {
                air.velocity = 0;
                currentSpeed = 0;
            } else if setting == FanSpeedEnum::Low {
                air.velocity = maxSpeed * 0.5;
                currentSpeed = maxSpeed * 0.5;
            } else if setting == FanSpeedEnum::High {
                air.velocity = maxSpeed;
                currentSpeed = maxSpeed;
            }
            speedSetting = setting;
        }
    }

    part def OvenChamber {
        doc "Insulated chamber where materials are placed for thermal processing";

        port heatIn : HeatInPort;
        port airIn : AirInPort;
        port tempOut : TempReadingPort;

        attribute currentTemperature : Temperature = 20;
        attribute volume : Real = 200;
        attribute maxSafeTemp : Temperature = 250;

        action updateTemperature {
            in heat : HeatFlow;
            in air : AirFlow;
            out temperature : Temperature;

            temperature = currentTemperature + heat.power * 0.001;
        }
    }

    part def TemperatureSensor {
        doc "Temperature sensor that measures chamber temperature and provides a reading to the controller";

        port tempIn : TempReadingPort;
        port tempOut : TempReadingPort;

        attribute accuracy : Temperature = 0.5;
        attribute minRange : Temperature = -20;
        attribute maxRange : Temperature = 300;

        action readTemperature {
            in chamberTemp : Temperature;
            out reading : Temperature;

            reading = chamberTemp;
        }
    }

    part def DoorLatch {
        doc "Door latch sensor that detects whether the oven door is open or closed";

        port doorStateOut : DoorStatePort;

        attribute state : DoorState = Closed;
        attribute isLatched : Boolean = true;

        action detectState {
            out detectedState : DoorState;

            if isLatched {
                detectedState = DoorState::Closed;
            } else {
                detectedState = DoorState::Open;
            }
        }
    }

    part def UserInterface {
        doc "Operator interface for setting parameters and viewing oven status";

        port controlOut : UIControlPort;
        port feedbackIn : UIFeedbackPort;

        attribute setpoint : Temperature = 150;
        attribute cycleDuration : Duration = 3600;
        attribute displayedTemp : Temperature;
        attribute displayedTime : Duration;
        attribute displayedPhase : OperationalPhase = Idle;

        action setParameters {
            in temp : Temperature;
            in duration : Duration;

            setpoint = temp;
            cycleDuration = duration;
        }

        action startCycle {
            out start : Boolean;
            start = true;
        }

        action stopCycle {
            out stop : Boolean;
            stop = true;
        }

        action updateDisplay {
            in temp : Temperature;
            in time : Duration;
            in phase : OperationalPhase;

            displayedTemp = temp;
            displayedTime = time;
            displayedPhase = phase;
        }
    }

    part def ControlUnit {
        doc "Central controller that manages oven operation including heating, fan speed, safety monitoring, and cycle progression";

        port tempInput : TempReadingPort;
        port doorInput : DoorStatePort;
        port heaterOutput : PowerCommandPort;
        port fanOutput : FanCommandPort;
        port uiInput : UIControlPort;
        port uiOutput : UIFeedbackPort;

        attribute targetTemperature : Temperature = 150;
        attribute cycleDuration : Duration = 3600;
        attribute elapsedTime : Duration = 0;
        attribute maxSafeTemperature : Temperature = 250;
        attribute currentTemperature : Temperature = 20;
        attribute currentDoorState : DoorState = Closed;
        attribute currentPhase : OperationalPhase = Idle;
        attribute heaterCmd : HeaterState = Off;
        attribute fanCmd : FanSpeedEnum = Off;
        attribute alarmActive : Boolean = false;

        state OvenStateMachine {

            state Idle {
                entry {
                    heaterCmd = HeaterState::Off;
                    fanCmd = FanSpeedEnum::Off;
                    currentPhase = OperationalPhase::Idle;
                    elapsedTime = 0;
                    alarmActive = false;
                }
            }

            state Preheating {
                entry {
                    heaterCmd = HeaterState::On;
                    fanCmd = FanSpeedEnum::High;
                    currentPhase = OperationalPhase::Preheating;
                }
                do {
                    heaterCmd = HeaterState::On;
                    fanCmd = FanSpeedEnum::High;
                }
            }

            state Maintaining {
                entry {
                    currentPhase = OperationalPhase::Maintaining;
                }
                do {
                    if currentTemperature < targetTemperature {
                        heaterCmd = HeaterState::On;
                    } else {
                        heaterCmd = HeaterState::Off;
                    }
                    fanCmd = FanSpeedEnum::Low;
                    elapsedTime = elapsedTime + 1;
                }
            }

            state Cooling {
                entry {
                    heaterCmd = HeaterState::Off;
                    fanCmd = FanSpeedEnum::High;
                    currentPhase = OperationalPhase::Cooling;
                }
                do {
                    heaterCmd = HeaterState::Off;
                    fanCmd = FanSpeedEnum::High;
                }
            }

            state Complete {
                entry {
                    heaterCmd = HeaterState::Off;
                    fanCmd = FanSpeedEnum::Off;
                    currentPhase = OperationalPhase::Complete;
                }
            }

            state EmergencyShutdown {
                entry {
                    heaterCmd = HeaterState::Off;
                    fanCmd = FanSpeedEnum::High;
                    alarmActive = true;
                }
                do {
                    heaterCmd = HeaterState::Off;
                    fanCmd = FanSpeedEnum::High;
                }
            }

            // Idle -> Preheating
            transition from Idle to Preheating when uiInput.startCommand;

            // Preheating transitions
            transition from Preheating to Maintaining when currentTemperature >= targetTemperature;
            transition from Preheating to EmergencyShutdown when currentTemperature > maxSafeTemperature;
            transition from Preheating to Cooling when doorInput.state == DoorState::Open;
            transition from Preheating to Idle when uiInput.stopCommand;

            // Maintaining transitions
            transition from Maintaining to Cooling when elapsedTime >= cycleDuration;
            transition from Maintaining to EmergencyShutdown when currentTemperature > maxSafeTemperature;
            transition from Maintaining to Cooling when doorInput.state == DoorState::Open;
            transition from Maintaining to Idle when uiInput.stopCommand;

            // Cooling transitions
            transition from Cooling to Complete when currentTemperature <= 50;
            transition from Cooling to Idle when uiInput.stopCommand;

            // Complete -> Idle (automatic completion)
            transition from Complete to Idle;

            // EmergencyShutdown -> Idle (recovery after cooldown)
            transition from EmergencyShutdown to Idle when currentTemperature <= 50;
        }

        action controlLoop {
            in tempReading : Temperature;
            in doorReading : DoorState;
            in setpoint : Temperature;
            in cycleTime : Duration;
            in startCmd : Boolean;
            in stopCmd : Boolean;
            out heaterCommand : HeaterState;
            out fanCommand : FanSpeedEnum;
            out currentTemp : Temperature;
            out elapsed : Duration;
            out phase : OperationalPhase;

            currentTemperature = tempReading;
            currentDoorState = doorReading;
            targetTemperature = setpoint;
            cycleDuration = cycleTime;
            heaterCommand = heaterCmd;
            fanCommand = fanCmd;
            currentTemp = currentTemperature;
            elapsed = elapsedTime;
            phase = currentPhase;
        }
    }

    // ========== TOP-LEVEL SYSTEM ==========

    part def HotAirOven {
        doc "Automated Hot Air Oven System for thermal processing applications including sterilization, drying, and curing";

        part chamber : OvenChamber;
        part heater : HeatingElement;
        part fan : CirculationFan;
        part sensor : TemperatureSensor;
        part doorLatch : DoorLatch;
        part controller : ControlUnit;
        part ui : UserInterface;

        // Heat flow from heating element to chamber
        connect heater.heatOut to chamber.heatIn;

        // Air flow from fan to chamber
        connect fan.airOut to chamber.airIn;

        // Temperature readings from chamber through sensor to controller
        connect chamber.tempOut to sensor.tempIn;
        connect sensor.tempOut to controller.tempInput;

        // Door state from latch to controller
        connect doorLatch.doorStateOut to controller.doorInput;

        // Control commands from controller to heater and fan
        connect controller.heaterOutput to heater.powerCommandIn;
        connect controller.fanOutput to fan.fanCommandIn;

        // UI signals from UI to controller and feedback from controller to UI
        connect ui.controlOut to controller.uiInput;
        connect controller.uiOutput to ui.feedbackIn;
    }

    // ========== REQUIREMENT SATISFACTION ==========

    part ovenInstance : HotAirOven {
        doc "Instance of the Hot Air Oven system satisfying all requirements";

        satisfy ThermalProcessingReq;
        satisfy TemperatureControlReq;
        satisfy AirCirculationReq;
        satisfy OvertempShutdownReq;
        satisfy DoorInterlockReq;
        satisfy UIFeedbackReq;
    }
}
