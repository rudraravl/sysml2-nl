package 'Automated Water Well System' {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        item def Water;

        attribute def PressureValue :> Real;
        attribute def LevelValue :> Real;

        item def PumpOnSignal;
        item def PumpOffSignal;
        item def LowWaterLevelAlert;
        item def NormalWaterLevelSignal;

        port def WaterPort {
            ref flow of Water;
        }

        port def ControlPort;

        part def Aquifer {
            attribute waterTableLevel : LevelValue;
            port waterOut : WaterPort;
        }

        part def SubmersiblePump {
            port waterIn : WaterPort;
            port waterOut : WaterPort;
            port controlIn : ControlPort;

            action extractWater : ExtractWater;

            state pumpStates {
                entry; then off;
                state off;
                accept PumpOnSignal then on;
                state on {
                    do extractWater;
                }
                accept PumpOffSignal then off;
                accept LowWaterLevelAlert then maintenance;
                state maintenance;
                accept NormalWaterLevelSignal then off;
            }
        }

        part def RisingPipe {
            port waterIn : WaterPort;
            port waterOut : WaterPort;
        }

        part def NonReturnValve {
            port waterIn : WaterPort;
            port waterOut : WaterPort;
        }

        part def PressureVessel {
            port waterIn : WaterPort;
            port waterOut : WaterPort;
            attribute currentPressure : PressureValue;
        }

        part def DistributionNetwork {
            port waterIn : WaterPort;
        }

        part def PressureController {
            attribute lowPressureThreshold : PressureValue;
            attribute highPressureThreshold : PressureValue;
            attribute currentPressure : PressureValue;
            port pumpControlOut : ControlPort;
            port alertIn : ControlPort;

            state controllerStates {
                entry; then monitoring;
                state monitoring;
                accept when currentPressure < lowPressureThreshold
                    do send new PumpOnSignal() to pumpControlOut
                    then monitoring;
                accept when currentPressure > highPressureThreshold
                    do send new PumpOffSignal() to pumpControlOut
                    then monitoring;
                accept LowWaterLevelAlert
                    do send new PumpOffSignal() to pumpControlOut
                    then emergency;
                state emergency;
                accept NormalWaterLevelSignal
                    then monitoring;
            }
        }

        part def WaterLevelSensor {
            attribute measuredLevel : LevelValue;
            attribute criticalLevelThreshold : LevelValue;
            port alertOut : ControlPort;

            state sensorStates {
                entry; then normal;
                state normal;
                accept when measuredLevel < criticalLevelThreshold
                    do send new LowWaterLevelAlert() to alertOut
                    then low;
                state low;
                accept when measuredLevel >= criticalLevelThreshold
                    do send new NormalWaterLevelSignal() to alertOut
                    then normal;
            }
        }

        part def WellBore {
            part pump : SubmersiblePump;
            part risingPipe : RisingPipe;
        }

        action def ExtractWater;

        requirement def 'Provide Pressurized Water' {
            doc /* The system shall provide pressurized water to the distribution network. */
        }

        requirement def 'Prevent Dry Running' {
            doc /* The system shall shut down the pump if the water level drops to a critical low. */
        }
    }

    package Usages {
        private import Definitions::*;

        part waterWellSystem {
            part aquifer : Aquifer;
            part wellBore : WellBore;
            part nonReturnValve : NonReturnValve;
            part pressureVessel : PressureVessel;
            part distributionNetwork : DistributionNetwork;
            part pressureController : PressureController;
            part waterLevelSensor : WaterLevelSensor;

            flow of Water from aquifer.waterOut to wellBore.pump.waterIn;
            flow of Water from wellBore.pump.waterOut to wellBore.risingPipe.waterIn;
            flow of Water from wellBore.risingPipe.waterOut to nonReturnValve.waterIn;
            flow of Water from nonReturnValve.waterOut to pressureVessel.waterIn;
            flow of Water from pressureVessel.waterOut to distributionNetwork.waterIn;

            connect pressureController.pumpControlOut to wellBore.pump.controlIn;
            connect waterLevelSensor.alertOut to pressureController.alertIn;
            connect waterLevelSensor.alertOut to wellBore.pump.controlIn;
        }

        requirement 'provide pressurized water' : 'Provide Pressurized Water' {
            doc /* The system shall provide pressurized water to the distribution network. */
        }

        requirement 'prevent dry running' : 'Prevent Dry Running' {
            doc /* The system shall shut down the pump if the water level drops to a critical low. */
        }
    }
}
