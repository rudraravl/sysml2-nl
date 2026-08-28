package MedicalFeedingTubeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        attribute def FlowRateValue :> Real;
        attribute def VolumeValue :> Real;
        attribute def PressureValue :> Real;

        item def NutritionalFormula;
        item def Command;
        item def PrimeCommand :> Command;
        item def StartCommand :> Command;
        item def StopCommand :> Command;
        item def PauseCommand :> Command;
        item def ResumeCommand :> Command;
        item def OcclusionAlarm;
        item def AirInLineAlarm;

        port def FormulaFlowPort {
            out formula : NutritionalFormula;
        }

        port def CommandPort {
            out command : Command;
        }

        port def FlowRateDataPort {
            out measuredFlowRate : FlowRateValue;
        }

        port def PressureDataPort {
            out measuredPressure : PressureValue;
            out occlusionAlarm : OcclusionAlarm;
        }

        port def AirDetectionDataPort {
            out airDetected : Boolean;
            out airInLineAlarm : AirInLineAlarm;
        }

        action def PrimePump;
        action def RunPump {
            in flowRate : FlowRateValue;
        }
        action def StopPump;
        action def SenseFlowRate {
            out flowRate : FlowRateValue;
        }
        action def SensePressure {
            out pressure : PressureValue;
        }
        action def DetectAir {
            out airDetected : Boolean;
        }
        action def TriggerAlarm;
        action def ClearAlarm;

        part def Patient {
            port enteralPort : ~FormulaFlowPort;
        }

        part def Reservoir {
            port outlet : FormulaFlowPort;
            attribute remainingVolume : VolumeValue;
        }

        part def DeliveryTube {
            port inlet : ~FormulaFlowPort;
            port outlet : FormulaFlowPort;
        }

        part def Pump {
            port inlet : ~FormulaFlowPort;
            port outlet : FormulaFlowPort;
            port commandPort : ~CommandPort;
            attribute currentSpeed : FlowRateValue;
        }

        part def FlowRateSensor {
            port dataPort : FlowRateDataPort;
        }

        part def PressureSensor {
            port dataPort : PressureDataPort;
            attribute maxSafePressure : PressureValue;
        }

        part def AirDetector {
            port dataPort : AirDetectionDataPort;
        }

        part def UserInterface {
            port commandPort : CommandPort;
            attribute prescribedFlowRate : FlowRateValue;
            attribute prescribedVolume : VolumeValue;
        }

        part def Controller {
            port uiPort : ~CommandPort;
            port pumpPort : CommandPort;
            port flowSensorPort : ~FlowRateDataPort;
            port pressureSensorPort : ~PressureDataPort;
            port airDetectorPort : ~AirDetectionDataPort;

            attribute prescribedFlowRate : FlowRateValue;
            attribute prescribedVolume : VolumeValue;
            attribute deliveredVolume : VolumeValue;

            exhibit state feedingStates {
                entry; then standby;

                state standby;
                accept PrimeCommand via uiPort
                    then priming;

                state priming;
                accept after 30 [s]
                    then delivering;

                state delivering {
                    entry;
                }
                accept PauseCommand via uiPort
                    then paused;
                accept OcclusionAlarm via pressureSensorPort
                    then alarmed;
                accept AirInLineAlarm via airDetectorPort
                    then alarmed;
                accept when deliveredVolume >= prescribedVolume
                    then completed;

                state paused;
                accept ResumeCommand via uiPort
                    then delivering;
                accept StopCommand via uiPort
                    then standby;

                state alarmed;
                accept StopCommand via uiPort
                    then standby;

                state completed;
                accept StopCommand via uiPort
                    then standby;
            }
        }

        part def FeedingTubeSystem {
            part patient : Patient;
            part reservoir : Reservoir;
            part pump : Pump;
            part tube : DeliveryTube;
            part controller : Controller;
            part ui : UserInterface;
            part flowSensor : FlowRateSensor;
            part pressureSensor : PressureSensor;
            part airDetector : AirDetector;

            connect reservoir.outlet to pump.inlet;
            connect pump.outlet to tube.inlet;
            connect tube.outlet to patient.enteralPort;

            connect ui.commandPort to controller.uiPort;
            connect controller.pumpPort to pump.commandPort;

            connect flowSensor.dataPort to controller.flowSensorPort;
            connect pressureSensor.dataPort to controller.pressureSensorPort;
            connect airDetector.dataPort to controller.airDetectorPort;
        }

        requirement def SafeDeliveryRequirement {
            subject system : FeedingTubeSystem;
            text "The system shall immediately stop delivery and raise an alarm if an occlusion or air bubble is detected.";
        }

        requirement def VolumeDeliveryRequirement {
            subject system : FeedingTubeSystem;
            text "The system shall deliver the total prescribed volume of formula before entering the completed state.";
        }

        requirement def FlowRateAccuracyRequirement {
            subject system : FeedingTubeSystem;
            text "The delivered flow rate shall be maintained within ±5% of the prescribed setpoint.";
        }

        requirement def AirEmbolismPreventionRequirement {
            subject system : FeedingTubeSystem;
            text "The system shall detect air bubbles in the delivery line and immediately halt delivery to prevent air embolism.";
        }
    }

    import Definitions::*;

    package Usages {
        private import Definitions::*;

        part feedingTubeSystem : FeedingTubeSystem {
            requirement safeDelReq : SafeDeliveryRequirement;
            satisfy safeDelReq by pressureSensor;

            requirement volDelReq : VolumeDeliveryRequirement;
            satisfy volDelReq by controller;

            requirement flowAccReq : FlowRateAccuracyRequirement;
            satisfy flowAccReq by flowSensor;

            requirement airPrevReq : AirEmbolismPreventionRequirement;
            satisfy airPrevReq by airDetector;
        }
    }
}
