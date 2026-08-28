package 'Water Aeration System' {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    private import ISQ::VolumeValue;
    private import ISQ::MassConcentrationValue;

    item def Water;
    item def Air;
    item def CompressedAir;
    item def FineBubbles;
    item def OxygenatedWater;
    item def DOReadingItem {
        attribute value : DOConcentration;
    }
    item def BlowerCommandItem {
        attribute value : Real;
    }

    attribute def DOConcentration :> MassConcentrationValue;
    attribute def BlowerSpeed :> Real;
    attribute def TargetDO :> DOConcentration;

    port def WaterOutPort {
        out item water : Water;
    }
    port def WaterInPort {
        in item water : Water;
    }
    port def AirOutPort {
        out item air : Air;
    }
    port def AirInPort {
        in item air : Air;
    }
    port def CompressedAirOutPort {
        out item air : CompressedAir;
    }
    port def CompressedAirInPort {
        in item air : CompressedAir;
    }
    port def BubblesOutPort {
        out item bubbles : FineBubbles;
    }
    port def BubblesInPort {
        in item bubbles : FineBubbles;
    }
    port def OxygenatedWaterOutPort {
        out item water : OxygenatedWater;
    }
    port def OxygenatedWaterInPort {
        in item water : OxygenatedWater;
    }
    port def DOReadingOutPort {
        out reading : DOReadingItem;
    }
    port def DOReadingInPort {
        in reading : DOReadingItem;
    }
    port def CommandOutPort {
        out command : BlowerCommandItem;
    }
    port def CommandInPort {
        in command : BlowerCommandItem;
    }

    part def DiffuserGrid {
        port airIn : CompressedAirInPort;
        port bubblesOut : BubblesOutPort;
    }

    part def AerationChamber {
        port waterIn : WaterInPort;
        port waterOut : OxygenatedWaterOutPort;
        port bubblesIn : BubblesInPort;
        attribute volume : VolumeValue;
        part diffuserGrid : DiffuserGrid;
        flow of bubbles : FineBubbles
            from diffuserGrid.bubblesOut.bubbles to bubblesIn.bubbles;
    }

    part def AirBlower {
        port airIn : AirInPort;
        port airOut : CompressedAirOutPort;
        port controlPort : CommandInPort;
        attribute speed : BlowerSpeed;
        perform action adjustSpeed {
            in command : BlowerCommandItem;
            out speed : BlowerSpeed;
        }
    }

    part def DissolvedOxygenSensor {
        port readingOut : DOReadingOutPort;
        attribute currentReading : DOConcentration;
        perform action measureDO {
            out reading : DOReadingItem;
        }
    }

    state def ControlStates {
        in target : TargetDO;
        in readingIn : DOReadingInPort;
        out commandOut : CommandOutPort;
        entry; then idle;
        state idle {
            entry do action sendBlowerOff {
                send new BlowerCommandItem() via commandOut;
            }
            accept DOReadingItem
                if readingIn.reading.value < target
                then active;
        }
        state active {
            entry do action sendBlowerOn {
                send new BlowerCommandItem() via commandOut;
            }
            accept DOReadingItem
                if readingIn.reading.value >= target
                then idle;
        }
    }

    part def AerationController {
        port readingIn : DOReadingInPort;
        port commandOut : CommandOutPort;
        attribute targetDO : TargetDO;
        exhibit state controlStates : ControlStates {
            in target = targetDO;
            in readingIn = readingIn;
            out commandOut = commandOut;
        }
    }

    requirement def MaintainDORequirement {
        doc /* The system shall maintain dissolved oxygen concentration at or above the target level. */
        subject aerationSystem : AerationSystem;
        objective {
            aerationSystem.sensor.currentReading >= aerationSystem.controller.targetDO
        }
    }

    part def AerationSystem {
        requirement maintainDO : MaintainDORequirement;

        part chamber : AerationChamber;
        part blower : AirBlower;
        part sensor : DissolvedOxygenSensor;
        part controller : AerationController;

        part externalWaterSource {
            port waterOut : WaterOutPort;
        }
        part externalSink {
            port waterIn : OxygenatedWaterInPort;
        }
        part atmosphere {
            port airOut : AirOutPort;
        }

        flow of water : Water
            from externalWaterSource.waterOut.water to chamber.waterIn.water;
        flow of oxygenatedWater : OxygenatedWater
            from chamber.waterOut.water to externalSink.waterIn.water;
        flow of air : Air
            from atmosphere.airOut.air to blower.airIn.air;
        flow of compressedAir : CompressedAir
            from blower.airOut.air to chamber.diffuserGrid.airIn.air;
        flow of reading : DOReadingItem
            from sensor.readingOut.reading to controller.readingIn.reading;
        flow of command : BlowerCommandItem
            from controller.commandOut.command to blower.controlPort.command;
    }
}
