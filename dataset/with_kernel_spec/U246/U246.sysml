package HotAirOvenSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import Time::*;

    package Definitions {
        enum def FanSpeed { low; high; }
        enum def DoorState { open; closed; }
        enum def OvenPhase { idle; preheating; maintaining; cooling; complete; }

        attribute def StartCmd;
        attribute def StopCmd;
        attribute def SetTargetTempCmd { temp : TemperatureValue; }
        attribute def SetDurationCmd { duration : DurationValue; }
        attribute def StatusUpdate {
            currentTemp : TemperatureValue;
            elapsedTime : DurationValue;
            phase : OvenPhase;
        }

        port def TempFeedbackPort { out temp : TemperatureValue; }
        port def DoorStatusPort { out status : DoorState; }
        port def HeaterControlPort { in on : Boolean; }
        port def FanControlPort { in speed : FanSpeed; }
        port def UICommandPort {
            in startCmd : StartCmd;
            in stopCmd : StopCmd;
            in setTargetTempCmd : SetTargetTempCmd;
            in setDurationCmd : SetDurationCmd;
        }
        port def UIFeedbackPort { out status : StatusUpdate; }

        action def SenseTemperature { out temp : TemperatureValue; }
        action def ControlHeater { in cmd : Boolean; }
        action def ControlFan { in speed : FanSpeed; }

        part def OvenChamber {
            attribute volume : VolumeValue = 100 [L];
            attribute maxSafeTemp : TemperatureValue = 573 [K];
            attribute safeCoolTemp : TemperatureValue = 323 [K];
        }

        part def HeatingElement {
            port heaterControlPort : HeaterControlPort;
            attribute powerRating : PowerValue = 2000 [W];
        }

        part def CirculationFan {
            port fanControlPort : FanControlPort;
            attribute currentSpeed : FanSpeed;
        }

        part def TemperatureSensor {
            port tempFeedbackPort : TempFeedbackPort;
            perform action senseTemp : SenseTemperature;
        }

        part def DoorLatch {
            port doorStatusPort : DoorStatusPort;
            attribute doorState : DoorState;
        }

        part def UserInterface {
            port uiCommandPort : ~UICommandPort;
            port uiFeedbackPort : ~UIFeedbackPort;
        }

        part def ControlUnit {
            port tempInputPort : ~TempFeedbackPort;
            port doorInputPort : ~DoorStatusPort;
            port uiInputPort : UICommandPort;
            port uiOutputPort : UIFeedbackPort;
            port heaterOutputPort : HeaterControlPort;
            port fanOutputPort : FanControlPort;

            attribute targetTemp : TemperatureValue = 448 [K];
            attribute cycleDuration : DurationValue = 2 [h];
            attribute elapsedTime : DurationValue;
            attribute heaterCmd : Boolean;
            attribute fanCmd : FanSpeed;
        }

        state def OvenStates;

        part def HotAirOven {
            part chamber : OvenChamber;
            part heater : HeatingElement;
            part fan : CirculationFan;
            part controller : ControlUnit;
            part tempSensor : TemperatureSensor;
            part doorLatch : DoorLatch;
            part ui : UserInterface;

            bind controller.uiInputPort = ui.uiCommandPort;
            bind controller.uiOutputPort = ui.uiFeedbackPort;

            flow tempFlow of TemperatureValue
                from tempSensor.tempFeedbackPort.temp to controller.tempInputPort.temp;
            flow doorStatusFlow of DoorState
                from doorLatch.doorStatusPort.status to controller.doorInputPort.status;
            flow heaterCmdFlow of Boolean
                from controller.heaterOutputPort.on to heater.heaterControlPort.on;
            flow fanCmdFlow of FanSpeed
                from controller.fanOutputPort.speed to fan.fanControlPort.speed;

            exhibit state ovenStates : OvenStates {
                entry; then Idle;

                state Idle;
                transition idle_to_preheating
                    first Idle
                    accept StartCmd via controller.uiInputPort
                    then Preheating;

                state Preheating;
                transition preheating_to_maintaining
                    first Preheating
                    accept when controller.tempInputPort.temp >= controller.targetTemp
                    then Maintaining;
                transition preheating_ot_safety
                    first Preheating
                    accept when controller.tempInputPort.temp > chamber.maxSafeTemp
                    then Cooling;
                transition preheating_door_safety
                    first Preheating
                    accept when controller.doorInputPort.status == DoorState::open
                    then Cooling;

                state Maintaining;
                transition maintaining_to_cooling
                    first Maintaining
                    accept after controller.cycleDuration
                    then Cooling;
                transition maintaining_ot_safety
                    first Maintaining
                    accept when controller.tempInputPort.temp > chamber.maxSafeTemp
                    then Cooling;
                transition maintaining_door_safety
                    first Maintaining
                    accept when controller.doorInputPort.status == DoorState::open
                    then Cooling;

                state Cooling;
                transition cooling_to_complete
                    first Cooling
                    accept when controller.tempInputPort.temp <= chamber.safeCoolTemp
                    then Complete;

                state Complete;
                transition complete_to_idle
                    first Complete
                    accept StopCmd via controller.uiInputPort
                    then Idle;
            }
        }
    }

    package Usages {
        private import Definitions::*;

        part ovenSystem : HotAirOven;
    }

    package Requirements {
        private import Definitions::*;

        requirement def OverTempSafetyRequirement {
            doc "The system shall automatically shut down the heating element if the chamber temperature exceeds the maximum safe limit.";
        }
        requirement def DoorInterlockRequirement {
            doc "The system shall immediately cut power to the heater if the oven door is opened during any operational phase.";
        }
        requirement def TemperatureControlRequirement {
            doc "The system shall maintain the chamber temperature within a precise range for a user-specified duration.";
        }
        requirement def UniformHeatingRequirement {
            doc "The circulation fan shall distribute hot air evenly throughout the chamber to ensure temperature uniformity.";
        }
    }
}
