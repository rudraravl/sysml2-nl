package HeadacheHat {
    private import ScalarValues::*;

    attribute def CelsiusTemp :> Real;
    attribute def MinutesDuration :> Real;
    attribute def PascalPressure :> Real;

    requirement def RelievePain {
        doc /* Effectively reduce the user's pain level in a safe, comfortable, and reusable manner. */
    }

    requirement def ProvideColdTherapy {
        doc /* Deliver cold therapy using removable and reusable cooling gel packs. */
    }

    requirement def ProvideCompressionTherapy {
        doc /* Deliver gentle compression using an adjustable elastic strap. */
    }

    requirement def EnsureSafety {
        doc /* Prevent the skin from getting too cold and avoid potential injury. */
        attribute minSafeTemp : CelsiusTemp = 2.0;
        attribute maxSessionTime : MinutesDuration = 20.0;
    }

    port def ThermalPort;
    port def MechanicalPort;
    port def DataPort;

    item def ThermalEnergy;

    part def FabricShell {
        attribute material : String = "Neoprene";
        part coolingSlot[4] {
            port insertionPort : ThermalPort;
        }
        part strapAnchor {
            port anchorPort : MechanicalPort;
        }
    }

    part def GelPack {
        attribute isFrozen : Boolean;
        attribute storedEnergy : ThermalEnergy;
        attribute currentTemp : CelsiusTemp;
        port coolingSurface : ThermalPort;
    }

    part def ElasticStrap {
        attribute appliedPressure : PascalPressure;
        port attachmentPoint : MechanicalPort;
    }

    part def TempSensor {
        attribute reading : CelsiusTemp;
        port dataOut : DataPort;
    }

    part def Controller {
        port sensorInput[2] : DataPort;
        port alertOutput : DataPort;
        attribute minTemp : CelsiusTemp = 2.0;
        attribute maxTime : MinutesDuration = 20.0;
        attribute unsafeDetected : Boolean = false;
        attribute sessionExpired : Boolean = false;
    }

    action def TherapySession {
        action freezeGelPacks;
        action insertPacks;
        action donHat;
        action tightenStrap;
        action deliverTherapy {
            action deliverCold;
            action deliverCompression;
        }
        action monitorTemperature;
        action stopTherapy;

        succession first freezeGelPacks then insertPacks then donHat then tightenStrap then deliverTherapy then stopTherapy;
    }

    state machine def OperatingState {
        state idle;
        state active;
        state emergency;

        transition idle -> active;
        transition active -> emergency;
        transition emergency -> idle;
    }

    part def HeadacheHat {
        part shell : FabricShell;
        part gelPacks[4] : GelPack;
        part strap : ElasticStrap;
        part sensors[2] : TempSensor;
        part controller : Controller;

        connect gelPacks.coolingSurface to shell.coolingSlot.insertionPort;
        connect sensors.dataOut to controller.sensorInput;
        connect strap.attachmentPoint to shell.strapAnchor.anchorPort;

        requirement reqPain : RelievePain;
        requirement reqCold : ProvideColdTherapy;
        requirement reqCompression : ProvideCompressionTherapy;
        requirement reqSafety : EnsureSafety;

        action therapySession : TherapySession;
        state machine operatingState : OperatingState;

        satisfy reqPain by therapySession;
        satisfy reqCold by gelPacks;
        satisfy reqCompression by strap;
        satisfy reqSafety by controller;
    }

    part headacheHat : HeadacheHat;
}
